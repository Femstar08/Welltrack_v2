import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../workouts/data/workout_repository.dart';

class _WorkoutStats {
  const _WorkoutStats({
    required this.activePlanName,
    required this.todayExerciseCount,
    required this.completedThisWeek,
  });
  final String? activePlanName;
  final int todayExerciseCount;
  final int completedThisWeek;
}

final _workoutStatsProvider =
    FutureProvider.family<_WorkoutStats, String>((ref, profileId) async {
  final repo = ref.watch(workoutRepositoryProvider);

  // Get active plan
  final activePlan = await repo.getActivePlan(profileId);

  // Get today's exercise count from active plan
  int todayExercises = 0;
  if (activePlan != null) {
    final todayDow = DateTime.now().weekday;
    final exercises =
        await repo.getPlanExercises(activePlan.id, dayOfWeek: todayDow);
    todayExercises = exercises.length;
  }

  // Get completed workouts this week
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final completedWorkouts = await repo.getCompletedWorkouts(profileId, limit: 50);
  final thisWeek = completedWorkouts
      .where((w) =>
          w.completedAt != null && w.completedAt!.isAfter(startOfWeek))
      .length;

  return _WorkoutStats(
    activePlanName: activePlan?.name,
    todayExerciseCount: todayExercises,
    completedThisWeek: thisWeek,
  );
});

class WorkoutsCard extends ConsumerWidget {
  const WorkoutsCard({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_workoutStatsProvider(profileId));
    final theme = Theme.of(context);

    final stats = statsAsync.valueOrNull;
    final planName = stats?.activePlanName;
    final todayCount = stats?.todayExerciseCount ?? 0;
    final weekCount = stats?.completedThisWeek ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/workouts'),
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
                      'Workouts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.fitness_center,
                      label: 'Today',
                      value: todayCount > 0
                          ? '$todayCount exercises'
                          : 'Rest day',
                      color: todayCount > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    _StatItem(
                      icon: Icons.check_circle_outline,
                      label: 'This week',
                      value: '$weekCount sessions',
                      color: weekCount > 0
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),

                if (planName != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Chip(
                      avatar: Icon(
                        Icons.event_note,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      label: Text(
                        planName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],

                const Divider(height: 24),

                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push('/workouts'),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Today', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push('/workouts/exercises'),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Exercises', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push('/workouts/progress'),
                        icon: const Icon(Icons.bar_chart, size: 16),
                        label: const Text('Progress', style: TextStyle(fontSize: 12)),
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
          style: theme.textTheme.bodyMedium?.copyWith(
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
