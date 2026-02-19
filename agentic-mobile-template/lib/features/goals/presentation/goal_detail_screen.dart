import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:welltrack/features/goals/domain/goal_entity.dart';
import 'package:welltrack/features/goals/presentation/goals_provider.dart';
import 'package:welltrack/features/goals/presentation/widgets/goal_projection_chart.dart';
import 'package:welltrack/features/freemium/presentation/freemium_gate_widget.dart';
import 'package:welltrack/shared/core/constants/feature_flags.dart';
import 'package:welltrack/shared/core/router/app_router.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalDetailProvider(goalId));

    return goalAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error loading goal: $error')),
      ),
      data: (goal) {
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Goal not found')),
          );
        }
        return _GoalDetailContent(goal: goal);
      },
    );
  }
}

class _GoalDetailContent extends ConsumerWidget {
  final GoalEntity goal;

  const _GoalDetailContent({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final forecast = goal.forecast;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.metricDisplayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // Navigate to edit screen - push with goal data
              final profileId = ref.read(activeProfileIdProvider) ?? '';
              context.push('/goals/create', extra: goal);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            _buildHeaderCard(context, theme),
            const SizedBox(height: 16),

            // Status section
            _buildStatusCard(context, theme),
            const SizedBox(height: 16),

            // Projection chart (Pro feature)
            FreemiumGateInline(
              featureName: FeatureFlags.forecasting,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projection',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: GoalProjectionChart(goal: goal),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Projection text (Pro feature)
            FreemiumGateInline(
              featureName: FeatureFlags.forecasting,
              child: _buildProjectionText(theme),
            ),
            const SizedBox(height: 16),

            // Model quality
            if (forecast != null) _buildModelQuality(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ThemeData theme) {
    final progress = goal.targetValue != 0
        ? (goal.currentValue / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress ring
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              goal.metricDisplayName,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${goal.currentValue} → ${goal.targetValue} ${goal.unit}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (goal.goalDescription != null &&
                goal.goalDescription!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                goal.goalDescription!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ThemeData theme) {
    final forecast = goal.forecast;
    final statusColor = _getStatusColor(goal.statusColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Trend arrow
                Icon(
                  forecast != null && forecast.isMovingTowardTarget
                      ? Icons.trending_up
                      : forecast != null && forecast.slope.abs() < 0.01
                          ? Icons.trending_flat
                          : Icons.trending_down,
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    goal.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (forecast != null) ...[
              const SizedBox(height: 12),
              _buildStatusRow(
                theme,
                'Weekly velocity',
                '${(forecast.slope * 7).toStringAsFixed(2)} ${goal.unit}/week',
              ),
              const SizedBox(height: 4),
              _buildStatusRow(
                theme,
                'Confidence',
                forecast.confidenceDescription,
              ),
              if (goal.deadline != null) ...[
                const SizedBox(height: 4),
                _buildStatusRow(
                  theme,
                  'Deadline',
                  '${goal.deadline!.day}/${goal.deadline!.month}/${goal.deadline!.year}',
                ),
              ],
            ],
            if (forecast == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Insufficient data for projection. Keep logging your metrics!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectionText(ThemeData theme) {
    final forecast = goal.forecast;
    if (forecast == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forecast',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              forecast.projectionMessage,
              style: theme.textTheme.bodyLarge,
            ),
            if (forecast.projectedDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Projected date: ${forecast.projectedDate!.day}/${forecast.projectedDate!.month}/${forecast.projectedDate!.year}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelQuality(ThemeData theme) {
    final forecast = goal.forecast!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Model Quality',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              'R² = ${forecast.rSquared.toStringAsFixed(2)} — ${forecast.modelQuality}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String colorName) {
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content:
            const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final profileId = ref.read(activeProfileIdProvider) ?? '';
              ref
                  .read(goalsProvider(profileId).notifier)
                  .deleteGoal(goal.id);
              context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
