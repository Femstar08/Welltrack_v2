// lib/features/daily_view/presentation/daily_view_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../features/meals/presentation/today_nutrition_provider.dart';
import '../../../features/insights/presentation/today_recovery_score_provider.dart';
import '../../../features/habits/presentation/habit_provider.dart';
import 'daily_view_provider.dart';

class DailyViewScreen extends ConsumerStatefulWidget {
  const DailyViewScreen({
    required this.profileId,
    super.key,
  });
  final String profileId;

  @override
  ConsumerState<DailyViewScreen> createState() => _DailyViewScreenState();
}

class _DailyViewScreenState extends ConsumerState<DailyViewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      unawaited(ref
          .read(dailyViewProvider(widget.profileId).notifier)
          .loadDailyData());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyViewProvider(widget.profileId));
    final recoveryScore =
        ref.watch(todayRecoveryScoreProvider(widget.profileId));
    final macrosAsync =
        ref.watch(todayMacroSummaryProvider(widget.profileId));
    final caloriesAsync =
        ref.watch(todayCalorieSummaryProvider(widget.profileId));
    final habitsState = ref.watch(habitProvider(widget.profileId));

    return Scaffold(
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(dailyViewProvider(widget.profileId).notifier)
                  .loadDailyData(),
              child: CustomScrollView(
                slivers: [
                  // Header with date selector
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: MediaQuery.paddingOf(context).top + 16,
                        bottom: 8,
                      ),
                      child: _DateHeader(
                        date: state.selectedDate,
                        onPrevious: () => ref
                            .read(dailyViewProvider(widget.profileId).notifier)
                            .goToPreviousDay(),
                        onNext: () => ref
                            .read(dailyViewProvider(widget.profileId).notifier)
                            .goToNextDay(),
                      ),
                    ),
                  ),

                  // Recovery score banner
                  if (recoveryScore != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: _RecoveryBanner(score: recoveryScore),
                      ),
                    ),

                  // Calorie summary card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: caloriesAsync.when(
                        loading: () => _buildShimmerCard(160),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (cal) => _CalorieSummaryCard(calories: cal),
                      ),
                    ),
                  ),

                  // Macro progress bars
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: macrosAsync.when(
                        loading: () => _buildShimmerCard(120),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (macros) => _MacroProgressCard(macros: macros),
                      ),
                    ),
                  ),

                  // Quick actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: _QuickActionsRow(profileId: widget.profileId),
                    ),
                  ),

                  // Meals section
                  if (state.mealsSummary != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: _MealsSection(summary: state.mealsSummary!),
                      ),
                    ),

                  // Habits section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: _HabitsSection(
                        habits: habitsState.habits,
                        todayLogs: habitsState.todayLogs,
                        onToggle: (habitType) => ref
                            .read(habitProvider(widget.profileId).notifier)
                            .toggleHabitToday(habitType),
                      ),
                    ),
                  ),

                  // Health metrics (single instance)
                  if (state.healthMetrics != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: _HealthMetricsCard(
                            metrics: state.healthMetrics!),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildShimmerCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date Header
// ---------------------------------------------------------------------------

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(d.year, d.month, d.day);
    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (selected == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _dayOfWeek(DateTime d) {
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return days[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous day',
          onPressed: onPrevious,
        ),
        Column(
          children: [
            Text(
              _formatDate(date),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            Text(
              _dayOfWeek(date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next day',
          onPressed: onNext,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recovery Banner
// ---------------------------------------------------------------------------

class _RecoveryBanner extends StatelessWidget {
  const _RecoveryBanner({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getRecoveryColor(score);
    final label = score >= 80
        ? 'Excellent'
        : score >= 60
            ? 'Good'
            : score >= 40
                ? 'Moderate'
                : 'Low';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            '$label — Recovery ${score.toInt()}%',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calorie Summary Card
// ---------------------------------------------------------------------------

class _CalorieSummaryCard extends StatelessWidget {
  const _CalorieSummaryCard({required this.calories});
  final CalorieSummary calories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = calories.remaining;
    final isOver = calories.isOver;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${remaining.abs()}',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isOver ? AppColors.warning : AppColors.primary,
            ),
          ),
          Text(
            isOver ? 'Calories over' : 'Calories remaining',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CalorieDetail(label: 'Goal', value: calories.adjustedGoal),
              _CalorieDetail(label: 'Consumed', value: calories.consumed),
              _CalorieDetail(
                  label: 'Remaining', value: remaining, bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieDetail extends StatelessWidget {
  const _CalorieDetail({
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
    return Column(
      children: [
        Text(
          '$value',
          style: (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
              ?.copyWith(fontWeight: bold ? FontWeight.bold : null),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Macro Progress Card
// ---------------------------------------------------------------------------

class _MacroProgressCard extends StatelessWidget {
  const _MacroProgressCard({required this.macros});
  final ({MacroSummary protein, MacroSummary carbs, MacroSummary fat}) macros;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macros',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _MacroBar(
            label: 'Protein',
            consumed: macros.protein.consumed,
            goal: macros.protein.goal,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _MacroBar(
            label: 'Carbs',
            consumed: macros.carbs.consumed,
            goal: macros.carbs.goal,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 12),
          _MacroBar(
            label: 'Fat',
            consumed: macros.fat.consumed,
            goal: macros.fat.goal,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
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
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = goal - consumed;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              remaining >= 0 ? '${remaining}g left' : '${-remaining}g over',
              style: theme.textTheme.bodySmall?.copyWith(
                color: remaining >= 0
                    ? AppColors.textSecondaryDark
                    : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            color: remaining >= 0 ? color : AppColors.warning,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Actions
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.restaurant_rounded,
            label: 'Log Meal',
            onTap: () => context.push('/meals/food-search'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.menu_book_rounded,
            label: 'Meal Plan',
            onTap: () => context.push('/meals/plan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.water_drop_rounded,
            label: 'Water',
            onTap: () => context.push('/water/log'),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meals Section
// ---------------------------------------------------------------------------

class _MealsSection extends StatelessWidget {
  const _MealsSection({required this.summary});
  final MealsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meals',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${summary.loggedCount}/${summary.plannedCount} logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...summary.plannedMeals.map((meal) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(meal, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Habits Section
// ---------------------------------------------------------------------------

class _HabitsSection extends StatelessWidget {
  const _HabitsSection({
    required this.habits,
    required this.todayLogs,
    required this.onToggle,
  });
  final List<dynamic> habits;
  final Map<String, bool> todayLogs;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (habits.isEmpty) return const SizedBox.shrink();

    final completedCount =
        todayLogs.values.where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Habits',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$completedCount/${habits.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...habits.map((habit) {
            final type = habit.habitType as String;
            final label = (habit.habitLabel as String?) ?? type.replaceAll('_', ' ');
            final done = todayLogs[type] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onToggle(type),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 20,
                      color: done ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health Metrics Card (single instance, no duplicates)
// ---------------------------------------------------------------------------

class _HealthMetricsCard extends StatelessWidget {
  const _HealthMetricsCard({required this.metrics});
  final HealthMetricsSummary metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Metrics',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.bedtime_rounded,
                  label: 'Sleep',
                  value: metrics.sleepDisplay,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.directions_walk_rounded,
                  label: 'Steps',
                  value: metrics.stepsDisplay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.favorite_rounded,
                  label: 'Heart Rate',
                  value: metrics.heartRate != null
                      ? '${metrics.heartRate!.toStringAsFixed(0)} bpm'
                      : '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.psychology_rounded,
                  label: 'Stress',
                  value: metrics.stressScore != null
                      ? '${metrics.stressScore!.toStringAsFixed(0)}/100'
                      : '--',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryDark,
          )),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
