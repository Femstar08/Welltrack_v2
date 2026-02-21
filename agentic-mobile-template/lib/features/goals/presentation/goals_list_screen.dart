import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/goal_entity.dart';
import 'goals_provider.dart';

class GoalsListScreen extends ConsumerWidget {

  const GoalsListScreen({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/goals/create'),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load goals: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              unawaited(
                Future(() =>
                    ref.read(goalsProvider(profileId).notifier).refresh()),
              );
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) => _GoalCard(goal: goals[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No goals set',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first goal.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/goals/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {

  const _GoalCard({required this.goal});
  final GoalEntity goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _calculateProgress();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/goals/${goal.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Metric icon
              CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primaryContainer,
                child: Icon(
                  _iconForMetricType(goal.metricType),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metric name + description
                    Text(
                      goal.metricDisplayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (goal.goalDescription != null &&
                        goal.goalDescription!.isNotEmpty)
                      Text(
                        goal.goalDescription!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status + projected date
                    Row(
                      children: [
                        _StatusChip(
                          label: goal.statusLabel,
                          color: _statusColor(goal.statusColor),
                        ),
                        const SizedBox(width: 8),
                        if (goal.forecast != null)
                          Expanded(
                            child: Text(
                              goal.forecast!.projectionMessage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgress() {
    // Use the entity's progressPercentage (0-100) and convert to 0-1
    return (goal.progressPercentage / 100).clamp(0.0, 1.0);
  }

  Color _statusColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.amber;
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

class _StatusChip extends StatelessWidget {

  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
