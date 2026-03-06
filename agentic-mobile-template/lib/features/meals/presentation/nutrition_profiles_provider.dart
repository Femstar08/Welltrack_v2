import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/data/profile_repository.dart';

class NutritionProfilesState {
  const NutritionProfilesState({
    this.enabledProfiles = const [],
    this.cuisinePreference = 'balanced',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<String> enabledProfiles;
  final String cuisinePreference;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  NutritionProfilesState copyWith({
    List<String>? enabledProfiles,
    String? cuisinePreference,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return NutritionProfilesState(
      enabledProfiles: enabledProfiles ?? this.enabledProfiles,
      cuisinePreference: cuisinePreference ?? this.cuisinePreference,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NutritionProfilesNotifier
    extends StateNotifier<NutritionProfilesState> {
  NutritionProfilesNotifier(this._repository, this._profileId)
      : super(const NutritionProfilesState(isLoading: true)) {
    _loadProfile();
  }

  final ProfileRepository _repository;
  final String _profileId;

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getProfile(_profileId);
      state = state.copyWith(
        enabledProfiles: List<String>.from(profile.nutritionProfiles),
        cuisinePreference: profile.cuisinePreference,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load: $e');
    }
  }

  void toggleProfile(String profileKey) {
    final current = List<String>.from(state.enabledProfiles);
    if (current.contains(profileKey)) {
      current.remove(profileKey);
    } else {
      current.add(profileKey);
    }
    state = state.copyWith(enabledProfiles: current);
  }

  void setCuisinePreference(String cuisine) {
    state = state.copyWith(cuisinePreference: cuisine);
  }

  Future<bool> save() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.updateProfile(_profileId, {
        'nutrition_profiles': state.enabledProfiles,
        'cuisine_preference': state.cuisinePreference,
      });
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: 'Failed to save: $e');
      return false;
    }
  }
}

final nutritionProfilesProvider = StateNotifierProvider.family<
    NutritionProfilesNotifier, NutritionProfilesState, String>(
  (ref, profileId) {
    final repository = ref.watch(profileRepositoryProvider);
    return NutritionProfilesNotifier(repository, profileId);
  },
);
