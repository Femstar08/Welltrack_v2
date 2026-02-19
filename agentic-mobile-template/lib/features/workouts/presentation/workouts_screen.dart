// lib/features/workouts/presentation/workouts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workout_provider.dart';
import 'workout_logging_screen.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {

  const WorkoutsScreen({
    required this.profileId,
    super.key,
  });
  final String profileId;

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(workoutProvider(widget.profileId).notifier).loadWorkouts();
      ref.read(workoutProvider(widget.profileId).notifier).loadExercises();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Schedule'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(context, state),
                _buildScheduleTab(context, state),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWorkoutDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Workout'),
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, WorkoutState state) {
    if (state.todayWorkouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No workouts scheduled for today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Tap the + button to schedule a workout'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(workoutProvider(widget.profileId).notifier).loadWorkouts(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    value: state.todayCompletionPercentage / 100,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Progress',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${state.completedTodayCount} of ${state.totalTodayCount} workouts complete',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...state.todayWorkouts.map((workout) => _buildWorkoutCard(
                context,
                workout,
                isToday: true,
              )),
        ],
      ),
    );
  }

  Widget _buildScheduleTab(BuildContext context, WorkoutState state) {
    if (state.workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No workouts scheduled',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Tap the + button to create a workout'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(workoutProvider(widget.profileId).notifier).loadWorkouts(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.workouts.length,
        itemBuilder: (context, index) {
          final workout = state.workouts[index];
          return _buildWorkoutCard(context, workout);
        },
      ),
    );
  }

  Widget _buildWorkoutCard(
    BuildContext context,
    workout, {
    bool isToday = false,
  }) {
    final isPastDue = workout.isPastDue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: workout.completed
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: ListTile(
        leading: Icon(
          workout.completed
              ? Icons.check_circle
              : isPastDue
                  ? Icons.warning_amber
                  : Icons.fitness_center,
          color: workout.completed
              ? Colors.green
              : isPastDue
                  ? Colors.orange
                  : null,
        ),
        title: Text(
          workout.name,
          style: TextStyle(
            decoration: workout.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.workoutType),
            Text(
              _formatDate(workout.scheduledDate),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (workout.completed && workout.durationMinutes != null)
              Text(
                '${workout.durationMinutes} minutes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
              ),
          ],
        ),
        trailing: workout.completed
            ? null
            : IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _startWorkout(context, workout.id),
              ),
        onTap: () => _showWorkoutDetails(context, workout.id),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  void _startWorkout(BuildContext context, String workoutId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutLoggingScreen(
          profileId: widget.profileId,
          workoutId: workoutId,
        ),
      ),
    );
  }

  void _showWorkoutDetails(BuildContext context, String workoutId) {
    // TODO: Navigate to workout detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout details - TODO')),
    );
  }

  void _showAddWorkoutDialog(BuildContext context) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Workout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Workout Name',
                  hintText: 'e.g., Morning Run',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Workout Type',
                  hintText: 'e.g., Cardio, Strength',
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Scheduled Date'),
                subtitle: Text(_formatDate(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    selectedDate = date;
                  }
                },
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
              if (nameController.text.isNotEmpty &&
                  typeController.text.isNotEmpty) {
                ref.read(workoutProvider(widget.profileId).notifier).createWorkout(
                      name: nameController.text,
                      workoutType: typeController.text,
                      scheduledDate: selectedDate,
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
}
