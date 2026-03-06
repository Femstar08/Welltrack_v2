import 'package:flutter/material.dart';

import '../../../daily_coach/domain/daily_prescription_entity.dart';

class TodaysFocusTip extends StatelessWidget {
  const TodaysFocusTip({
    super.key,
    this.tip,
    required this.scenario,
    this.isFallback = false,
  });

  final String? tip;
  final PrescriptionScenario scenario;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTip = tip ?? _fallbackTip(scenario);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Focus Tip',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!isFallback && tip != null) _AiBadge(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              displayTip,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _fallbackTip(PrescriptionScenario scenario) {
    switch (scenario) {
      case PrescriptionScenario.wellRested:
        return 'Your body is primed today. Make the most of your energy by attacking your biggest challenge first.';
      case PrescriptionScenario.tiredNotSore:
        return 'Consistency over intensity. Showing up even on tired days is what separates great athletes from good ones.';
      case PrescriptionScenario.sore:
        return 'Feeling sore is part of progress. Reduce volume today and focus on form over weight.';
      case PrescriptionScenario.verySore:
        return 'Recovery is training. Prioritise protein, hydration, and sleep to come back stronger tomorrow.';
      case PrescriptionScenario.behindSteps:
        return 'A short 20-minute walk after dinner can add 2,000+ steps and improve your sleep quality.';
      case PrescriptionScenario.weightStalling:
        return 'Plateaus are normal. Small adjustments in calories or adding one cardio session can restart progress.';
      case PrescriptionScenario.busyDay:
        return 'A focused 30-minute session beats no session. Quality over quantity on busy days.';
      case PrescriptionScenario.unwell:
        return 'Rest is the best medicine. Stay hydrated and let your body focus its energy on recovery.';
      case PrescriptionScenario.defaultPlan:
        return 'Every rep, every step, every meal — it all compounds into the person you\'re becoming.';
    }
  }
}

class _AiBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 10,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            'AI',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
