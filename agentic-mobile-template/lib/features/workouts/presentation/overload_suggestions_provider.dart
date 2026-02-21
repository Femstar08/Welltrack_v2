// lib/features/workouts/presentation/overload_suggestions_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/overload_detection_service.dart';
import '../data/workout_repository.dart';
import '../domain/overload_suggestion_entity.dart';

/// Provides the [OverloadDetectionService] singleton.
final overloadDetectionServiceProvider =
    Provider<OverloadDetectionService>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return OverloadDetectionService(repo);
});

/// Parameters for the overload suggestions query.
class OverloadSuggestionsParams {
  const OverloadSuggestionsParams({
    required this.profileId,
    required this.exercises,
  });

  final String profileId;
  final List<({String exerciseId, String exerciseName})> exercises;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OverloadSuggestionsParams) return false;
    return profileId == other.profileId &&
        exercises.length == other.exercises.length;
  }

  @override
  int get hashCode => Object.hash(profileId, exercises.length);
}

/// Fetches overload suggestions for a list of exercises.
///
/// Typically called from the session summary screen with the exercises
/// that were just completed.
final overloadSuggestionsProvider = FutureProvider.family<
    List<OverloadSuggestion>, OverloadSuggestionsParams>(
  (ref, params) async {
    final service = ref.watch(overloadDetectionServiceProvider);
    return service.detectPlateausForExercises(
      profileId: params.profileId,
      exercises: params.exercises,
    );
  },
);
