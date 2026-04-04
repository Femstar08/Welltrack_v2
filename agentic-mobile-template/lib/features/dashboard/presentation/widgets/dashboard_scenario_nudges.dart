import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../daily_coach/data/daily_prescription_repository.dart';
import '../../../daily_coach/domain/daily_prescription_entity.dart';
import '../../../daily_coach/presentation/widgets/scenario_nudge_card.dart';
import '../../../health/data/health_repository.dart';
import '../../../health/domain/health_metric_entity.dart';

/// Shows scenario nudge cards on the dashboard when applicable.
///
/// Reads today's prescription and surfaces dismissable cards for:
/// - Tired (feeling tired or sleep < 6hrs)
/// - Behind on steps (after 3 PM, < 40% of step goal) — also checked dynamically
/// - Weight stalling (no change for 14+ days)
class DashboardScenarioNudges extends ConsumerWidget {
  const DashboardScenarioNudges({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionAsync =
        ref.watch(_dashboardPrescriptionProvider(profileId));
    final stepsAsync = ref.watch(_dashboardStepsProvider(profileId));

    return prescriptionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prescription) {
        final cards = <Widget>[];

        if (prescription?.scenario == PrescriptionScenario.tiredNotSore) {
          cards.add(ScenarioNudgeCard.tired());
        }

        if (prescription?.scenario == PrescriptionScenario.weightStalling) {
          cards.add(ScenarioNudgeCard.weightStalling());
        }

        // Behind on steps: show from prescription scenario OR dynamic check
        if (prescription?.scenario == PrescriptionScenario.behindSteps) {
          cards.add(ScenarioNudgeCard.behindOnSteps(
            nudgeText: prescription?.stepsNudge,
          ));
        } else if (DateTime.now().hour >= 15) {
          // Dynamic check: after 3 PM, check current steps vs goal
          final stepsToday = stepsAsync.valueOrNull;
          const stepsGoal = 10000;
          if (stepsToday != null && stepsToday < (stepsGoal * 0.4)) {
            cards.add(ScenarioNudgeCard.behindOnSteps());
          }
        }

        if (cards.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            for (final card in cards) ...[
              card,
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

final _dashboardPrescriptionProvider =
    FutureProvider.family<DailyPrescriptionEntity?, String>(
        (ref, profileId) async {
  final repo = ref.watch(dailyPrescriptionRepositoryProvider);
  return repo.getTodayPrescription(profileId);
});

final _dashboardStepsProvider =
    FutureProvider.family<int?, String>((ref, profileId) async {
  final healthRepo = ref.watch(healthRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final metrics = await healthRepo.getMetrics(
    profileId,
    MetricType.steps,
    startDate: startOfDay,
    endDate: endOfDay,
  );
  return metrics.isNotEmpty ? metrics.first.valueNum?.toInt() : null;
});
