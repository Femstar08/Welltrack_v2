import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'today_nutrition_provider.dart';
import '../../freemium/data/freemium_repository.dart';
import '../../freemium/domain/plan_tier.dart';
import '../../../shared/core/router/app_router.dart';

/// Detailed nutrition breakdown with tabs: Macros, Calories, Heart Healthy, Low Carb.
class NutritionDetailScreen extends ConsumerStatefulWidget {
  const NutritionDetailScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  ConsumerState<NutritionDetailScreen> createState() =>
      _NutritionDetailScreenState();
}

class _NutritionDetailScreenState extends ConsumerState<NutritionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['macros', 'calories', 'heart', 'lowcarb'];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexOf(widget.initialTab ?? 'macros');
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    final tierAsync = ref.watch(currentPlanTierProvider);
    final isPro = tierAsync.valueOrNull == PlanTier.pro;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Nutrition Details'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Macros'),
            Tab(text: 'Calories'),
            Tab(text: 'Heart'),
            Tab(text: 'Low Carb'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MacrosTab(profileId: profileId),
          _CaloriesTab(profileId: profileId),
          _GatedTab(
            isPro: isPro,
            title: 'Heart Healthy',
            description:
                'Track fat, sodium, and cholesterol for heart health',
            child: _HeartHealthyTab(profileId: profileId),
          ),
          _GatedTab(
            isPro: isPro,
            title: 'Low Carb',
            description: 'Track carbs, sugar, and fiber intake',
            child: _LowCarbTab(profileId: profileId),
          ),
        ],
      ),
    );
  }
}

class _MacrosTab extends ConsumerWidget {
  const _MacrosTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macrosAsync = ref.watch(todayMacroSummaryProvider(profileId));

    return macrosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (macros) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _MacroRow(
            label: 'Protein',
            consumed: macros.protein.consumed,
            goal: macros.protein.goal,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 16),
          _MacroRow(
            label: 'Carbs',
            consumed: macros.carbs.consumed,
            goal: macros.carbs.goal,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(height: 16),
          _MacroRow(
            label: 'Fat',
            consumed: macros.fat.consumed,
            goal: macros.fat.goal,
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  final String label;
  final int consumed;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.5) : 0.0;
    final remaining = goal - consumed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            Text(
              remaining >= 0 ? '${remaining}g left' : '${-remaining}g over',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: remaining >= 0
                    ? theme.colorScheme.onSurfaceVariant
                    : Colors.amber.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.15),
            color: remaining >= 0 ? color : Colors.amber.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${consumed}g / ${goal}g',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CaloriesTab extends ConsumerWidget {
  const _CaloriesTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caloriesAsync = ref.watch(todayCalorieSummaryProvider(profileId));

    return caloriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cal) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Text(
                '${cal.remaining}',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: !cal.isOver
                      ? theme.colorScheme.primary
                      : Colors.amber.shade700,
                ),
              ),
            ),
            Center(
              child: Text(
                cal.isOver ? 'Calories over' : 'Calories remaining',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _CalorieDetailRow(
              label: 'Goal',
              value: cal.adjustedGoal,
            ),
            _CalorieDetailRow(
              label: 'Consumed',
              value: -cal.consumed,
            ),
            const Divider(height: 32),
            _CalorieDetailRow(
              label: 'Remaining',
              value: cal.remaining,
              bold: true,
            ),
          ],
        );
      },
    );
  }
}

class _CalorieDetailRow extends StatelessWidget {
  const _CalorieDetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$value kcal', style: style),
        ],
      ),
    );
  }
}

class _HeartHealthyTab extends ConsumerWidget {
  const _HeartHealthyTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final microAsync = ref.watch(todayMicronutrientSummaryProvider(profileId));

    return microAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (micro) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Heart Healthy Tracking', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          _NutrientRow(label: 'Total Fat', value: micro.fatG?.toDouble(), unit: 'g'),
          _NutrientRow(label: 'Sodium', value: micro.sodiumMg?.toDouble(), unit: 'mg'),
          _NutrientRow(
              label: 'Cholesterol', value: micro.cholesterolMg?.toDouble(), unit: 'mg'),
        ],
      ),
    );
  }
}

class _LowCarbTab extends ConsumerWidget {
  const _LowCarbTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final microAsync = ref.watch(todayMicronutrientSummaryProvider(profileId));

    return microAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (micro) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Low Carb Tracking', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          _NutrientRow(label: 'Carbs', value: micro.carbsG?.toDouble(), unit: 'g'),
          _NutrientRow(label: 'Sugar', value: micro.sugarG?.toDouble(), unit: 'g'),
          _NutrientRow(label: 'Fiber', value: micro.fiberG?.toDouble(), unit: 'g'),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(
            value != null ? '${value!.toStringAsFixed(1)} $unit' : '--',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: value != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps PRO-gated tabs with upgrade prompt for free users.
class _GatedTab extends StatelessWidget {
  const _GatedTab({
    required this.isPro,
    required this.title,
    required this.description,
    required this.child,
  });

  final bool isPro;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isPro) return child;

    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/paywall'),
              child: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      ),
    );
  }
}
