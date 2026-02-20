// lib/features/workouts/presentation/workouts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/workout_entity.dart';
import '../domain/workout_plan_entity.dart';
import '../data/workout_repository.dart';
import 'plan_provider.dart';
import 'workout_provider.dart';

// ── Providers scoped to this screen ────────────────────────────────────────

/// Completed workouts (history) — most recent first, capped at 30.
/// Plans and active plan are provided by plan_provider.dart:
///   workoutPlansProvider(profileId)
///   activePlanProvider(profileId)
///   planExercisesProvider((planId: ..., dayOfWeek: ...))
final _workoutHistoryProvider =
    FutureProvider.family<List<WorkoutEntity>, String>(
  (ref, profileId) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getCompletedWorkouts(profileId, limit: 30);
  },
);

// ── Screen ─────────────────────────────────────────────────────────────────

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({required this.profileId, super.key});
  final String profileId;

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Trigger legacy workout load for any state that still depends on it.
    Future.microtask(() {
      ref.read(workoutProvider(widget.profileId).notifier).loadWorkouts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Plans'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TodayTab(profileId: widget.profileId),
          _PlansTab(profileId: widget.profileId),
          _HistoryTab(profileId: widget.profileId),
        ],
      ),
    );
  }
}

// ── TODAY TAB ──────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  const _TodayTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePlanAsync = ref.watch(activePlanProvider(profileId));

    return activePlanAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(
        message: 'Failed to load today\'s workout.',
        onRetry: () => ref.invalidate(activePlanProvider(profileId)),
      ),
      data: (activePlan) {
        if (activePlan == null) {
          return _TodayEmptyState(
            message: 'No active plan',
            detail: 'Create a workout plan and set it as active to see your daily workout here.',
            actionLabel: 'Create your first workout plan',
            onAction: () {
              // Switch to Plans tab — parent TabController is needed; use a
              // simple ScaffoldMessenger nudge as a fallback.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Switch to the Plans tab to create a plan.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          );
        }
        return _TodayPlanView(
          profileId: profileId,
          plan: activePlan,
        );
      },
    );
  }
}

class _TodayPlanView extends ConsumerWidget {
  const _TodayPlanView({required this.profileId, required this.plan});
  final String profileId;
  final WorkoutPlanEntity plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // dayOfWeek: 1=Mon … 7=Sun (matches WorkoutPlanExerciseEntity.dayOfWeek)
    final todayDow = DateTime.now().weekday;

    final planExercisesAsync = ref.watch(
      planExercisesProvider((planId: plan.id, dayOfWeek: todayDow)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activePlanProvider(profileId));
        ref.invalidate(
          planExercisesProvider((planId: plan.id, dayOfWeek: todayDow)),
        );
      },
      child: planExercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: 'Failed to load exercises.',
          onRetry: () => ref.invalidate(
            planExercisesProvider((planId: plan.id, dayOfWeek: todayDow)),
          ),
        ),
        data: (exercises) {
          if (exercises.isEmpty) {
            return _TodayEmptyState(
              message: 'Rest Day',
              detail: 'No exercises scheduled on ${_dowLabel(todayDow)} in "${plan.name}". Enjoy your recovery.',
              actionLabel: null,
              onAction: null,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Plan badge
              Row(
                children: [
                  const Icon(Icons.event_note, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Chip(
                    label: Text(_dowLabel(todayDow)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Workout card
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Today\'s Workout',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          Text(
                            '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                    ...exercises.take(5).map((pe) {
                      final name = pe.exercise?.name ?? 'Exercise';
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: Text(
                            '${pe.sortOrder + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '${pe.targetSets} sets × ${pe.targetReps} reps',
                        ),
                        trailing: pe.targetWeightKg != null
                            ? Text(
                                '${pe.targetWeightKg!.toStringAsFixed(1)} kg',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              )
                            : null,
                      );
                    }),
                    if (exercises.length > 5)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          '+ ${exercises.length - 5} more exercise${exercises.length - 5 == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            // Navigate to live logging screen.
                            // A workout session will be started there.
                            context.push(
                              '/workouts/log/new',
                              extra: {
                                'planId': plan.id,
                                'planName': plan.name,
                                'dayOfWeek': todayDow,
                              },
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Workout'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dowLabel(int dow) {
    const labels = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return labels[dow] ?? 'Today';
  }
}

class _TodayEmptyState extends StatelessWidget {
  const _TodayEmptyState({
    required this.message,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });
  final String message;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── PLANS TAB ──────────────────────────────────────────────────────────────

class _PlansTab extends ConsumerWidget {
  const _PlansTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(workoutPlansProvider(profileId));

    return Scaffold(
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: 'Failed to load plans.',
          onRetry: () => ref.invalidate(workoutPlansProvider(profileId)),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 80,
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No workout plans yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a plan to organise your weekly training.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(workoutPlansProvider(profileId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return _PlanCard(
                  plan: plan,
                  profileId: profileId,
                  onTap: () =>
                      context.push('/workouts/plan/${plan.id}'),
                  onSetActive: plan.isActive
                      ? null
                      : () async {
                          final repo =
                              ref.read(workoutRepositoryProvider);
                          try {
                            await repo.setActivePlan(profileId, plan.id);
                            ref.invalidate(
                              workoutPlansProvider(profileId),
                            );
                            ref.invalidate(
                              activePlanProvider(profileId),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'plans_fab',
        onPressed: () => _showCreatePlanDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Workout Plan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Plan name',
                  hintText: 'e.g. Push / Pull / Legs',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. 4-day hypertrophy split',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              final repo = ref.read(workoutRepositoryProvider);
              try {
                final plan = await repo.createPlan(
                  profileId: profileId,
                  name: name,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
                ref.invalidate(workoutPlansProvider(profileId));
                if (context.mounted) {
                  context.push('/workouts/plan/${plan.id}');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating plan: $e'),
                      backgroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.profileId,
    required this.onTap,
    required this.onSetActive,
  });
  final WorkoutPlanEntity plan;
  final String profileId;
  final VoidCallback onTap;
  final VoidCallback? onSetActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  if (plan.isActive)
                    Chip(
                      label: const Text('Active'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      avatar: Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                ],
              ),
              if (plan.description != null && plan.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  plan.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (onSetActive != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onSetActive,
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: const Text('Set as Active'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── HISTORY TAB ─────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_workoutHistoryProvider(profileId));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(
        message: 'Failed to load workout history.',
        onRetry: () => ref.invalidate(_workoutHistoryProvider(profileId)),
      ),
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No completed workouts yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completed workouts will appear here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_workoutHistoryProvider(profileId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final workout = history[index];
              return _HistoryCard(workout: workout);
            },
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.workout});
  final WorkoutEntity workout;

  @override
  Widget build(BuildContext context) {
    final completedAt = workout.completedAt;
    final dateLabel = completedAt != null
        ? _formatDate(completedAt)
        : _formatDate(workout.scheduledDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.check,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          workout.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel),
            if (workout.durationMinutes != null)
              Text(
                '${workout.durationMinutes} min',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: workout.durationMinutes != null,
        onTap: () {
          // Placeholder — will navigate to session summary when implemented.
          context.push(
            '/workouts/summary/${workout.id}',
            extra: <String, dynamic>{
              'workoutName': workout.name,
              'durationMinutes': workout.durationMinutes,
              'completedAt': workout.completedAt?.toIso8601String(),
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ── Shared error widget ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
