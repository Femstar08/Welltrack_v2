import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:welltrack/features/dashboard/presentation/dashboard_home_provider.dart';
import 'package:welltrack/features/dashboard/presentation/dashboard_provider.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/intelligence_insight_card.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/key_signals_grid.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/secondary_modules_list.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/shimmer_loading.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/today_summary_card.dart';
import 'package:welltrack/features/dashboard/presentation/widgets/trends_preview_card.dart';
import 'package:welltrack/features/goals/domain/goal_entity.dart';
import 'package:welltrack/features/goals/presentation/goals_provider.dart';

/// Main dashboard screen showing goal-adaptive metrics and module tiles.
class DashboardScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String displayName;

  const DashboardScreen({
    super.key,
    required this.profileId,
    required this.displayName,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).initialize(widget.profileId);
      ref.read(dashboardHomeProvider.notifier).initialize(widget.profileId);
    });
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await Future.wait([
      ref.read(dashboardProvider.notifier).refresh(widget.profileId),
      ref.read(dashboardHomeProvider.notifier).refresh(widget.profileId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(dashboardHomeProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: homeState.isLoading
            ? const DashboardShimmer()
            : CustomScrollView(
                slivers: [
                  // Section 1: Today Summary
                  SliverToBoxAdapter(
                    child: TodaySummaryCard(
                      displayName: widget.displayName,
                      primaryMetric: homeState.primaryMetric,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 2: Key Signals Grid
                  SliverToBoxAdapter(
                    child: KeySignalsGrid(signals: homeState.keySignals),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 3: Intelligence Insight
                  SliverToBoxAdapter(
                    child: IntelligenceInsightCard(
                      insightText: homeState.insightText,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 4: Trends Preview
                  SliverToBoxAdapter(
                    child: TrendsPreviewCard(
                      trendData: homeState.trendData,
                      trendLabel: homeState.trendLabel,
                      trendDirection: homeState.trendDirection,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 5: Goals Summary
                  SliverToBoxAdapter(
                    child: _GoalsSummaryCard(
                      profileId: widget.profileId,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Section 6: Secondary Modules
                  SliverToBoxAdapter(
                    child: SecondaryModulesList(tiles: dashboard.tiles),
                  ),

                  // Bottom padding for scroll clearance
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _handleBottomNavTap(index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            activeIcon: Icon(Icons.edit_note),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        break; // Already on dashboard
      case 1:
        context.push('/daily-view');
      case 2:
        context.push('/insights');
      case 3:
        context.push('/profile');
    }
    // Reset index so Home tab stays highlighted when returning
    if (index != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }
}

class _GoalsSummaryCard extends ConsumerWidget {
  final String profileId;

  const _GoalsSummaryCard({required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider(profileId));
    final theme = Theme.of(context);

    return goalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (goals) {
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
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (goals.isEmpty)
                      _buildEmptyGoals(context, theme)
                    else
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
                ),
              ),
            ),
          ),
        );
      },
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
              color: statusColor.withOpacity(0.15),
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
