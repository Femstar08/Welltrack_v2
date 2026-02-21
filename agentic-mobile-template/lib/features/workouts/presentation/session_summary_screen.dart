// lib/features/workouts/presentation/session_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/overload_suggestion_entity.dart';
import '../domain/workout_entity.dart';
import '../domain/workout_log_entity.dart';
import '../data/workout_repository.dart';
import 'overload_suggestions_provider.dart';

// ── Summary data model ────────────────────────────────────────────────────────

/// Lightweight summary passed from the logging screen via GoRouter extra.
/// All fields are optional so the screen degrades gracefully.
class WorkoutSummaryData {
  const WorkoutSummaryData({
    required this.workoutId,
    this.profileId,
    this.workoutName,
    this.durationMinutes,
    this.totalSets,
    this.totalVolumeKg,
    this.exercisesCompleted,
    this.newPrExerciseNames = const [],
    this.muscleGroupsWorked = const [],
    this.exerciseEntries = const [],
  });

  factory WorkoutSummaryData.fromMap(
    String workoutId,
    Map<String, dynamic> map,
  ) {
    return WorkoutSummaryData(
      workoutId: workoutId,
      profileId: map['profileId'] as String?,
      workoutName: map['workoutName'] as String?,
      durationMinutes: map['durationMinutes'] as int?,
      totalSets: map['totalSets'] as int?,
      totalVolumeKg: map['totalVolumeKg'] != null
          ? (map['totalVolumeKg'] as num).toDouble()
          : null,
      exercisesCompleted: map['exercisesCompleted'] as int?,
      newPrExerciseNames:
          (map['newPrExerciseNames'] as List?)?.cast<String>() ?? [],
      muscleGroupsWorked:
          (map['muscleGroupsWorked'] as List?)?.cast<String>() ?? [],
      exerciseEntries: (map['exerciseEntries'] as List?)
              ?.map((e) => (
                    exerciseId: e['exerciseId'] as String,
                    exerciseName: e['exerciseName'] as String,
                  ))
              .toList() ??
          [],
    );
  }

  final String workoutId;
  final String? profileId;
  final String? workoutName;
  final int? durationMinutes;
  final int? totalSets;
  final double? totalVolumeKg;
  final int? exercisesCompleted;
  final List<String> newPrExerciseNames;
  final List<String> muscleGroupsWorked;

  /// Exercise ID + name pairs for overload suggestion queries.
  final List<({String exerciseId, String exerciseName})> exerciseEntries;
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches the workout entity to back-fill any missing summary fields.
final _summaryWorkoutProvider =
    FutureProvider.family<WorkoutEntity, String>((ref, workoutId) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getWorkout(workoutId);
});

/// Fetches workout logs to calculate totals when not supplied via extra.
final _summaryLogsProvider =
    FutureProvider.family<List<WorkoutLogEntity>, String>(
        (ref, workoutId) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getWorkoutLogs(workoutId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.workoutId, super.key});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Attempt to read summary data from GoRouter extra.
    WorkoutSummaryData? summaryData;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      summaryData = WorkoutSummaryData.fromMap(workoutId, extra);
    } else if (extra is WorkoutSummaryData) {
      summaryData = extra;
    }

    final workoutAsync = ref.watch(_summaryWorkoutProvider(workoutId));
    final logsAsync = ref.watch(_summaryLogsProvider(workoutId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Session Summary'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon.')),
              );
            },
          ),
        ],
      ),
      body: workoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _SummaryError(
          onDone: () => context.go('/workouts'),
        ),
        data: (workout) {
          // Merge supplied data with fetched workout data.
          final name = summaryData?.workoutName ?? workout.name;
          final durationMin =
              summaryData?.durationMinutes ?? workout.durationMinutes;

          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _SummaryBody(
              workoutName: name,
              durationMinutes: durationMin,
              summaryData: summaryData,
              logs: const [],
              onDone: () => context.go('/workouts'),
            ),
            data: (logs) => _SummaryBody(
              workoutName: name,
              durationMinutes: durationMin,
              summaryData: summaryData,
              logs: logs,
              onDone: () => context.go('/workouts'),
            ),
          );
        },
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({
    required this.workoutName,
    required this.durationMinutes,
    required this.summaryData,
    required this.logs,
    required this.onDone,
  });

  final String workoutName;
  final int? durationMinutes;
  final WorkoutSummaryData? summaryData;
  final List<WorkoutLogEntity> logs;
  final VoidCallback onDone;

  // ── Computed values ───────────────────────────────────────────────

  int get _totalSets {
    if (summaryData?.totalSets != null) return summaryData!.totalSets!;
    return logs.fold<int>(0, (sum, l) => sum + (l.sets ?? 1));
  }

  double get _totalVolumeKg {
    if (summaryData?.totalVolumeKg != null) return summaryData!.totalVolumeKg!;
    return logs.fold<double>(0, (sum, l) {
      final sets = l.sets ?? 1;
      final reps = l.reps ?? 0;
      final weight = l.weightKg ?? 0;
      return sum + (sets * reps * weight);
    });
  }

  int get _exercisesCompleted {
    if (summaryData?.exercisesCompleted != null) {
      return summaryData!.exercisesCompleted!;
    }
    return logs.length;
  }

  List<String> get _prExercises => summaryData?.newPrExerciseNames ?? [];

  List<String> get _muscleGroups {
    if (summaryData?.muscleGroupsWorked.isNotEmpty == true) {
      return summaryData!.muscleGroupsWorked;
    }
    // Derive from log exercise names as fallback (no muscle data available here).
    return [];
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Overload suggestions — only query if we have exercise data.
    final profileId = summaryData?.profileId;
    final entries = summaryData?.exerciseEntries ?? [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Celebration header ─────────────────────────────────
            _CelebrationHeader(workoutName: workoutName),
            const SizedBox(height: 28),

            // ── Stat cards grid ────────────────────────────────────
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              children: [
                _StatCard(
                  icon: Icons.timer_outlined,
                  value: durationMinutes != null
                      ? '${durationMinutes} min'
                      : '--',
                  label: 'Duration',
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatCard(
                  icon: Icons.monitor_weight_outlined,
                  value: _totalVolumeKg > 0
                      ? '${_totalVolumeKg.toStringAsFixed(0)} kg'
                      : '--',
                  label: 'Total Volume',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                _StatCard(
                  icon: Icons.layers_outlined,
                  value: _totalSets > 0 ? '$_totalSets' : '--',
                  label: 'Sets Done',
                  color: Colors.orange.shade700,
                ),
                _StatCard(
                  icon: Icons.sports_gymnastics,
                  value: _exercisesCompleted > 0
                      ? '$_exercisesCompleted'
                      : '--',
                  label: 'Exercises',
                  color: Colors.teal.shade600,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── New personal records ───────────────────────────────
            if (_prExercises.isNotEmpty) ...[
              _PrSection(prExercises: _prExercises),
              const SizedBox(height: 24),
            ],

            // ── Smart overload suggestions ─────────────────────────
            if (profileId != null && entries.isNotEmpty)
              _OverloadSuggestionsSection(
                profileId: profileId,
                exercises: entries,
              ),

            // ── Muscle groups worked ───────────────────────────────
            if (_muscleGroups.isNotEmpty) ...[
              _MuscleGroupsSection(muscles: _muscleGroups),
              const SizedBox(height: 24),
            ],

            // ── Exercises logged (from logs) ───────────────────────
            if (logs.isNotEmpty) ...[
              _ExercisesLoggedSection(logs: logs),
              const SizedBox(height: 24),
            ],

            // ── Done button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Celebration header ────────────────────────────────────────────────────────

class _CelebrationHeader extends StatelessWidget {
  const _CelebrationHeader({required this.workoutName});
  final String workoutName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.celebration,
            size: 30,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout Complete!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                workoutName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PR section ────────────────────────────────────────────────────────────────

class _PrSection extends StatelessWidget {
  const _PrSection({required this.prExercises});
  final List<String> prExercises;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade300.withValues(alpha: 0.3),
            Colors.orange.shade400.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text(
                'New Personal Records!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...prExercises.map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
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
}

// ── Muscle groups section ─────────────────────────────────────────────────────

class _MuscleGroupsSection extends StatelessWidget {
  const _MuscleGroupsSection({required this.muscles});
  final List<String> muscles;

  // Deterministic colour per muscle group for visual consistency.
  Color _muscleColor(String muscle) {
    const colorMap = <String, Color>{
      'chest': Colors.blue,
      'back': Colors.green,
      'shoulders': Colors.purple,
      'arms': Colors.orange,
      'legs': Colors.red,
      'core': Colors.teal,
      'biceps': Colors.orange,
      'triceps': Colors.deepOrange,
      'quads': Colors.red,
      'hamstrings': Colors.redAccent,
      'glutes': Colors.pink,
      'calves': Colors.brown,
    };
    return colorMap[muscle.toLowerCase()] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muscles Worked',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: muscles.map((m) {
            final color = _muscleColor(m);
            return Chip(
              label: Text(
                _sentenceCase(m),
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: color.withValues(alpha: 0.12),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _sentenceCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Exercises logged section ──────────────────────────────────────────────────

class _ExercisesLoggedSection extends StatelessWidget {
  const _ExercisesLoggedSection({required this.logs});
  final List<WorkoutLogEntity> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercises Logged',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        ...logs.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value.exerciseName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            entry.value.displaySummary,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ── Overload suggestions section ─────────────────────────────────────────

class _OverloadSuggestionsSection extends ConsumerWidget {
  const _OverloadSuggestionsSection({
    required this.profileId,
    required this.exercises,
  });

  final String profileId;
  final List<({String exerciseId, String exerciseName})> exercises;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = OverloadSuggestionsParams(
      profileId: profileId,
      exercises: exercises,
    );
    final suggestionsAsync = ref.watch(overloadSuggestionsProvider(params));

    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade300.withValues(alpha: 0.2),
                  Colors.indigo.shade400.withValues(alpha: 0.15),
                ],
              ),
              border:
                  Border.all(color: Colors.blue.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up,
                        color: Colors.blue.shade700, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Progressive Overload',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...suggestions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OverloadSuggestionTile(suggestion: s),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverloadSuggestionTile extends StatelessWidget {
  const _OverloadSuggestionTile({required this.suggestion});
  final OverloadSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.fitness_center,
            size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.exerciseName,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${suggestion.summary} — ${suggestion.suggestion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load session data.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onDone,
              child: const Text('Back to Workouts'),
            ),
          ],
        ),
      ),
    );
  }
}
