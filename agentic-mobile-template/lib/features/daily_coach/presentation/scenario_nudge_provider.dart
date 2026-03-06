import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/daily_prescription_entity.dart';

/// Tracks which scenario nudge cards have been dismissed today.
///
/// Stores dismissals in a Hive box keyed by "YYYY-MM-DD:scenarioName".
/// Cards dismissed today won't reappear until tomorrow.
class ScenarioNudgeDismissalNotifier extends StateNotifier<Set<String>> {
  ScenarioNudgeDismissalNotifier() : super({}) {
    _loadDismissals();
  }

  static const _boxName = 'scenario_nudge_dismissals';

  Future<void> _loadDismissals() async {
    final box = await Hive.openBox<bool>(_boxName);
    final today = _todayKey();
    final dismissed = <String>{};
    for (final key in box.keys) {
      final k = key as String;
      if (k.startsWith(today)) {
        dismissed.add(k.substring(today.length + 1)); // after "YYYY-MM-DD:"
      }
    }
    if (mounted) state = dismissed;
  }

  Future<void> dismiss(PrescriptionScenario scenario) async {
    final box = await Hive.openBox<bool>(_boxName);
    final key = '${_todayKey()}:${scenario.name}';
    await box.put(key, true);
    if (mounted) state = {...state, scenario.name};
  }

  bool isDismissed(PrescriptionScenario scenario) {
    return state.contains(scenario.name);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final scenarioNudgeDismissalProvider =
    StateNotifierProvider<ScenarioNudgeDismissalNotifier, Set<String>>(
  (ref) => ScenarioNudgeDismissalNotifier(),
);
