import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/profile/data/profile_repository.dart';
import 'package:welltrack/features/profile/domain/profile_entity.dart';

final activeProfileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileEntity?>>((ref) {
  return ProfileNotifier(ref.watch(profileRepositoryProvider));
});

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileEntity?>> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadActiveProfile();
  }

  Future<void> loadActiveProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getActiveProfile();
      state = AsyncValue.data(profile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateProfile(
    String profileId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final updatedProfile = await _repository.updateProfile(profileId, fields);
      state = AsyncValue.data(updatedProfile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createProfile({
    required String userId,
    required String profileType,
    required String displayName,
    DateTime? dateOfBirth,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? fitnessGoals,
    String? dietaryRestrictions,
    String? allergies,
    String? primaryGoal,
    String? goalIntensity,
    bool isPrimary = true,
  }) async {
    try {
      final profile = await _repository.createProfile(
        userId: userId,
        profileType: profileType,
        displayName: displayName,
        dateOfBirth: dateOfBirth,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        activityLevel: activityLevel,
        fitnessGoals: fitnessGoals,
        dietaryRestrictions: dietaryRestrictions,
        allergies: allergies,
        primaryGoal: primaryGoal,
        goalIntensity: goalIntensity,
        isPrimary: isPrimary,
      );
      state = AsyncValue.data(profile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markOnboardingComplete(String userId) async {
    try {
      await _repository.markOnboardingComplete(userId);
    } catch (e) {
      // Log error but don't update state
      throw Exception('Failed to mark onboarding complete: $e');
    }
  }

  void refresh() {
    loadActiveProfile();
  }
}
