import 'custom_macro_target_repository.dart';

class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  @override
  String toString() =>
      'MacroTargets(cal: $calories, P: ${proteinG}g, C: ${carbsG}g, F: ${fatG}g)';
}

class MacroCalculator {
  MacroCalculator._();

  /// Calculate daily macro targets based on user profile and day type.
  ///
  /// Uses simplified Mifflin-St Jeor BMR estimate (without height, assumes
  /// average height of 170 cm for a reasonable approximation).
  ///
  /// [weightKg] - current body weight in kg
  /// [activityLevel] - 'sedentary', 'light', 'moderate', 'active', 'very_active'
  /// [dayType] - 'strength', 'cardio', 'rest'
  /// [fitnessGoal] - 'lose_weight', 'maintain', 'gain_muscle'
  /// [gender] - 'male', 'female' (defaults to 'male' if null)
  /// [age] - age in years (defaults to 30 if null)
  static MacroTargets calculateDailyTargets({
    required double weightKg,
    String? activityLevel,
    required String dayType,
    String? fitnessGoal,
    String? gender,
    int? age,
  }) {
    final effectiveAge = age ?? 30;
    final effectiveGender = gender ?? 'male';

    // Mifflin-St Jeor BMR (using assumed avg height of 170 cm)
    double bmr;
    if (effectiveGender == 'female') {
      bmr = (10 * weightKg) + (6.25 * 170) - (5 * effectiveAge) - 161;
    } else {
      bmr = (10 * weightKg) + (6.25 * 170) - (5 * effectiveAge) + 5;
    }

    // Activity multiplier for TDEE
    final activityMultiplier = _activityMultiplier(activityLevel);
    var tdee = bmr * activityMultiplier;

    // Day type adjustment
    switch (dayType) {
      case 'strength':
        tdee += 300;
      case 'cardio':
        tdee += 100;
      case 'rest':
        tdee -= 200;
    }

    // Fitness goal adjustment
    switch (fitnessGoal) {
      case 'lose_weight':
        tdee -= 300;
      case 'gain_muscle':
        tdee += 200;
      case 'maintain':
      default:
        break;
    }

    final calories = tdee.round().clamp(1200, 5000);

    // Macro splits by day type (protein/carbs/fat percentages)
    double proteinPct, carbsPct, fatPct;
    switch (dayType) {
      case 'strength':
        proteinPct = 0.30;
        carbsPct = 0.50;
        fatPct = 0.20;
      case 'cardio':
        proteinPct = 0.30;
        carbsPct = 0.40;
        fatPct = 0.30;
      case 'rest':
      default:
        proteinPct = 0.35;
        carbsPct = 0.35;
        fatPct = 0.30;
    }

    // Convert percentages to grams (protein=4cal/g, carbs=4cal/g, fat=9cal/g)
    final proteinG = ((calories * proteinPct) / 4).round();
    final carbsG = ((calories * carbsPct) / 4).round();
    final fatG = ((calories * fatPct) / 9).round();

    return MacroTargets(
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
  }

  /// Resolves macro targets: uses custom targets if available, otherwise falls back
  /// to the formula-based calculation.
  static Future<MacroTargets> resolveTargets({
    required String profileId,
    required String dayType,
    required CustomMacroTargetRepository customRepo,
    double? weightKg,
    String? activityLevel,
    String? fitnessGoal,
    String? gender,
    int? age,
  }) async {
    final custom = await customRepo.getTarget(profileId, dayType);
    if (custom != null) {
      return custom.toMacroTargets();
    }
    return calculateDailyTargets(
      weightKg: weightKg ?? 75.0,
      activityLevel: activityLevel,
      dayType: dayType,
      fitnessGoal: fitnessGoal,
      gender: gender,
      age: age,
    );
  }

  static double _activityMultiplier(String? level) {
    switch (level) {
      case 'sedentary':
        return 1.2;
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'active':
        return 1.725;
      case 'very_active':
        return 1.9;
      default:
        return 1.55; // moderate default
    }
  }
}
