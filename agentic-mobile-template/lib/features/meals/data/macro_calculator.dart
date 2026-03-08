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

  /// Applies a recovery-score-based calorie (and macro) adjustment to an
  /// already-computed [MacroTargets] baseline.
  ///
  /// Rules (from CLAUDE.md Phase 2 table):
  ///   80–100 (push)   → full target — no change
  ///   60–79 (normal)  → maintenance TDEE — no change (targets already include
  ///                     day-type adjustments; treat as-is for maintenance)
  ///   40–59 (easy)    → −10% calories, macro grams scaled proportionally
  ///   0–39  (rest)    → sleep-focused macros: high protein/fat, lower carbs,
  ///                     calories reduced via [calorieModifier] from prescription
  ///
  /// [calorieModifier]        — absolute kcal offset from prescription (e.g. −200)
  /// [calorieAdjustmentPct]   — fractional offset from prescription (e.g. −0.10)
  /// When both are set, both are applied cumulatively.
  ///
  /// If [recoveryScore] is null, the targets are returned unchanged (baseline
  /// period or no health data yet).
  static MacroTargets applyRecoveryAdjustment({
    required MacroTargets base,
    double? recoveryScore,
    int calorieModifier = 0,
    double calorieAdjustmentPct = 0.0,
  }) {
    if (recoveryScore == null) return base;

    // Start from the absolute kcal modifier from the prescription engine
    // then apply the percentage modifier on top of that.
    double adjustedCalories = base.calories.toDouble() + calorieModifier;
    if (calorieAdjustmentPct != 0.0) {
      adjustedCalories += base.calories * calorieAdjustmentPct;
    }

    // Clamp to a safe minimum
    final calories = adjustedCalories.round().clamp(1200, 5000);

    // Sleep-focused macro split for rest/recovery tier (0–39)
    // High protein to preserve muscle, moderate fat, low carbs.
    double proteinPct, carbsPct, fatPct;
    if (recoveryScore < 40) {
      proteinPct = 0.40;
      carbsPct = 0.25;
      fatPct = 0.35;
    } else {
      // For other tiers, preserve the existing macro ratio from the base targets
      final total = base.proteinG * 4 + base.carbsG * 4 + base.fatG * 9;
      if (total > 0) {
        proteinPct = (base.proteinG * 4) / total;
        carbsPct = (base.carbsG * 4) / total;
        fatPct = (base.fatG * 9) / total;
      } else {
        // Fallback balanced split
        proteinPct = 0.30;
        carbsPct = 0.40;
        fatPct = 0.30;
      }
    }

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

  /// Returns a human-readable label describing the recovery adjustment applied.
  /// Used in the UI to explain why the calorie target changed.
  static String recoveryAdjustmentLabel(double? recoveryScore) {
    if (recoveryScore == null) return '';
    if (recoveryScore >= 80) return 'Full target — excellent recovery';
    if (recoveryScore >= 60) return 'Maintenance — good recovery';
    if (recoveryScore >= 40) return 'Reduced −10% — fair recovery';
    return 'Sleep-focused macros — low recovery';
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
