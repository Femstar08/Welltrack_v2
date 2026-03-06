import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/daily_prescription_entity.dart';
import '../scenario_nudge_provider.dart';

/// A dismissable card that surfaces scenario-specific nudges.
///
/// Shown for tired, behind-on-steps, and weight-stalling scenarios.
/// Once dismissed, the card does not reappear the same day.
class ScenarioNudgeCard extends ConsumerWidget {
  const ScenarioNudgeCard({
    super.key,
    required this.scenario,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final PrescriptionScenario scenario;
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissals = ref.watch(scenarioNudgeDismissalProvider);
    if (dismissals.contains(scenario.name)) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onPressed: () {
                ref
                    .read(scenarioNudgeDismissalProvider.notifier)
                    .dismiss(scenario);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  /// Factory for tired scenario card.
  static ScenarioNudgeCard tired() {
    return const ScenarioNudgeCard(
      scenario: PrescriptionScenario.tiredNotSore,
      title: 'Tired Day',
      message:
          'Workout volume reduced by 20%. Consider adding extra carbs at breakfast for sustained energy.',
      icon: Icons.bedtime_outlined,
      color: Colors.amber,
    );
  }

  /// Factory for behind-on-steps scenario card.
  static ScenarioNudgeCard behindOnSteps({String? nudgeText}) {
    return ScenarioNudgeCard(
      scenario: PrescriptionScenario.behindSteps,
      title: 'Behind on Steps',
      message: nudgeText ?? 'A 30-min walk puts you on track.',
      icon: Icons.directions_walk,
      color: Colors.teal,
    );
  }

  /// Factory for weight stalling scenario card.
  static ScenarioNudgeCard weightStalling() {
    return const ScenarioNudgeCard(
      scenario: PrescriptionScenario.weightStalling,
      title: 'Weight Plateau',
      message:
          'Consider reducing rest-day calories by 100\u2013200kcal.',
      icon: Icons.trending_flat,
      color: Colors.deepOrange,
    );
  }
}
