import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/daily_prescription_entity.dart';
import 'todays_plan_provider.dart';
import 'widgets/bedtime_reminder_card.dart';
import 'widgets/todays_focus_tip.dart';
import 'widgets/todays_meals_card.dart';
import 'widgets/todays_steps_ring.dart';
import 'widgets/todays_workout_card.dart';

class TodaysPlanScreen extends ConsumerWidget {
  const TodaysPlanScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todaysPlanProvider(profileId));
    final theme = Theme.of(context);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.prescription == null) {
      return _ErrorState(
        error: state.error!,
        onRetry: () =>
            ref.read(todaysPlanProvider(profileId).notifier).refresh(),
      );
    }

    if (state.prescription == null) {
      return _NoPrescriptionState();
    }

    final prescription = state.prescription!;
    final dateLabel = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Plan"),
            Text(
              dateLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(todaysPlanProvider(profileId).notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Fallback indicator
              if (prescription.isFallback) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FallbackChip(),
                ),
                const SizedBox(height: 8),
              ],

              // 1. Workout card
              TodaysWorkoutCard(
                prescription: prescription,
                profileId: profileId,
                activePlanId: state.activePlanId,
                planName: state.todaysWorkoutName,
                exerciseCount: state.todaysExerciseCount,
              ),
              const SizedBox(height: 12),

              // 2. Meals card
              TodaysMealsCard(
                mealDirective: prescription.mealDirective,
                mealPlan: state.mealPlan,
              ),
              const SizedBox(height: 12),

              // 3. Steps ring
              TodaysStepsRing(
                stepsToday: state.stepsToday,
                stepsGoal: state.stepsGoal,
                nudgeText: prescription.stepsNudge,
              ),
              const SizedBox(height: 12),

              // 4. Focus tip
              TodaysFocusTip(
                tip: prescription.aiFocusTip,
                scenario: prescription.scenario,
                isFallback: prescription.isFallback,
              ),
              const SizedBox(height: 12),

              // 5. Bedtime reminder
              BedtimeReminderCard(
                bedtimeHour: prescription.bedtimeHour,
                bedtimeMinute: prescription.bedtimeMinute,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No Prescription State ──────────────────────────────────────────────────

class _NoPrescriptionState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Plan")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 72,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'No plan yet for today',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Complete your morning check-in to get your personalised daily plan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('Start Morning Check-In'),
                onPressed: () => context.push('/daily-coach/checkin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Plan")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 20),
              Text(
                'Could not load your plan',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fallback Chip ──────────────────────────────────────────────────────────

class _FallbackChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Generated without AI',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
