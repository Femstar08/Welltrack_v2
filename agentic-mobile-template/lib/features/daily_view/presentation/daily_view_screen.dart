// lib/features/daily_view/presentation/daily_view_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      unawaited(ref.read(dailyViewProvider(widget.profileId).notifier).loadDailyData());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyViewProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              ref.read(dailyViewProvider(widget.profileId).notifier).goToToday();
            },
            tooltip: 'Go to today',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(dailyViewProvider(widget.profileId).notifier)
                  .loadDailyData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildDateSelector(context, state),
                    _buildRecoveryScoreCard(context, state),
                    _buildProgressRing(context, state),
                    if (state.mealsSummary != null)
                      _buildMealsSection(context, state.mealsSummary!),
                    if (state.supplementsSummary != null)
                      _buildSupplementsSection(context, state.supplementsSummary!),
                    if (state.workoutsSummary != null)
                      _buildWorkoutsSection(context, state.workoutsSummary!),
                    if (state.healthMetrics != null)
                      _buildHealthMetricsSection(context, state.healthMetrics!),
                    const SizedBox(height: 80), // Bottom padding for FAB
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateSelector(BuildContext context, DailyViewState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                ref.read(dailyViewProvider(widget.profileId).notifier).goToPreviousDay();
              },
            ),
            GestureDetector(
              onTap: () => _showDatePicker(context, state),
              child: Column(
                children: [
                  Text(
                    _formatDate(state.selectedDate),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    _formatDayOfWeek(state.selectedDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                ref.read(dailyViewProvider(widget.profileId).notifier).goToNextDay();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryScoreCard(BuildContext context, DailyViewState state) {
    final recovery = state.recoveryScore;
    if (recovery == null) return const SizedBox.shrink();

    Color scoreColor;
    if (recovery.score == null) {
      scoreColor = Colors.grey;
    } else if (recovery.score! >= 80) {
      scoreColor = Colors.green;
    } else if (recovery.score! >= 60) {
      scoreColor = Colors.blue;
    } else if (recovery.score! >= 40) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scoreColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              recovery.isCalibrating ? Icons.sync : Icons.favorite,
              size: 40,
              color: scoreColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recovery.isCalibrating ? 'Recovery' : recovery.statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                  ),
                  Text(
                    recovery.displayMessage,
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

  Widget _buildProgressRing(BuildContext context, DailyViewState state) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: state.overallCompletionPercentage / 100,
                      strokeWidth: 12,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${state.overallCompletionPercentage.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Complete',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${state.completedTasks} of ${state.totalTasks} tasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsSection(BuildContext context, MealsSummary summary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.restaurant),
        title: const Text('Meals'),
        subtitle: Text(
          '${summary.loggedCount} of ${summary.plannedCount} logged',
        ),
        trailing: _buildCompletionIndicator(
          context,
          summary.completionPercentage,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...summary.plannedMeals.map((meal) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle_outlined, size: 16),
                      title: Text(meal),
                      trailing: const Text('Planned'),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToMeals(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Log Meal'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplementsSection(BuildContext context, SupplementsSummary summary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.medication),
        title: const Text('Supplements'),
        subtitle: Text(
          '${summary.taken} taken, ${summary.pending} pending',
        ),
        trailing: _buildCompletionIndicator(
          context,
          summary.completionPercentage,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.pendingSupplements.isNotEmpty) ...[
                  Text(
                    'Pending',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...summary.pendingSupplements.map((supplement) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.radio_button_unchecked, size: 16),
                        title: Text(supplement),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                // TODO: Mark as taken
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.orange),
                              onPressed: () {
                                // TODO: Mark as skipped
                              },
                            ),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToSupplements(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View All Supplements'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsSection(BuildContext context, WorkoutsSummary summary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.fitness_center),
        title: const Text('Workouts'),
        subtitle: Text(
          '${summary.completedCount} of ${summary.scheduledCount} completed',
        ),
        trailing: _buildCompletionIndicator(
          context,
          summary.completionPercentage,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...summary.scheduledWorkouts.map((workout) => ListTile(
                      dense: true,
                      leading: Icon(
                        workout.completed ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: workout.completed ? Colors.green : null,
                      ),
                      title: Text(workout.name),
                      subtitle: Text(workout.workoutType),
                      trailing: workout.completed
                          ? null
                          : TextButton(
                              onPressed: () => _navigateToWorkout(context, workout.id),
                              child: const Text('Start'),
                            ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToWorkouts(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View All Workouts'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricsSection(BuildContext context, HealthMetricsSummary metrics) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety),
                const SizedBox(width: 8),
                Text(
                  'Health Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Sleep',
                    metrics.sleepDisplay,
                    Icons.bedtime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Steps',
                    metrics.stepsDisplay,
                    Icons.directions_walk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Heart Rate',
                    metrics.heartRate != null
                        ? '${metrics.heartRate!.toStringAsFixed(0)} bpm'
                        : 'No data',
                    Icons.favorite,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    'Stress',
                    metrics.stressScore != null
                        ? '${metrics.stressScore!.toStringAsFixed(0)}/100'
                        : 'No data',
                    Icons.psychology,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionIndicator(BuildContext context, double percentage) {
    Color color;
    if (percentage >= 100) {
      color = Colors.green;
    } else if (percentage >= 50) {
      color = Colors.blue;
    } else if (percentage > 0) {
      color = Colors.orange;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _formatDayOfWeek(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  void _showDatePicker(BuildContext context, DailyViewState state) async {
    final date = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null) {
      ref.read(dailyViewProvider(widget.profileId).notifier).changeDate(date);
    }
  }

  void _navigateToMeals(BuildContext context) {
    // TODO: Navigate to meals screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to meals - TODO')),
    );
  }

  void _navigateToSupplements(BuildContext context) {
    // TODO: Navigate to supplements screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to supplements - TODO')),
    );
  }

  void _navigateToWorkouts(BuildContext context) {
    // TODO: Navigate to workouts screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to workouts - TODO')),
    );
  }

  void _navigateToWorkout(BuildContext context, String workoutId) {
    // TODO: Navigate to specific workout
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to workout $workoutId - TODO')),
    );
  }
}
