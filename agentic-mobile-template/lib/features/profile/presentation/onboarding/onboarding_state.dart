import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingData {
  final String? primaryGoal;
  final String? goalIntensity;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final bool skippedDevices;

  const OnboardingData({
    this.primaryGoal,
    this.goalIntensity,
    this.age,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.skippedDevices = false,
  });

  OnboardingData copyWith({
    String? primaryGoal,
    String? goalIntensity,
    int? age,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    bool? skippedDevices,
  }) {
    return OnboardingData(
      primaryGoal: primaryGoal ?? this.primaryGoal,
      goalIntensity: goalIntensity ?? this.goalIntensity,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      skippedDevices: skippedDevices ?? this.skippedDevices,
    );
  }

  DateTime? get estimatedDateOfBirth {
    if (age == null) return null;
    final now = DateTime.now();
    return DateTime(now.year - age!, now.month, now.day);
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setPrimaryGoal(String goal) {
    state = state.copyWith(primaryGoal: goal);
  }

  void setGoalIntensity(String intensity) {
    state = state.copyWith(goalIntensity: intensity);
  }

  void setAge(int age) {
    state = state.copyWith(age: age);
  }

  void setHeightCm(double height) {
    state = state.copyWith(heightCm: height);
  }

  void setWeightKg(double weight) {
    state = state.copyWith(weightKg: weight);
  }

  void setActivityLevel(String level) {
    state = state.copyWith(activityLevel: level);
  }

  void setSkippedDevices(bool skipped) {
    state = state.copyWith(skippedDevices: skipped);
  }
}

final onboardingDataProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>((ref) {
  return OnboardingNotifier();
});
