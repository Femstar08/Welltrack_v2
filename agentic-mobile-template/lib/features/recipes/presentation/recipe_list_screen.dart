import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/core/router/app_router.dart';
import '../domain/recipe_entity.dart';
import 'recipe_browse_provider.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileId = ref.read(activeProfileIdProvider) ?? '';
      if (profileId.isNotEmpty) {
        ref.read(savedRecipesProvider(profileId).notifier).loadRecipes();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    final recipesState = ref.watch(savedRecipesProvider(profileId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recipes'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref
                      .read(savedRecipesProvider(profileId).notifier)
                      .searchRecipes('');
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showSearch ? 64 : 0,
            child: _showSearch
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search recipes...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                      onChanged: (query) {
                        ref
                            .read(savedRecipesProvider(profileId).notifier)
                            .searchRecipes(query);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Filter chips
          if (recipesState.recipes.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: recipesState.activeFilter == 'All',
                    onTap: () => ref
                        .read(savedRecipesProvider(profileId).notifier)
                        .filterByTag('All'),
                  ),
                  _FilterChip(
                    label: 'Favorites',
                    isSelected: recipesState.activeFilter == 'Favorites',
                    onTap: () => ref
                        .read(savedRecipesProvider(profileId).notifier)
                        .filterByTag('Favorites'),
                  ),
                  ...recipesState.allTags.map((tag) => _FilterChip(
                        label: tag,
                        isSelected: recipesState.activeFilter == tag,
                        onTap: () => ref
                            .read(savedRecipesProvider(profileId).notifier)
                            .filterByTag(tag),
                      )),
                ],
              ),
            ),

          // Body
          Expanded(
            child: _buildBody(recipesState, profileId, theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
      SavedRecipesState state, String profileId, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64,
                color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load recipes',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref
                  .read(savedRecipesProvider(profileId).notifier)
                  .loadRecipes(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.recipes.isEmpty) {
      return _buildEmptyState(theme);
    }

    if (state.filteredRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64,
                color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No matching recipes',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                ref
                    .read(savedRecipesProvider(profileId).notifier)
                    .clearFilters();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(savedRecipesProvider(profileId).notifier).loadRecipes(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: state.filteredRecipes.length,
        itemBuilder: (context, index) {
          final recipe = state.filteredRecipes[index];
          return _RecipeCard(recipe: recipe);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 80,
                color: theme.colorScheme.outline),
            const SizedBox(height: 24),
            Text(
              'No recipes yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Get started by generating AI recipes or importing from a URL.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/recipes/suggestions'),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI Suggestions'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/recipes/import-url'),
              icon: const Icon(Icons.link),
              label: const Text('Import from URL'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI Suggestions'),
              subtitle: const Text('Generate recipes from your pantry'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/recipes/suggestions');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Import from URL'),
              subtitle: const Text('Paste a recipe link'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/recipes/import-url');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Import from Photo'),
              subtitle: const Text('Photograph a recipe to import'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/recipes/import-ocr');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primaryContainer,
        checkmarkColor: theme.colorScheme.primary,
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final RecipeEntity recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            SizedBox(
              height: 140,
              width: double.infinity,
              child: recipe.imageUrl != null
                  ? Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(theme),
                    )
                  : _imagePlaceholder(theme),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + favorite
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recipe.isFavorite)
                        Icon(Icons.favorite,
                            size: 18, color: theme.colorScheme.error),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Metadata row
                  Row(
                    children: [
                      if (recipe.totalTimeMin != null) ...[
                        Icon(Icons.timer_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          recipe.displayTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.people_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.servings}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (recipe.nutritionScore != null) ...[
                        const Spacer(),
                        _NutritionBadge(score: recipe.nutritionScore!),
                      ],
                    ],
                  ),

                  // Tags
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: recipe.tags.take(3).map((tag) {
                        return Chip(
                          label: Text(tag,
                              style: theme.textTheme.labelSmall),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NutritionBadge extends StatelessWidget {
  const _NutritionBadge({required this.score});

  final String score;

  @override
  Widget build(BuildContext context) {
    final color = _getColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        score,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getColor(String score) {
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
