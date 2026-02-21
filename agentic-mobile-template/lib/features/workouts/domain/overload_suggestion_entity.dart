// lib/features/workouts/domain/overload_suggestion_entity.dart

/// A deterministic suggestion generated when a user has plateaued on an
/// exercise — same weight x reps for 3+ consecutive sessions.
class OverloadSuggestion {
  const OverloadSuggestion({
    required this.exerciseId,
    required this.exerciseName,
    required this.currentWeightKg,
    required this.currentReps,
    required this.sessionCount,
    required this.suggestedWeightKg,
    required this.suggestedReps,
  });

  final String exerciseId;
  final String exerciseName;

  /// The weight the user has been stuck at.
  final double currentWeightKg;

  /// The reps the user has been stuck at.
  final int currentReps;

  /// Number of consecutive sessions at this plateau.
  final int sessionCount;

  /// Suggested new weight (~7.5% increase, rounded to nearest 2.5 kg).
  final double suggestedWeightKg;

  /// Suggested new reps (typically currentReps - 2, minimum 1).
  final int suggestedReps;

  String get summary =>
      '${currentWeightKg.toStringAsFixed(1)} kg x $currentReps '
      'for $sessionCount sessions';

  String get suggestion =>
      'Try ${suggestedWeightKg.toStringAsFixed(1)} kg x $suggestedReps';
}
