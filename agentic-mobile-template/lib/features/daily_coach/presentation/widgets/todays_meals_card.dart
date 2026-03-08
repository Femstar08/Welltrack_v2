import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../daily_coach/domain/daily_prescription_entity.dart';
import '../../../meals/domain/meal_plan_entity.dart';

class TodaysMealsCard extends StatelessWidget {
  const TodaysMealsCard({
    super.key,
    required this.mealDirective,
    this.mealPlan,
  });

  final MealDirective mealDirective;
  final MealPlanEntity? mealPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Meals',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _DirectiveBadge(directive: mealDirective),
              ],
            ),
            const SizedBox(height: 10),
            if (mealPlan != null) ...[
              _MealPlanContent(mealPlan: mealPlan!, directive: mealDirective),
            ] else ...[
              _NoMealPlanContent(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealPlanContent extends StatelessWidget {
  const _MealPlanContent({
    required this.mealPlan,
    required this.directive,
  });

  final MealPlanEntity mealPlan;
  final MealDirective directive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

    final meals = mealTypes
        .map((type) => mealPlan.mealsForType(type))
        .where((list) => list.isNotEmpty)
        .map((list) => list.first)
        .toList();

    final totalCals = mealPlan.totalCaloriesActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...meals.map((item) => _MealRow(item: item, directive: directive)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$totalCals kcal total',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/meals/plan'),
              child: const Text('View Full Plan'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.item, required this.directive});
  final MealPlanItemEntity item;
  final MealDirective directive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? badge;
    if (item.mealType == 'breakfast' &&
        directive == MealDirective.extraCarbs) {
      badge = const _MacroBadge(label: '+ carbs', color: Colors.amber);
    } else if (directive == MealDirective.highProtein) {
      badge = const _MacroBadge(label: '+ protein', color: Colors.green);
    }

    return InkWell(
      onTap: () => context.push('/meals/plan'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.mealTypeDisplayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    item.name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 6), badge],
            if (item.calories != null) ...[
              const SizedBox(width: 8),
              Text(
                '${item.calories} kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  const _MacroBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _NoMealPlanContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No meal plan for today.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => context.push('/meals/plan'),
          child: const Text('Generate Meal Plan'),
        ),
      ],
    );
  }
}

class _DirectiveBadge extends StatelessWidget {
  const _DirectiveBadge({required this.directive});
  final MealDirective directive;

  @override
  Widget build(BuildContext context) {
    final label = _label(directive);
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
      ),
    );
  }

  String? _label(MealDirective directive) {
    switch (directive) {
      case MealDirective.standard:
        return null;
      case MealDirective.extraCarbs:
        return 'Extra Carbs';
      case MealDirective.highProtein:
        return 'High Protein';
      case MealDirective.light:
        return 'Light Meals';
      case MealDirective.grabAndGo:
        return 'Grab & Go';
      case MealDirective.hydrationFocus:
        return 'Hydration Focus';
    }
  }
}
