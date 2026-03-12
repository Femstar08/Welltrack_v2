import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'meal_prep_provider.dart';

class MealPrepScreen extends ConsumerStatefulWidget {
  const MealPrepScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<MealPrepScreen> createState() => _MealPrepScreenState();
}

class _MealPrepScreenState extends ConsumerState<MealPrepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(mealPrepProvider(widget.profileId).notifier)
          .loadWeek(_mondayOf(DateTime.now()));
    });
  }

  DateTime _mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  String _formatWeekLabel(DateTime monday) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final sunday = monday.add(const Duration(days: 6));
    final sameMonth = monday.month == sunday.month;
    if (sameMonth) {
      return '${months[monday.month - 1]} ${monday.day}–${sunday.day}';
    }
    return '${months[monday.month - 1]} ${monday.day} – ${months[sunday.month - 1]} ${sunday.day}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealPrepProvider(widget.profileId));
    final theme = Theme.of(context);
    final notifier = ref.read(mealPrepProvider(widget.profileId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Prep'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () => notifier.loadWeek(state.weekStart),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notifier.loadWeek(state.weekStart),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _WeekNavigator(
                    label: _formatWeekLabel(state.weekStart),
                    onPrevious: () => notifier.changeWeek(-1),
                    onNext: () => notifier.changeWeek(1),
                  ),
                  const SizedBox(height: 12),

                  _WeekOverviewCard(state: state),
                  const SizedBox(height: 20),

                  Text(
                    'Batch Cook Groups',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (state.weekPlans.isEmpty)
                    _NoPlansState(onTap: () => context.push('/meals/plan'))
                  else if (state.batchGroups.isEmpty)
                    const _EmptyBatchState()
                  else
                    ...state.batchGroups.asMap().entries.map(
                          (entry) => _BatchGroupCard(
                            group: entry.value,
                            onToggle: () =>
                                notifier.toggleGroupCompleted(entry.key),
                          ),
                        ),

                  if (state.shoppingItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Ingredients Needed',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _ShoppingSection(
                      items: state.shoppingItems,
                      onToggle: (i) => notifier.toggleShoppingItem(i),
                    ),
                  ],

                  if (state.daysWithPlans < 7 && state.weekPlans.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _GeneratePlansButton(
                      daysWithPlans: state.daysWithPlans,
                      onTap: () => context.push('/meals/plan'),
                    ),
                  ],

                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

// ── Week navigator ──────────────────────────────────────────────────────────

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Column(
          children: [
            Text(
              'Week of',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

// ── Week overview card ──────────────────────────────────────────────────────

class _WeekOverviewCard extends StatelessWidget {
  const _WeekOverviewCard({required this.state});

  final MealPrepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.kitchen_outlined,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.daysWithPlans} day${state.daysWithPlans == 1 ? '' : 's'} planned',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.totalMealsPlanned} total meals · '
                    '${state.batchCookableMeals} batch-cookable',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (state.batchGroups.isNotEmpty)
              Chip(
                label: Text(
                  '${state.batchGroups.where((g) => g.isCompleted).length}/'
                  '${state.batchGroups.length} done',
                  style: theme.textTheme.labelSmall,
                ),
                backgroundColor:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Batch group card ────────────────────────────────────────────────────────

class _BatchGroupCard extends StatefulWidget {
  const _BatchGroupCard({
    required this.group,
    required this.onToggle,
  });

  final BatchCookGroup group;
  final VoidCallback onToggle;

  @override
  State<_BatchGroupCard> createState() => _BatchGroupCardState();
}

class _BatchGroupCardState extends State<_BatchGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: AnimatedOpacity(
        opacity: group.isCompleted ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: group.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.servings} servings · covers ${group.meals.length} meals',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: group.isCompleted,
                    onChanged: (_) => widget.onToggle(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),

            // Time & storage chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  _TimeBadge(
                    icon: Icons.timer_outlined,
                    label: '${group.estimatedPrepMinutes}m prep',
                    color: Colors.blue.shade400,
                  ),
                  _TimeBadge(
                    icon: Icons.local_fire_department_outlined,
                    label: '${group.estimatedCookMinutes}m cook',
                    color: Colors.orange.shade400,
                  ),
                ],
              ),
            ),

            // Storage instructions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.storageInstructions,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Expandable meal list
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _expanded ? 'Hide meals' : 'Show meals',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            if (_expanded) ...[
              const Divider(height: 1),
              for (final meal in group.meals)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meal.name,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        meal.mealTypeDisplayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  const _TimeBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / no-plan states ──────────────────────────────────────────────────

class _EmptyBatchState extends StatelessWidget {
  const _EmptyBatchState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.no_meals_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No batch cooking opportunities this week',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Meals that repeat across days will be grouped here for efficient prep.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlansState extends StatelessWidget {
  const _NoPlansState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No meal plans this week',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate meal plans first and come back to see batch cooking opportunities.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Go to Meal Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shopping section ────────────────────────────────────────────────────────

class _ShoppingSection extends StatelessWidget {
  const _ShoppingSection({
    required this.items,
    required this.onToggle,
  });

  final List<PrepShoppingItem> items;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group indices by category preserving insertion order
    final categoryOrder = <String>[];
    final byCategory = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final category = items[i].category;
      if (!byCategory.containsKey(category)) {
        categoryOrder.add(category);
        byCategory[category] = [];
      }
      byCategory[category]!.add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in categoryOrder) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              category,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                for (var j = 0; j < byCategory[category]!.length; j++) ...[
                  if (j > 0) const Divider(height: 1, indent: 48),
                  _ShoppingItemRow(
                    item: items[byCategory[category]![j]],
                    onToggle: () => onToggle(byCategory[category]![j]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ShoppingItemRow extends StatelessWidget {
  const _ShoppingItemRow({required this.item, required this.onToggle});

  final PrepShoppingItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.isCrossedOff
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 20,
              color: item.isCrossedOff
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: item.isCrossedOff
                      ? TextDecoration.lineThrough
                      : null,
                  color: item.isCrossedOff
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : null,
                ),
              ),
            ),
            if (item.count > 1)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '×${item.count}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Generate plans CTA ──────────────────────────────────────────────────────

class _GeneratePlansButton extends StatelessWidget {
  const _GeneratePlansButton({
    required this.daysWithPlans,
    required this.onTap,
  });

  final int daysWithPlans;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = 7 - daysWithPlans;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: Text(
        'Generate meal plans for $missing more day${missing == 1 ? '' : 's'}',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: theme.colorScheme.primary,
      ),
    );
  }
}
