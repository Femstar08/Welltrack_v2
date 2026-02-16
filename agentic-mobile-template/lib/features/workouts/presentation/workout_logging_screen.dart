// lib/features/workouts/presentation/workout_logging_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/workouts/presentation/workout_provider.dart';

class WorkoutLoggingScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String workoutId;

  const WorkoutLoggingScreen({
    required this.profileId,
    required this.workoutId,
    super.key,
  });

  @override
  ConsumerState<WorkoutLoggingScreen> createState() =>
      _WorkoutLoggingScreenState();
}

class _WorkoutLoggingScreenState extends ConsumerState<WorkoutLoggingScreen> {
  DateTime? _startTime;
  final _exerciseSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    Future.microtask(() {
      ref
          .read(workoutDetailProvider((
            profileId: widget.profileId,
            workoutId: widget.workoutId,
          )).notifier)
          .loadWorkoutDetail();
    });
  }

  @override
  void dispose() {
    _exerciseSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutDetailProvider((
      profileId: widget.profileId,
      workoutId: widget.workoutId,
    )));

    return WillPopScope(
      onWillPop: () async {
        if (state.logs.isNotEmpty) {
          return await _showExitConfirmation(context);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.workout?.name ?? 'Workout'),
          actions: [
            if (_startTime != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _formatElapsedTime(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildWorkoutHeader(context, state),
                  Expanded(
                    child: state.logs.isEmpty
                        ? _buildEmptyState(context)
                        : _buildExerciseList(context, state),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddExerciseDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.logs.isEmpty
                        ? null
                        : () => _completeWorkout(context, state),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete Workout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutHeader(BuildContext context, WorkoutDetailState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.workout?.workoutType ?? 'Workout',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${state.totalExercises} exercises logged',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises logged yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('Tap "Add Exercise" to get started'),
        ],
      ),
    );
  }

  Widget _buildExerciseList(BuildContext context, WorkoutDetailState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final log = state.logs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(log.exerciseName),
            subtitle: Text(log.displaySummary),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDeleteLog(context, log.id);
                } else if (value == 'edit') {
                  _showEditExerciseDialog(context, log);
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _formatElapsedTime() {
    if (_startTime == null) return '00:00';
    final elapsed = DateTime.now().difference(_startTime!);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showAddExerciseDialog(BuildContext context) {
    final exerciseNameController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final weightController = TextEditingController();
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: exerciseNameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  hintText: 'e.g., Bench Press',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsController,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: repsController,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (seconds)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (exerciseNameController.text.isNotEmpty) {
                ref
                    .read(workoutDetailProvider((
                      profileId: widget.profileId,
                      workoutId: widget.workoutId,
                    )).notifier)
                    .addExerciseLog(
                      exerciseName: exerciseNameController.text,
                      sets: setsController.text.isNotEmpty
                          ? int.tryParse(setsController.text)
                          : null,
                      reps: repsController.text.isNotEmpty
                          ? int.tryParse(repsController.text)
                          : null,
                      weightKg: weightController.text.isNotEmpty
                          ? double.tryParse(weightController.text)
                          : null,
                      durationSeconds: durationController.text.isNotEmpty
                          ? int.tryParse(durationController.text)
                          : null,
                    );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditExerciseDialog(BuildContext context, log) {
    // TODO: Implement edit exercise dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit exercise - TODO')),
    );
  }

  void _confirmDeleteLog(BuildContext context, String logId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: const Text('Are you sure you want to delete this exercise log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(workoutDetailProvider((
                    profileId: widget.profileId,
                    workoutId: widget.workoutId,
                  )).notifier)
                  .deleteLog(logId);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _completeWorkout(BuildContext context, WorkoutDetailState state) {
    if (_startTime == null) return;

    final duration = DateTime.now().difference(_startTime!);
    final durationMinutes = duration.inMinutes;

    ref.read(workoutProvider(widget.profileId).notifier).completeWorkout(
          widget.workoutId,
          durationMinutes: durationMinutes,
        );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Workout Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.celebration,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Duration: $durationMinutes minutes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Exercises: ${state.totalExercises}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close workout screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Workout?'),
        content: const Text(
          'You have logged exercises. Are you sure you want to exit without completing the workout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
