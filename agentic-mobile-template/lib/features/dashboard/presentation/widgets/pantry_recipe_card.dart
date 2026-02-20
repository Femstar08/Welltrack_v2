import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../pantry/data/pantry_repository.dart';
import '../../../recipes/data/recipe_repository.dart';

class _PantryStats {
  const _PantryStats({required this.total, required this.expiring});
  final int total;
  final int expiring;
}

final _pantryCountProvider =
    FutureProvider.family<_PantryStats, String>((ref, profileId) async {
  final repo = ref.watch(pantryRepositoryProvider);
  final items = await repo.getItems(profileId);
  final expiring = items.where((i) => i.isExpiringSoon).length;
  return _PantryStats(total: items.length, expiring: expiring);
});

final _recipeCountProvider =
    FutureProvider.family<int, String>((ref, profileId) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final recipes = await repo.getRecipes(profileId);
  return recipes.length;
});

class PantryRecipeCard extends ConsumerWidget {
  const PantryRecipeCard({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantryAsync = ref.watch(_pantryCountProvider(profileId));
    final recipeAsync = ref.watch(_recipeCountProvider(profileId));
    final theme = Theme.of(context);

    final pantryTotal = pantryAsync.valueOrNull?.total ?? 0;
    final expiring = pantryAsync.valueOrNull?.expiring ?? 0;
    final recipeCount = recipeAsync.valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/recipes'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kitchen & Recipes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.kitchen,
                      label: 'Pantry',
                      value: '$pantryTotal',
                      color: theme.colorScheme.primary,
                    ),
                    _StatItem(
                      icon: Icons.warning_amber,
                      label: 'Expiring',
                      value: '$expiring',
                      color: expiring > 0 ? Colors.orange : theme.colorScheme.onSurfaceVariant,
                    ),
                    _StatItem(
                      icon: Icons.menu_book,
                      label: 'Recipes',
                      value: '$recipeCount',
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push('/pantry'),
                        icon: const Icon(Icons.kitchen, size: 16),
                        label: const Text('Pantry', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push('/recipes'),
                        icon: const Icon(Icons.menu_book, size: 16),
                        label: const Text('Recipes', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push('/shopping'),
                        icon: const Icon(Icons.shopping_cart, size: 16),
                        label: const Text('Shopping', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
