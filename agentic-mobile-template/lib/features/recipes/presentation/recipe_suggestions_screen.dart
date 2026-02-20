import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'recipe_generation_provider.dart';
import 'recipe_detail_screen.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../pantry/domain/pantry_item_entity.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/auth_state.dart';

class RecipeSuggestionsScreen extends ConsumerStatefulWidget {
  const RecipeSuggestionsScreen({super.key});

  @override
  ConsumerState<RecipeSuggestionsScreen> createState() =>
      _RecipeSuggestionsScreenState();
}

class _RecipeSuggestionsScreenState
    extends ConsumerState<RecipeSuggestionsScreen> {
  bool _autoTriggerAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoTriggerIfIdle();
    });
  }

  Future<void> _autoTriggerIfIdle() async {
    if (_autoTriggerAttempted) return;

    final generationData = ref.read(recipeGenerationProvider);
    final isIdleWithNoSuggestions =
        generationData.state == RecipeGenerationState.idle &&
            generationData.suggestions.isEmpty;

    if (!isIdleWithNoSuggestions) return;

    setState(() {
      _autoTriggerAttempted = true;
    });

    final profileAsync = ref.read(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    if (profile == null) return;

    final authState = ref.read(authProvider);
    String userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    } else {
      userId = profile.userId;
    }

    List<PantryItemEntity> pantryItems;
    try {
      pantryItems = await ref
          .read(pantryRepositoryProvider)
          .getAvailableItems(profile.id);
    } catch (_) {
      pantryItems = [];
    }

    if (!mounted) return;

    if (pantryItems.isEmpty) {
      // Show the empty-pantry state — nothing to generate from.
      // The build method will handle showing the empty pantry message
      // once we know generation was not triggered due to empty pantry.
      // We signal this by leaving the state idle and setting a flag.
      setState(() {
        // _autoTriggerAttempted is already true; idle + empty is handled in build.
      });
      return;
    }

    await ref
        .read(recipeGenerationProvider.notifier)
        .generateRecipeSuggestions(userId, profile.id, pantryItems);
  }

  @override
  Widget build(BuildContext context) {
    final generationData = ref.watch(recipeGenerationProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Suggestions'),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No active profile'));
          }

          if (generationData.state == RecipeGenerationState.generating) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating recipe ideas...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take a few moments',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (generationData.state == RecipeGenerationState.generatingSteps) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your recipe...'),
                ],
              ),
            );
          }

          if (generationData.state == RecipeGenerationState.complete &&
              generationData.generatedRecipe != null) {
            // Navigate to recipe detail
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(
                    recipeId: generationData.generatedRecipe!.id,
                  ),
                ),
              );
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (generationData.state == RecipeGenerationState.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    generationData.errorMessage ?? 'An error occurred',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(recipeGenerationProvider.notifier).reset();
                      Navigator.pop(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // Idle with no suggestions and auto-trigger already attempted means
          // the pantry was empty when the screen loaded.
          if (generationData.state == RecipeGenerationState.idle &&
              generationData.suggestions.isEmpty &&
              _autoTriggerAttempted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.kitchen_outlined,
                      size: 80,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your pantry is empty',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add items to your pantry to get personalised recipe suggestions.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/pantry'),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Go to Pantry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Idle but not yet attempted — first frame before postFrameCallback fires.
          if (generationData.state == RecipeGenerationState.idle &&
              generationData.suggestions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // State is 'suggestions' (or idle with pre-loaded suggestions).
          return Column(
            children: [
              // Error / fallback banner
              if (generationData.errorMessage != null &&
                  (generationData.state == RecipeGenerationState.suggestions ||
                      generationData.suggestions.isNotEmpty))
                _FallbackBanner(message: generationData.errorMessage!),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: generationData.suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = generationData.suggestions[index];
                    return _RecipeSuggestionCard(
                      suggestion: suggestion,
                      onTap: () {
                        ref
                            .read(recipeGenerationProvider.notifier)
                            .selectSuggestion(
                                profile.userId, profile.id, suggestion);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeSuggestionCard extends StatelessWidget {

  const _RecipeSuggestionCard({
    required this.suggestion,
    required this.onTap,
  });
  final RecipeSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder image
            Container(
              height: 160,
              color: theme.colorScheme.primaryContainer,
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    suggestion.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    suggestion.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Metadata row
                  Row(
                    children: [
                      // Time
                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${suggestion.estimatedTimeMin} min',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),

                      // Difficulty
                      Icon(Icons.bar_chart, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        suggestion.difficulty,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),

                      // Nutrition score
                      _NutritionScoreBadge(score: suggestion.nutritionScore),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestion.tags.map((tag) {
                      return Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionScoreBadge extends StatelessWidget {

  const _NutritionScoreBadge({required this.score});
  final String score;

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        'Score: $score',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
