// lib/features/workouts/presentation/workout_plan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/workout_plan_exercise_entity.dart';
import '../domain/exercise_entity.dart';
import '../data/workout_repository.dart';
import 'plan_provider.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class WorkoutPlanDetailScreen extends ConsumerStatefulWidget {
  const WorkoutPlanDetailScreen({required this.planId, super.key});
  final String planId;

  @override
  ConsumerState<WorkoutPlanDetailScreen> createState() =>
      _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState
    extends ConsumerState<WorkoutPlanDetailScreen> {
  // Track which day cards are expanded.
  final Set<int> _expandedDays = {DateTime.now().weekday};

  // Locally cached plan meta passed via GoRouter extra (populated by router).
  String _planName = 'Workout Plan';
  String? _planDescription;
  bool _isActive = false;
  String? _profileId;

  static const List<_DayMeta> _days = [
    _DayMeta(dow: 1, label: 'Monday'),
    _DayMeta(dow: 2, label: 'Tuesday'),
    _DayMeta(dow: 3, label: 'Wednesday'),
    _DayMeta(dow: 4, label: 'Thursday'),
    _DayMeta(dow: 5, label: 'Friday'),
    _DayMeta(dow: 6, label: 'Saturday'),
    _DayMeta(dow: 7, label: 'Sunday'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attempt to read route extra for plan metadata.
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _planName = extra['planName'] as String? ?? _planName;
      _planDescription = extra['planDescription'] as String?;
      _isActive = extra['isActive'] as bool? ?? _isActive;
      _profileId = extra['profileId'] as String?;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Future<void> _setActive() async {
    if (_profileId == null) return;
    final repo = ref.read(workoutRepositoryProvider);
    try {
      await repo.setActivePlan(_profileId!, widget.planId);
      setState(() => _isActive = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$_planName" is now your active plan.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
          'Are you sure you want to delete "$_planName"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final repo = ref.read(workoutRepositoryProvider);
      try {
        await repo.deletePlan(widget.planId);
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting plan: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showAddExerciseSheet(int dayOfWeek) async {
    final result = await context.push<ExerciseEntity>(
      '/workouts/exercises?selectMode=true',
    );
    if (result == null || !mounted) return;

    // Count current exercises for this day to set sortOrder.
    final existingAsync = ref.read(
      planExercisesProvider((planId: widget.planId, dayOfWeek: dayOfWeek)),
    );
    final existing = existingAsync.valueOrNull ?? [];
    final sortOrder = existing.length;

    final repo = ref.read(workoutRepositoryProvider);
    try {
      await repo.addPlanExercise(
        planId: widget.planId,
        exerciseId: result.id,
        dayOfWeek: dayOfWeek,
        sortOrder: sortOrder,
      );
      ref.invalidate(
        planExercisesProvider((planId: widget.planId, dayOfWeek: dayOfWeek)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding exercise: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_planName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete plan',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Description + active badge row
          if (_planDescription != null && _planDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _planDescription!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),

          if (_isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'This is your active plan',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (_profileId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _setActive,
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Set as Active Plan'),
                ),
              ),
            ),

          // Day-by-day cards
          ..._days.map((day) => _DayCard(
                day: day,
                planId: widget.planId,
                isExpanded: _expandedDays.contains(day.dow),
                onToggle: () => setState(() {
                  if (_expandedDays.contains(day.dow)) {
                    _expandedDays.remove(day.dow);
                  } else {
                    _expandedDays.add(day.dow);
                  }
                }),
                onAddExercise: () => _showAddExerciseSheet(day.dow),
                onRemoveExercise: (id) async {
                  final repo = ref.read(workoutRepositoryProvider);
                  try {
                    await repo.removePlanExercise(id);
                    ref.invalidate(
                      planExercisesProvider(
                          (planId: widget.planId, dayOfWeek: day.dow)),
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              )),
        ],
      ),
    );
  }
}

// ── Day Card ─────────────────────────────────────────────────────────────────

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.day,
    required this.planId,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddExercise,
    required this.onRemoveExercise,
  });

  final _DayMeta day;
  final String planId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddExercise;
  final ValueChanged<String> onRemoveExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(
      planExercisesProvider((planId: planId, dayOfWeek: day.dow)),
    );

    final isToday = DateTime.now().weekday == day.dow;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              )
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (isToday)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      day.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w600,
                            color: isToday
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                    ),
                  ),
                  exercisesAsync.when(
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const Icon(Icons.error_outline, size: 18),
                    data: (exercises) => Text(
                      exercises.isEmpty
                          ? 'Rest'
                          : '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: exercises.isEmpty
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded body
          if (isExpanded)
            exercisesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load: $err',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              data: (exercises) => Column(
                children: [
                  if (exercises.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'No exercises assigned — tap Add to build this day.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    ...exercises.map(
                      (pe) => _ExerciseRow(
                        planExercise: pe,
                        onRemove: () => onRemoveExercise(pe.id),
                      ),
                    ),
                  const Divider(height: 1),
                  TextButton.icon(
                    onPressed: onAddExercise,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Exercise'),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Exercise row within a day card ────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.planExercise,
    required this.onRemove,
  });
  final WorkoutPlanExerciseEntity planExercise;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = planExercise.exercise?.name ?? 'Exercise';
    final muscles =
        planExercise.exercise?.muscleGroups.take(2).toList() ?? [];

    return Dismissible(
      key: ValueKey(planExercise.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onRemove(),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          Icons.drag_indicator,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        title: Text(name),
        subtitle: Row(
          children: [
            Text(
              '${planExercise.targetSets} sets × ${planExercise.targetReps} reps',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (muscles.isNotEmpty) ...[
              const SizedBox(width: 8),
              ...muscles.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    label: Text(
                      _toSentenceCase(m),
                      style: const TextStyle(fontSize: 10),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: planExercise.targetWeightKg != null
            ? Text(
                '${planExercise.targetWeightKg!.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              )
            : null,
      ),
    );
  }

  String _toSentenceCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Internal data class ───────────────────────────────────────────────────────

class _DayMeta {
  const _DayMeta({required this.dow, required this.label});
  final int dow;
  final String label;
}
