// lib/features/dashboard/presentation/widgets/daily_coach_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../daily_coach/data/checkin_repository.dart';
import '../../../daily_coach/data/daily_prescription_repository.dart';
import '../../../daily_coach/domain/checkin_entity.dart';
import '../../../daily_coach/domain/daily_prescription_entity.dart';

// ---------------------------------------------------------------------------
// Status model
// ---------------------------------------------------------------------------

class _DailyCoachStatus {
  const _DailyCoachStatus({this.checkIn, this.prescription});
  final CheckInEntity? checkIn;
  final DailyPrescriptionEntity? prescription;

  bool get hasCheckIn => checkIn != null;
  bool get hasPrescription => prescription != null;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _dailyCoachStatusProvider =
    FutureProvider.family<_DailyCoachStatus, String>((ref, profileId) async {
  final checkinRepo = ref.watch(checkinRepositoryProvider);
  final prescriptionRepo = ref.watch(dailyPrescriptionRepositoryProvider);

  final results = await Future.wait([
    checkinRepo.getTodayCheckIn(profileId),
    prescriptionRepo.getTodayPrescription(profileId),
  ]);

  return _DailyCoachStatus(
    checkIn: results[0] as CheckInEntity?,
    prescription: results[1] as DailyPrescriptionEntity?,
  );
});

// ---------------------------------------------------------------------------
// Helpers — scenario display
// ---------------------------------------------------------------------------

(IconData, String, Color) _scenarioDisplay(PrescriptionScenario scenario) {
  return switch (scenario) {
    PrescriptionScenario.wellRested =>
      (Icons.wb_sunny, 'Well Rested', Colors.green),
    PrescriptionScenario.tiredNotSore =>
      (Icons.bedtime, 'Take It Easy', Colors.amber),
    PrescriptionScenario.sore =>
      (Icons.fitness_center, 'Light Day', Colors.amber),
    PrescriptionScenario.verySore =>
      (Icons.healing, 'Recovery Day', Colors.orange),
    PrescriptionScenario.busyDay =>
      (Icons.speed, 'Express Mode', Colors.blue),
    PrescriptionScenario.behindSteps =>
      (Icons.directions_walk, 'Move More', Colors.teal),
    PrescriptionScenario.weightStalling =>
      (Icons.trending_flat, 'Plateau Alert', Colors.deepOrange),
    PrescriptionScenario.unwell =>
      (Icons.local_hospital, 'Rest & Recover', Colors.red),
    _ => (Icons.today, 'Standard Day', Colors.blueGrey),
  };
}

String _workoutDirectiveLabel(WorkoutDirective directive) {
  return switch (directive) {
    WorkoutDirective.fullSession => 'Full workout session today',
    WorkoutDirective.reducedVolume => 'Reduced volume — 80% of normal sets',
    WorkoutDirective.activeRecovery => 'Active recovery — walk & stretch',
    WorkoutDirective.quickSession => 'Express 30-min compound session',
    WorkoutDirective.rest => 'Rest day — no training',
  };
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class DailyCoachCard extends ConsumerWidget {
  const DailyCoachCard({required this.profileId, super.key});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_dailyCoachStatusProvider(profileId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: statusAsync.when(
        loading: () => _buildShell(
          context,
          child: const SizedBox(
            height: 60,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (status) {
          if (!status.hasCheckIn) {
            return _buildNoCheckIn(context);
          }
          if (!status.hasPrescription) {
            return _buildPlanLoading(context);
          }
          return _buildPlanReady(context, status.prescription!);
        },
      ),
    );
  }

  // ── State 1: No check-in today ──────────────────────────────────────────

  Widget _buildNoCheckIn(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.6),
              colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_twilight, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Daily Coach',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_greeting()}! How are you feeling?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete your morning check-in to get today\'s personalised plan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => context.push('/daily-coach/checkin'),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start Check-In'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State 2: Check-in done, plan loading ───────────────────────────────

  Widget _buildPlanLoading(BuildContext context) {
    final theme = Theme.of(context);

    return _buildShell(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Building your plan...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── State 3: Plan ready ────────────────────────────────────────────────

  Widget _buildPlanReady(
    BuildContext context,
    DailyPrescriptionEntity prescription,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, label, color) = _scenarioDisplay(prescription.scenario);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/daily-coach/plan'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_twilight,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Today\'s Plan',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Scenario badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Workout directive
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _workoutDirectiveLabel(prescription.workoutDirective),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // CTA button
              OutlinedButton(
                onPressed: () => context.push('/daily-coach/plan'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Today\'s Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared shell (used during loading states) ──────────────────────────

  Widget _buildShell(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_twilight,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Coach',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
