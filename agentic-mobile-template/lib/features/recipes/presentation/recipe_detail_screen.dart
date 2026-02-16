import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/recipes/data/recipe_repository.dart';
import 'package:welltrack/features/recipes/domain/recipe_entity.dart';
import 'package:welltrack/features/recipes/presentation/prep_walkthrough_screen.dart';

final recipeDetailProvider = FutureProvider.family<RecipeEntity, String>((ref, recipeId) {
  return ref.watch(recipeRepositoryProvider).getRecipe(recipeId);
});

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeDetailProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        data: (recipe) => _RecipeDetailContent(recipe: recipe),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailContent extends ConsumerWidget {
  final RecipeEntity recipe;

  const _RecipeDetailContent({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
      slivers: [
        // App bar with image
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              recipe.title,
              style: const TextStyle(
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            background: recipe.imageUrl != null
                ? Image.network(
                    recipe.imageUrl!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.restaurant,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: recipe.isFavorite ? Colors.red : null,
              ),
              onPressed: () async {
                await ref
                    .read(recipeRepositoryProvider)
                    .toggleFavorite(recipe.id, !recipe.isFavorite);
                ref.invalidate(recipeDetailProvider(recipe.id));
              },
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata row
                Row(
                  children: [
                    _MetadataChip(
                      icon: Icons.timer_outlined,
                      label: recipe.displayTime,
                    ),
                    const SizedBox(width: 12),
                    _MetadataChip(
                      icon: Icons.people_outline,
                      label: '${recipe.servings} servings',
                    ),
                    const SizedBox(width: 12),
                    _MetadataChip(
                      icon: Icons.bar_chart,
                      label: recipe.difficultyLevel,
                    ),
                    if (recipe.nutritionScore != null) ...[
                      const SizedBox(width: 12),
                      _NutritionScoreBadge(score: recipe.nutritionScore!),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                if (recipe.description != null) ...[
                  Text(
                    recipe.description!,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],

                // Tags
                if (recipe.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recipe.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Ingredients section
                Text(
                  'Ingredients',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...recipe.ingredients.map((ingredient) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 8),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ingredient.displayText,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Instructions section
                Text(
                  'Instructions',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...recipe.steps.asMap().entries.map((entry) {
                  final step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text('${step.stepNumber}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.instruction,
                                style: theme.textTheme.bodyLarge,
                              ),
                              if (step.isTimed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${step.durationMinutes} min',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ),
      ],
      ),
      floatingActionButton: recipe.steps.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrepWalkthroughScreen(recipe: recipe),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Cooking'),
            )
          : null,
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        score,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
