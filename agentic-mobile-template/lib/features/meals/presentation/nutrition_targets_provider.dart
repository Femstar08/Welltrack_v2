import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/custom_macro_target_repository.dart';
import '../data/macro_calculator.dart';
import '../domain/custom_macro_target_entity.dart';

class DayTypeTargetState {
  const DayTypeTargetState({
    this.custom,
    this.calculated,
    this.isCustom = false,
    this.isSaving = false,
  });

  final CustomMacroTargetEntity? custom;
  final MacroTargets? calculated;
  final bool isCustom;
  final bool isSaving;

  int get calories =>
      isCustom ? (custom?.calories ?? 0) : (calculated?.calories ?? 0);
  int get proteinG =>
      isCustom ? (custom?.proteinG ?? 0) : (calculated?.proteinG ?? 0);
  int get carbsG =>
      isCustom ? (custom?.carbsG ?? 0) : (calculated?.carbsG ?? 0);
  int get fatG => isCustom ? (custom?.fatG ?? 0) : (calculated?.fatG ?? 0);
}

class NutritionTargetsState {
  const NutritionTargetsState({
    this.strength = const DayTypeTargetState(),
    this.cardio = const DayTypeTargetState(),
    this.rest = const DayTypeTargetState(),
    this.isLoading = false,
    this.error,
  });

  final DayTypeTargetState strength;
  final DayTypeTargetState cardio;
  final DayTypeTargetState rest;
  final bool isLoading;
  final String? error;

  NutritionTargetsState copyWith({
    DayTypeTargetState? strength,
    DayTypeTargetState? cardio,
    DayTypeTargetState? rest,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NutritionTargetsState(
      strength: strength ?? this.strength,
      cardio: cardio ?? this.cardio,
      rest: rest ?? this.rest,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  DayTypeTargetState forDayType(String dayType) {
    switch (dayType) {
      case 'strength':
        return strength;
      case 'cardio':
        return cardio;
      case 'rest':
        return rest;
      default:
        return rest;
    }
  }
}

class NutritionTargetsNotifier
    extends StateNotifier<NutritionTargetsState> {
  NutritionTargetsNotifier(this._repo, this._profileId)
      : super(const NutritionTargetsState());

  final CustomMacroTargetRepository _repo;
  final String _profileId;

  Future<void> loadTargets({
    double? weightKg,
    String? activityLevel,
    String? fitnessGoal,
    String? gender,
    int? age,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final customs = await _repo.getTargets(_profileId);

      DayTypeTargetState buildState(String dayType) {
        final custom = customs.where((c) => c.dayType == dayType).firstOrNull;
        final calculated = MacroCalculator.calculateDailyTargets(
          weightKg: weightKg ?? 75.0,
          activityLevel: activityLevel,
          dayType: dayType,
          fitnessGoal: fitnessGoal,
          gender: gender,
          age: age,
        );
        return DayTypeTargetState(
          custom: custom,
          calculated: calculated,
          isCustom: custom != null,
        );
      }

      state = state.copyWith(
        strength: buildState('strength'),
        cardio: buildState('cardio'),
        rest: buildState('rest'),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> saveTarget({
    required String dayType,
    required int calories,
    required int proteinG,
    required int carbsG,
    required int fatG,
  }) async {
    _updateDayState(
        dayType,
        (s) => DayTypeTargetState(
              custom: s.custom,
              calculated: s.calculated,
              isCustom: true,
              isSaving: true,
            ));

    try {
      final entity = CustomMacroTargetEntity(
        profileId: _profileId,
        dayType: dayType,
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
      );
      final saved = await _repo.saveTarget(entity);
      _updateDayState(
          dayType,
          (s) => DayTypeTargetState(
                custom: saved,
                calculated: s.calculated,
                isCustom: true,
                isSaving: false,
              ));
    } catch (e) {
      _updateDayState(
          dayType,
          (s) => DayTypeTargetState(
                custom: s.custom,
                calculated: s.calculated,
                isCustom: s.isCustom,
                isSaving: false,
              ));
      state = state.copyWith(error: 'Failed to save: $e');
    }
  }

  Future<void> deleteTarget(String dayType) async {
    _updateDayState(
        dayType,
        (s) => DayTypeTargetState(
              custom: s.custom,
              calculated: s.calculated,
              isCustom: s.isCustom,
              isSaving: true,
            ));

    try {
      await _repo.deleteTarget(_profileId, dayType);
      _updateDayState(
          dayType,
          (s) => DayTypeTargetState(
                custom: null,
                calculated: s.calculated,
                isCustom: false,
                isSaving: false,
              ));
    } catch (e) {
      _updateDayState(
          dayType,
          (s) => DayTypeTargetState(
                custom: s.custom,
                calculated: s.calculated,
                isCustom: s.isCustom,
                isSaving: false,
              ));
      state = state.copyWith(error: 'Failed to delete: $e');
    }
  }

  void _updateDayState(
    String dayType,
    DayTypeTargetState Function(DayTypeTargetState) updater,
  ) {
    switch (dayType) {
      case 'strength':
        state = state.copyWith(strength: updater(state.strength));
      case 'cardio':
        state = state.copyWith(cardio: updater(state.cardio));
      case 'rest':
        state = state.copyWith(rest: updater(state.rest));
    }
  }
}

final nutritionTargetsProvider = StateNotifierProvider.family<
    NutritionTargetsNotifier, NutritionTargetsState, String>(
  (ref, profileId) {
    return NutritionTargetsNotifier(
      ref.watch(customMacroTargetRepositoryProvider),
      profileId,
    );
  },
);
