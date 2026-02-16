import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/recipes/presentation/recipe_generation_provider.dart';
import 'package:welltrack/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:welltrack/features/profile/presentation/profile_provider.dart';

class RecipeSuggestionsScreen extends ConsumerWidget {
  const RecipeSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationData = ref.watch(recipeGenerationProvider);
    final profileAsync = ref.watch(activeProfileProvider);

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

          if (generationData.suggestions.isEmpty) {
            return const Center(
              child: Text('No recipe suggestions available'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: generationData.suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = generationData.suggestions[index];
              return _RecipeSuggestionCard(
                suggestion: suggestion,
                onTap: () {
                  ref
                      .read(recipeGenerationProvider.notifier)
                      .selectSuggestion(profile.id, suggestion);
                },
              );
            },
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

class _RecipeSuggestionCard extends StatelessWidget {
  final RecipeSuggestion suggestion;
  final VoidCallback onTap;

  const _RecipeSuggestionCard({
    required this.suggestion,
    required this.onTap,
  });

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
  final String score;

  const _NutritionScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
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
