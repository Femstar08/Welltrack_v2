// lib/features/workouts/data/overload_detection_service.dart

import 'dart:math';
import '../domain/overload_suggestion_entity.dart';
import 'workout_repository.dart';

/// Deterministic plateau detection — no AI involved.
///
/// Analyses the heaviest completed set per session for a given exercise.
/// If the user has done the same weight x reps for [minSessions] or more
/// consecutive sessions, a suggestion to increase weight is returned.
class OverloadDetectionService {
  OverloadDetectionService(this._repository);

  final WorkoutRepository _repository;

  /// Minimum consecutive sessions at the same weight/reps to trigger a
  /// plateau suggestion.
  static const int minSessions = 3;

  /// Weight increase factor (7.5%).
  static const double _increaseFactor = 1.075;

  /// Round to the nearest increment (2.5 kg for barbell work).
  static const double _roundingIncrement = 2.5;

  /// Detect plateau for a single exercise. Returns null if no plateau.
  Future<OverloadSuggestion?> detectPlateau({
    required String profileId,
    required String exerciseId,
    required String exerciseName,
  }) async {
    final bestSets = await _repository.getRecentBestSetsForExercise(
      profileId,
      exerciseId,
      sessionCount: 5,
    );

    if (bestSets.length < minSessions) return null;

    // Check if the most recent [minSessions] sessions all share the same
    // weight and reps on the heaviest set.
    final recent = bestSets.take(minSessions).toList();
    final refWeight = recent.first.weightKg;
    final refReps = recent.first.reps;

    if (refWeight == null || refReps == null) return null;
    if (refWeight <= 0 || refReps <= 0) return null;

    final allSame = recent.every(
      (s) => s.weightKg == refWeight && s.reps == refReps,
    );

    if (!allSame) return null;

    // Count how many consecutive sessions are at this plateau (could be > 3).
    int plateauCount = minSessions;
    for (int i = minSessions; i < bestSets.length; i++) {
      if (bestSets[i].weightKg == refWeight && bestSets[i].reps == refReps) {
        plateauCount++;
      } else {
        break;
      }
    }

    // Calculate suggested progression.
    final rawSuggested = refWeight * _increaseFactor;
    final suggestedWeight =
        (rawSuggested / _roundingIncrement).ceil() * _roundingIncrement;
    final suggestedReps = max(1, refReps - 2);

    return OverloadSuggestion(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      currentWeightKg: refWeight,
      currentReps: refReps,
      sessionCount: plateauCount,
      suggestedWeightKg: suggestedWeight,
      suggestedReps: suggestedReps,
    );
  }

  /// Batch-detect plateaus for multiple exercises (e.g. all exercises in a
  /// just-completed session). Returns only exercises where a plateau is found.
  Future<List<OverloadSuggestion>> detectPlateausForExercises({
    required String profileId,
    required List<({String exerciseId, String exerciseName})> exercises,
  }) async {
    final suggestions = <OverloadSuggestion>[];

    for (final ex in exercises) {
      final suggestion = await detectPlateau(
        profileId: profileId,
        exerciseId: ex.exerciseId,
        exerciseName: ex.exerciseName,
      );
      if (suggestion != null) {
        suggestions.add(suggestion);
      }
    }

    return suggestions;
  }
}
