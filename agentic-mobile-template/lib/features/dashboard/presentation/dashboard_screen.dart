import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/core/theme/app_colors.dart';
import 'dashboard_home_provider.dart';
import 'dashboard_provider.dart';
import 'widgets/shimmer_loading.dart';
import 'widgets/secondary_modules_list.dart';
import 'widgets/pantry_recipe_card.dart';
import 'widgets/workouts_card.dart';
import 'widgets/daily_coach_card.dart';
import 'widgets/dashboard_scenario_nudges.dart';
import 'widgets/nutrition_summary_carousel.dart';
import '../../goals/domain/goal_entity.dart';
import '../../goals/presentation/goals_provider.dart';
import '../../habits/presentation/habit_provider.dart';
import '../../bloodwork/presentation/bloodwork_provider.dart';

/// Main dashboard screen showing goal-adaptive metrics and module tiles
/// Designed with the "Obsidian Vitality" Design System
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    required this.profileId,
    required this.displayName,
  });
  final String profileId;
  final String displayName;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(dashboardProvider.notifier).initialize(widget.profileId));
      unawaited(ref.read(dashboardHomeProvider.notifier).initialize(widget.profileId));
    });
  }

  Future<void> _handleRefresh() async {
    unawaited(HapticFeedback.mediumImpact());
    await Future.wait([
      ref.read(dashboardProvider.notifier).refresh(widget.profileId),
      ref.read(dashboardHomeProvider.notifier).refresh(widget.profileId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(dashboardHomeProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: homeState.isLoading
            ? const DashboardShimmer()
            : CustomScrollView(
                slivers: [
                  // App Bar / Header Intro
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 60, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning,',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                          ),
                          Text(
                            widget.displayName,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.textPrimaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Nutrition Carousel
                  SliverToBoxAdapter(
                    child: NutritionSummaryCarousel(profileId: widget.profileId),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // 2. Metrics Row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildMetricsRow(context),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // 3. Weight Trend Chart
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildWeightTrendChart(context),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // 4a. Bloodwork Summary Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildBloodworkSummary(context),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 4b. Habit Streak
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildHabitStreak(context),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // 5. Discover Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildDiscoverGrid(context),
                    ),
                  ),

                  // 6. Restored Core Features
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Column(
                        children: [
                          DailyCoachCard(profileId: widget.profileId),
                          const SizedBox(height: 8),
                          DashboardScenarioNudges(profileId: widget.profileId),
                          const SizedBox(height: 8),
                          _GoalsSummaryCard(profileId: widget.profileId),
                          const SizedBox(height: 24),
                          WorkoutsCard(profileId: widget.profileId),
                          const SizedBox(height: 24),
                          PantryRecipeCard(profileId: widget.profileId),
                          const SizedBox(height: 24),
                          SecondaryModulesList(tiles: ref.watch(dashboardProvider).tiles),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassMetricCard(
            context,
            icon: Icons.directions_walk,
            iconColor: AppColors.secondary,
            value: '12,450',
            label: 'Steps',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassMetricCard(
            context,
            icon: Icons.local_fire_department,
            iconColor: AppColors.primary,
            value: '850',
            label: 'kcal',
            subtitle: 'Exercise',
          ),
        ),
      ],
    );
  }

  Widget _buildGlassMetricCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? subtitle,
  }) {
    // Glassmorphism effect via ClipRRect & BackdropFilter, layered on surfaceContainerLow
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                subtitle ?? label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightTrendChart(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weight Trend',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '90 Days',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 85),
                      FlSpot(1, 84.5),
                      FlSpot(2, 83.8),
                      FlSpot(3, 83.0),
                      FlSpot(4, 82.5),
                      FlSpot(5, 81.2),
                    ],
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.secondary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitStreak(BuildContext context) {
    final habitsState = ref.watch(habitProvider(widget.profileId));
    final activeHabits = habitsState.habits;

    // Empty state: no active habits
    if (activeHabits.isEmpty) {
      return GestureDetector(
        onTap: () => context.push('/habits'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.textSecondaryDark, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Start tracking habits',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondaryDark),
            ],
          ),
        ),
      );
    }

    // Find habit with best active streak
    final bestHabit = activeHabits.reduce(
      (a, b) => a.currentStreakDays >= b.currentStreakDays ? a : b,
    );
    final streakDays = bestHabit.currentStreakDays;

    return GestureDetector(
      onTap: () => context.push('/habits'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 0,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: AppColors.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streakDays > 0
                        ? '$streakDays-Day Streak!'
                        : '${activeHabits.length} Active Habits',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    streakDays > 0
                        ? 'Keep going with ${bestHabit.habitLabel ?? bestHabit.habitType}'
                        : 'Tap to check in today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodworkSummary(BuildContext context) {
    final bwState = ref.watch(bloodworkProvider(widget.profileId));
    final flaggedCount = bwState.outOfRangeCount;
    final totalResults = bwState.results.length;

    // Empty state: no bloodwork results
    if (totalResults == 0) {
      return GestureDetector(
        onTap: () => context.push('/bloodwork'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.biotech_outlined, color: AppColors.textSecondaryDark, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Log your first blood test',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondaryDark),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/bloodwork'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: flaggedCount > 0
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                flaggedCount > 0 ? Icons.warning_amber : Icons.check_circle,
                color: flaggedCount > 0 ? Colors.red : Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bloodwork',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flaggedCount > 0
                        ? '$flaggedCount result${flaggedCount == 1 ? '' : 's'} out of range'
                        : 'All results in range',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: flaggedCount > 0 ? Colors.red : AppColors.textSecondaryDark,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discover',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildDiscoverTile(context, 'Sleep', Icons.bedtime, AppColors.sleepTile, '/health/sleep'),
            _buildDiscoverTile(context, 'Recipes', Icons.restaurant_menu, AppColors.mealsTile, '/recipes'),
            _buildDiscoverTile(context, 'Workouts', Icons.fitness_center, AppColors.workoutsTile, '/workouts'),
            _buildDiscoverTile(context, 'Recovery', Icons.spa, AppColors.secondary, '/recovery-detail'),
          ],
        ),
      ],
    );
  }

  Widget _buildDiscoverTile(BuildContext context, String title, IconData icon, Color color, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsSummaryCard extends ConsumerWidget {
  const _GoalsSummaryCard({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider(profileId));
    final theme = Theme.of(context);

    final goals = goalsAsync.valueOrNull ?? [];
    final isLoading = goalsAsync is AsyncLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/goals'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Goals',
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
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (goals.isEmpty)
                  _buildEmptyGoals(context, theme)
                else ...[
                  ...goals.take(3).map(
                        (goal) => _buildGoalRow(context, theme, goal),
                      ),
                  if (goals.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'View all ${goals.length} goals',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGoals(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => context.push('/goals/create'),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Set your first goal',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(
    BuildContext context,
    ThemeData theme,
    GoalEntity goal,
  ) {
    final progress = goal.targetValue != 0
        ? (goal.currentValue / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;
    final statusColor = _statusColor(goal.statusColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            _iconForMetricType(goal.metricType),
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              goal.metricDisplayName,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              goal.statusLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.amber.shade700;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static IconData _iconForMetricType(String type) {
    switch (type) {
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'vo2max':
        return Icons.speed;
      case 'steps':
        return Icons.directions_walk;
      case 'sleep':
        return Icons.bedtime_outlined;
      case 'hr':
        return Icons.monitor_heart_outlined;
      case 'hrv':
        return Icons.timeline;
      case 'calories':
        return Icons.local_fire_department_outlined;
      case 'distance':
        return Icons.straighten;
      case 'active_minutes':
        return Icons.timer_outlined;
      case 'body_fat':
        return Icons.percent;
      case 'blood_pressure':
        return Icons.bloodtype;
      case 'spo2':
        return Icons.air;
      case 'stress':
        return Icons.self_improvement;
      default:
        return Icons.flag_outlined;
    }
  }
}
