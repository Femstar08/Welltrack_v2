// lib/features/habits/domain/kegel_protocol.dart
//
// Domain model for the Kegel guided-timer feature (US-003).
//
// A [KegelProtocol] is a pure data class — no DB involvement. All three
// pre-loaded protocols are exposed via [KegelProtocol.presets].

/// Describes a single kegel training protocol.
class KegelProtocol {
  const KegelProtocol({
    required this.id,
    required this.name,
    required this.description,
    required this.sets,
    required this.repsPerSet,
    required this.squeezeSeconds,
    required this.relaxSeconds,
    required this.restBetweenSetsSeconds,
  });

  /// Stable identifier — used by the timer provider to key state.
  final String id;

  /// Short display name shown on the protocol selection card.
  final String name;

  /// One-line description of the protocol.
  final String description;

  /// How many sets in one session.
  final int sets;

  /// Reps per set.
  final int repsPerSet;

  /// Duration of the squeeze (contraction) phase in seconds.
  final int squeezeSeconds;

  /// Duration of the relax phase in seconds.
  final int relaxSeconds;

  /// Rest duration between sets in seconds.
  final int restBetweenSetsSeconds;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// Estimated total session duration in seconds (including rest between sets).
  int get estimatedTotalSeconds {
    final repDuration = (squeezeSeconds + relaxSeconds) * repsPerSet;
    final setDuration = repDuration;
    final totalWork = setDuration * sets;
    // (sets - 1) rest gaps between sets.
    final totalRest = restBetweenSetsSeconds * (sets - 1);
    return totalWork + totalRest;
  }

  /// Estimated duration formatted as "X min" or "X min Y sec".
  String get estimatedDurationLabel {
    final secs = estimatedTotalSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '$m min';
    return '$m min ${s}s';
  }

  // ---------------------------------------------------------------------------
  // Pre-loaded protocols
  // ---------------------------------------------------------------------------

  /// The three pre-loaded Kegel protocols presented in the selection screen.
  static const List<KegelProtocol> presets = [
    KegelProtocol(
      id: 'quick_flicks',
      name: 'Quick Flicks',
      description: 'Fast contractions to build endurance and muscle activation.',
      sets: 3,
      repsPerSet: 10,
      squeezeSeconds: 1,
      relaxSeconds: 1,
      restBetweenSetsSeconds: 10,
    ),
    KegelProtocol(
      id: 'long_holds',
      name: 'Long Holds',
      description: 'Sustained contractions to develop strength and control.',
      sets: 3,
      repsPerSet: 5,
      squeezeSeconds: 5,
      relaxSeconds: 5,
      restBetweenSetsSeconds: 15,
    ),
    KegelProtocol(
      id: 'reverse_kegels',
      name: 'Reverse Kegels',
      description: 'Controlled push-out phase for flexibility and relaxation.',
      sets: 3,
      repsPerSet: 5,
      squeezeSeconds: 5,
      relaxSeconds: 5,
      restBetweenSetsSeconds: 15,
    ),
  ];
}
