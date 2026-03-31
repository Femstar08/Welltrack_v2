import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../habits/presentation/habit_provider.dart';
import '../../meals/presentation/meal_plan_provider.dart';
import '../../supplements/presentation/supplement_provider.dart';
import 'daily_view_provider.dart';

/// Plan tab — today's actionable daily plan: check-in, meals, workout,
/// supplements, habits.
class DailyViewScreen extends ConsumerStatefulWidget {
  const DailyViewScreen({required this.profileId, super.key});
  final String profileId;

  @override
  ConsumerState<DailyViewScreen> createState() => _DailyViewScreenState();
}

class _DailyViewScreenState extends ConsumerState<DailyViewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      unawaited(ref
          .read(dailyViewProvider(widget.profileId).notifier)
          .loadDailyData());
      unawaited(ref
          .read(mealPlanProvider(widget.profileId).notifier)
          .loadPlan(DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dvState = ref.watch(dailyViewProvider(widget.profileId));
    final mealState = ref.watch(mealPlanProvider(widget.profileId));
    final habitsState = ref.watch(habitProvider(widget.profileId));
    final suppState = ref.watch(supplementProvider(widget.profileId));
    final theme = Theme.of(context);

    return Scaffold(
      body: dvState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(dailyViewProvider(widget.profileId).notifier)
                    .loadDailyData();
                await ref
                    .read(mealPlanProvider(widget.profileId).notifier)
                    .loadPlan(DateTime.now());
              },
              child: CustomScrollView(
                slivers: [
                  // Header with date
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 20, right: 20,
                        top: MediaQuery.paddingOf(context).top + 16,
                        bottom: 8,
                      ),
                      child: _DateHeader(
                        date: dvState.selectedDate,
                        onPrevious: () => ref
                            .read(dailyViewProvider(widget.profileId).notifier)
                            .goToPreviousDay(),
                        onNext: () => ref
                            .read(dailyViewProvider(widget.profileId).notifier)
                            .goToNextDay(),
                      ),
                    ),
                  ),

                  // Morning Check-in
                  SliverToBoxAdapter(
                    child: _CheckInCard(
                      isDone: dvState.recoveryScore != null,
                    ),
                  ),

                  // Meal Plan
                  SliverToBoxAdapter(
                    child: _MealPlanCard(
                      plan: mealState.plan,
                      isGenerating: mealState.isGenerating,
                      profileId: widget.profileId,
                    ),
                  ),

                  // Workout
                  SliverToBoxAdapter(
                    child: _WorkoutCard(
                      workoutsSummary: dvState.workoutsSummary,
                    ),
                  ),

                  // Supplements
                  SliverToBoxAdapter(
                    child: _SupplementsCard(
                      supplements: suppState.supplements,
                      todayLogsByProtocol: suppState.todayLogsByProtocol,
                    ),
                  ),

                  // Habits
                  SliverToBoxAdapter(
                    child: _HabitsCard(
                      habits: habitsState.habits,
                      todayLogs: habitsState.todayLogs,
                      onToggle: (type) => ref
                          .read(habitProvider(widget.profileId).notifier)
                          .toggleHabitToday(type),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

// ── Date Header ─────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date, required this.onPrevious, required this.onNext,
  });
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final label = d == today
        ? "Today's Plan"
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : d == today.add(const Duration(days: 1))
                ? 'Tomorrow'
                : '${_month(date.month)} ${date.day}';
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious, tooltip: 'Previous day'),
        Column(children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
          Text('${days[date.weekday - 1]}, ${_month(date.month)} ${date.day}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
        ]),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext, tooltip: 'Next day'),
      ],
    );
  }

  String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

// ── Check-in Card ───────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.isDone});
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/daily-coach/checkin'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: isDone ? const Color(0xFF4CAF50) : AppColors.primary, width: 3)),
            ),
            child: Row(children: [
              Text(isDone ? '✅' : '☀️', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Morning Check-in', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(isDone ? 'Completed' : 'Tap to start', style: theme.textTheme.bodySmall?.copyWith(color: isDone ? const Color(0xFF4CAF50) : AppColors.primary)),
              ])),
              if (!isDone) Icon(Icons.chevron_right, color: AppColors.primary),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Meal Plan Card ──────────────────────────────────────────────

class _MealPlanCard extends ConsumerWidget {
  const _MealPlanCard({required this.plan, required this.isGenerating, required this.profileId});
  final dynamic plan; // MealPlanEntity?
  final bool isGenerating;
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = plan?.items as List? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('MEAL PLAN', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/meals/plan'),
              child: Text('View all', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 12),
          if (isGenerating)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Column(children: [
              Text('No meal plan for today', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryDark)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.push('/meals/plan'), child: const Text('Generate plan')),
            ])
          else
            ...items.take(4).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 70, child: Text(
                  (item.mealType as String? ?? '').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                )),
                Expanded(child: Text(item.name as String? ?? '', style: theme.textTheme.bodyMedium)),
                Text('${item.calories ?? 0} kcal', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark)),
              ]),
            )),
        ]),
      ),
    );
  }
}

// ── Workout Card ────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({this.workoutsSummary});
  final WorkoutsSummary? workoutsSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduled = workoutsSummary?.scheduledCount ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WORKOUT', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          if (scheduled > 0 && workoutsSummary!.scheduledWorkouts.isNotEmpty)
            ...workoutsSummary!.scheduledWorkouts.take(1).map((w) => Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(w.workoutType, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark)),
              ])),
              if (!w.completed)
                TextButton(onPressed: () => context.push('/workouts/log/${w.id}'), child: const Text('Start')),
            ]))
          else
            Row(children: [
              Icon(Icons.fitness_center, color: AppColors.textSecondaryDark, size: 20),
              const SizedBox(width: 12),
              Text('No workout scheduled', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryDark)),
              const Spacer(),
              TextButton(onPressed: () => context.push('/workouts'), child: const Text('Plan')),
            ]),
        ]),
      ),
    );
  }
}

// ── Supplements Card ────────────────────────────────────────────

class _SupplementsCard extends StatelessWidget {
  const _SupplementsCard({required this.supplements, required this.todayLogsByProtocol});
  final List<dynamic> supplements;
  final Map<String, dynamic> todayLogsByProtocol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (supplements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('SUPPLEMENTS', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            GestureDetector(onTap: () => context.push('/supplements'), child: Text('View all', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary))),
          ]),
          const SizedBox(height: 12),
          ...supplements.take(5).map((s) {
            final name = (s.name as String?) ?? '';
            final log = todayLogsByProtocol[s.id as String? ?? ''];
            final taken = log != null && (log.isTaken as bool? ?? false);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(taken ? Icons.check_circle_rounded : Icons.circle_outlined, size: 20, color: taken ? const Color(0xFF4CAF50) : AppColors.textSecondaryDark),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: taken ? TextDecoration.lineThrough : null,
                  color: taken ? AppColors.textSecondaryDark : null,
                ))),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

// ── Habits Card ─────────────────────────────────────────────────

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.habits, required this.todayLogs, required this.onToggle});
  final List<dynamic> habits;
  final Map<String, bool> todayLogs;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (habits.isEmpty) return const SizedBox.shrink();

    final completedCount = todayLogs.values.where((v) => v).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('HABITS', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            Text('$completedCount/${habits.length}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark)),
          ]),
          const SizedBox(height: 12),
          ...habits.map((habit) {
            final type = habit.habitType as String;
            final label = (habit.habitLabel as String?) ?? type.replaceAll('_', ' ');
            final done = todayLogs[type] == true;
            final streak = (habit.currentStreakDays as int?) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onToggle(type),
                child: Row(children: [
                  Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined, size: 20, color: done ? AppColors.primary : AppColors.textSecondaryDark),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? AppColors.textSecondaryDark : null,
                  ))),
                  if (streak > 0) Text('🔥 $streak', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFFF9800))),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }
}
