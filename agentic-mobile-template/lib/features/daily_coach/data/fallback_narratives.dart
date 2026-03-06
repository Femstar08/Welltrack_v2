// lib/features/daily_coach/data/fallback_narratives.dart

import '../domain/daily_prescription_entity.dart';

/// Pre-written narrative content shown when the AI orchestrator is unavailable.
///
/// Language is suggestive, not prescriptive ("Consider" not "Do this").
/// No medical claims. All content is general wellness guidance only.
class FallbackNarrative {
  const FallbackNarrative({
    required this.focusTip,
    required this.narrative,
  });

  final String focusTip;
  final String narrative;

  static const Map<PrescriptionScenario, FallbackNarrative> _narratives = {
    PrescriptionScenario.wellRested: FallbackNarrative(
      focusTip:
          'Great energy today — consider pushing for a personal record on your main lift.',
      narrative:
          "You're well rested and feeling strong. Your body is primed for a full session.",
    ),
    PrescriptionScenario.tiredNotSore: FallbackNarrative(
      focusTip:
          'Prioritise good form over heavy weight today. Quality reps build long-term strength.',
      narrative:
          "Not your best sleep, but you can still get a solid session in. Reduced volume will keep you moving forward.",
    ),
    PrescriptionScenario.verySore: FallbackNarrative(
      focusTip:
          'Light movement helps recovery more than complete rest. A walk or gentle stretch session works well.',
      narrative:
          'Your body needs time to recover. Active recovery today sets you up for a stronger session tomorrow.',
    ),
    PrescriptionScenario.behindSteps: FallbackNarrative(
      focusTip:
          'A 20-minute walk after your next meal is an easy way to close the gap.',
      narrative:
          "You're behind on steps today. A short walk can help hit your target and improve digestion.",
    ),
    PrescriptionScenario.weightStalling: FallbackNarrative(
      focusTip:
          'Consider tracking portions more carefully this week — small calorie adjustments can restart progress.',
      narrative:
          'Weight has been stable for a while. Small adjustments to rest-day calories may help restart progress.',
    ),
    PrescriptionScenario.busyDay: FallbackNarrative(
      focusTip: 'A focused 30-minute session is better than skipping entirely.',
      narrative:
          'Busy day ahead. A shorter workout keeps consistency without adding stress to your schedule.',
    ),
    PrescriptionScenario.unwell: FallbackNarrative(
      focusTip: 'Rest is the most productive thing you can do today.',
      narrative:
          'Take it easy today. Hydration and rest will help you bounce back faster.',
    ),
    PrescriptionScenario.defaultPlan: FallbackNarrative(
      focusTip:
          'Stay consistent — small daily actions compound into big results.',
      narrative:
          'Standard day ahead. Stick to your plan and trust the process.',
    ),
  };

  /// Returns the fallback narrative for the given [scenario].
  /// Falls back to [PrescriptionScenario.defaultPlan] if not mapped.
  static FallbackNarrative forScenario(PrescriptionScenario scenario) {
    return _narratives[scenario] ??
        _narratives[PrescriptionScenario.defaultPlan]!;
  }
}
