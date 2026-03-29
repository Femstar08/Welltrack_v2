import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/meal_repository.dart';
import '../data/macro_calculator.dart';
import 'nutrition_targets_provider.dart';
import '../../daily_coach/data/daily_prescription_repository.dart';
import '../../daily_coach/domain/daily_prescription_entity.dart';
import '../../freemium/data/freemium_repository.dart';
import '../../freemium/domain/plan_tier.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_metric_entity.dart';
import '../../workouts/data/workout_repository.dart';

// ---------------------------------------------------------------------------
// State classes
// ---------------------------------------------------------------------------

class MacroSummary {
  const MacroSummary({
    required this.consumed,
    required this.goal,
  });
  final int consumed;
  final int goal;

  int get remaining => goal - consumed;
  bool get isOver => consumed > goal;
}

class CalorieSummary {
  const CalorieSummary({
    required this.baseGoal,
    required this.adjustedGoal,
    required this.consumed,
    this.recoveryBadge,
  });
  final int baseGoal;
  final int adjustedGoal;
  final int consumed;
  final String? recoveryBadge;

  int get remaining => adjustedGoal - consumed;
  bool get isOver => consumed > adjustedGoal;
}

class MicronutrientSummary {
  const MicronutrientSummary({
    this.fatG,
    this.sodiumMg,
    this.cholesterolMg,
    this.carbsG,
    this.sugarG,
    this.fiberG,
  });
  final int? fatG;
  final int? sodiumMg;
  final int? cholesterolMg;
  final int? carbsG;
  final int? sugarG;
  final int? fiberG;
}

class TodayNutritionDashboard {
  const TodayNutritionDashboard({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.micro,
    required this.dayType,
  });
  final MacroSummary protein;
  final MacroSummary carbs;
  final MacroSummary fat;
  final CalorieSummary calories;
  final MicronutrientSummary micro;
  final String dayType;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Macro summary for today: consumed vs goal for protein, carbs, fat.
final todayMacroSummaryProvider = FutureProvider.family<
    ({MacroSummary protein, MacroSummary carbs, MacroSummary fat}),
    String>((ref, profileId) async {
  final mealRepo = ref.watch(mealRepositoryProvider);
  final today = DateTime.now();
  final meals = await mealRepo.getMeals(profileId, today);

  int consumedProtein = 0;
  int consumedCarbs = 0;
  int consumedFat = 0;

  for (final meal in meals) {
    final info = meal.nutritionInfo;
    if (info != null) {
      consumedProtein += (info['protein_g'] as num?)?.toInt() ?? 0;
      consumedCarbs += (info['carbs_g'] as num?)?.toInt() ?? 0;
      consumedFat += (info['fat_g'] as num?)?.toInt() ?? 0;
    }
  }

  // Get targets for today's day type
  final targets = await _getTodayTargets(ref, profileId);

  return (
    protein: MacroSummary(consumed: consumedProtein, goal: targets.proteinG),
    carbs: MacroSummary(consumed: consumedCarbs, goal: targets.carbsG),
    fat: MacroSummary(consumed: consumedFat, goal: targets.fatG),
  );
});

/// Calorie summary for today with recovery-adjusted goal.
final todayCalorieSummaryProvider =
    FutureProvider.family<CalorieSummary, String>((ref, profileId) async {
  // Read all dependencies before any await (Riverpod best practice)
  final mealRepo = ref.watch(mealRepositoryProvider);
  final prescriptionRepo = ref.watch(dailyPrescriptionRepositoryProvider);
  final targetsState = ref.watch(nutritionTargetsProvider(profileId));

  final today = DateTime.now();
  final meals = await mealRepo.getMeals(profileId, today);

  int consumed = 0;
  for (final meal in meals) {
    final info = meal.nutritionInfo;
    if (info != null) {
      consumed += (info['calories'] as num?)?.toInt() ?? 0;
    }
  }

  final prescription =
      await prescriptionRepo.getTodayPrescription(profileId);
  final dayType = _planTypeToDayType(prescription?.planType);
  final baseDayTargets = targetsState.forDayType(dayType);
  final baseGoal = baseDayTargets.calories;

  // Apply recovery adjustment for PRO users
  final tier =
      await ref.read(currentPlanTierProvider.future);
  int adjustedGoal = baseGoal;
  String? recoveryBadge;

  if (tier == PlanTier.pro && prescription != null) {
    final adjusted = MacroCalculator.applyRecoveryAdjustment(
      base: MacroTargets(
        calories: baseGoal,
        proteinG: baseDayTargets.proteinG,
        carbsG: baseDayTargets.carbsG,
        fatG: baseDayTargets.fatG,
      ),
      recoveryScore: prescription.recoveryScore,
      calorieModifier: prescription.calorieModifier,
      calorieAdjustmentPct: prescription.calorieAdjustmentPercent,
    );
    adjustedGoal = adjusted.calories;
    recoveryBadge = MacroCalculator.recoveryAdjustmentLabel(
        prescription.recoveryScore);
  }

  return CalorieSummary(
    baseGoal: baseGoal,
    adjustedGoal: adjustedGoal,
    consumed: consumed,
    recoveryBadge: recoveryBadge,
  );
});

/// Micronutrient summary for today (null for untracked nutrients).
final todayMicronutrientSummaryProvider =
    FutureProvider.family<MicronutrientSummary, String>(
        (ref, profileId) async {
  final mealRepo = ref.watch(mealRepositoryProvider);
  final today = DateTime.now();
  final meals = await mealRepo.getMeals(profileId, today);

  int? fatG, sodiumMg, cholesterolMg, carbsG, sugarG, fiberG;

  for (final meal in meals) {
    final info = meal.nutritionInfo;
    if (info == null) continue;

    if (info.containsKey('fat_g')) {
      fatG = (fatG ?? 0) + ((info['fat_g'] as num?)?.toInt() ?? 0);
    }
    if (info.containsKey('sodium_mg')) {
      sodiumMg =
          (sodiumMg ?? 0) + ((info['sodium_mg'] as num?)?.toInt() ?? 0);
    }
    if (info.containsKey('cholesterol_mg')) {
      cholesterolMg = (cholesterolMg ?? 0) +
          ((info['cholesterol_mg'] as num?)?.toInt() ?? 0);
    }
    if (info.containsKey('carbs_g')) {
      carbsG = (carbsG ?? 0) + ((info['carbs_g'] as num?)?.toInt() ?? 0);
    }
    if (info.containsKey('sugar_g')) {
      sugarG = (sugarG ?? 0) + ((info['sugar_g'] as num?)?.toInt() ?? 0);
    }
    if (info.containsKey('fiber_g')) {
      fiberG = (fiberG ?? 0) + ((info['fiber_g'] as num?)?.toInt() ?? 0);
    }
  }

  return MicronutrientSummary(
    fatG: fatG,
    sodiumMg: sodiumMg,
    cholesterolMg: cholesterolMg,
    carbsG: carbsG,
    sugarG: sugarG,
    fiberG: fiberG,
  );
});

/// Combined dashboard provider — merges macros, calories, and micronutrients.
final todayNutritionDashboardProvider =
    FutureProvider.family<TodayNutritionDashboard, String>(
        (ref, profileId) async {
  final macros = await ref.read(todayMacroSummaryProvider(profileId).future);
  final calories =
      await ref.read(todayCalorieSummaryProvider(profileId).future);
  final micro =
      await ref.read(todayMicronutrientSummaryProvider(profileId).future);

  final prescriptionRepo = ref.read(dailyPrescriptionRepositoryProvider);
  final prescription =
      await prescriptionRepo.getTodayPrescription(profileId);
  final dayType = _planTypeToDayType(prescription?.planType);

  return TodayNutritionDashboard(
    protein: macros.protein,
    carbs: macros.carbs,
    fat: macros.fat,
    calories: calories,
    micro: micro,
    dayType: dayType,
  );
});

/// Today's step count from Health Connect / Garmin.
final todayStepsProvider =
    FutureProvider.family<int?, String>((ref, profileId) async {
  final healthRepo = ref.watch(healthRepositoryProvider);
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final metrics = await healthRepo.getMetrics(
    profileId,
    MetricType.steps,
    startDate: startOfDay,
    endDate: endOfDay,
  );

  if (metrics.isEmpty) return null;
  return metrics.fold<double>(0, (sum, m) => sum + (m.valueNum ?? 0)).toInt();
});

/// Today's exercise summary: calories burned and total duration.
class ExerciseSummary {
  const ExerciseSummary({
    required this.caloriesBurned,
    required this.durationMinutes,
  });
  final int caloriesBurned;
  final int durationMinutes;
}

/// Today's exercise calories + duration from completed workouts and health metrics.
final todayExerciseProvider =
    FutureProvider.family<ExerciseSummary, String>((ref, profileId) async {
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  // Active calories from Health Connect / Garmin
  final healthRepo = ref.watch(healthRepositoryProvider);
  final calMetrics = await healthRepo.getMetrics(
    profileId,
    MetricType.calories,
    startDate: startOfDay,
    endDate: endOfDay,
  );
  final activeCals =
      calMetrics.fold<double>(0, (sum, m) => sum + (m.valueNum ?? 0)).toInt();

  // Duration from completed workouts today
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  final todayWorkouts = await workoutRepo.getTodayWorkouts(profileId);
  final totalMinutes = todayWorkouts
      .where((w) => w.completed)
      .fold<int>(0, (sum, w) => sum + (w.durationMinutes ?? 0));

  return ExerciseSummary(
    caloriesBurned: activeCals,
    durationMinutes: totalMinutes,
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _planTypeToDayType(PlanType? planType) {
  switch (planType ?? PlanType.normal) {
    case PlanType.push:
      return 'strength';
    case PlanType.normal:
      return 'cardio';
    case PlanType.easy:
    case PlanType.rest:
      return 'rest';
  }
}

Future<MacroTargets> _getTodayTargets(
    Ref ref, String profileId) async {
  // Read all sync dependencies before any await
  final prescriptionRepo = ref.watch(dailyPrescriptionRepositoryProvider);
  final targetsState = ref.watch(nutritionTargetsProvider(profileId));

  final prescription =
      await prescriptionRepo.getTodayPrescription(profileId);
  final dayType = _planTypeToDayType(prescription?.planType);
  final dayTargets = targetsState.forDayType(dayType);

  return MacroTargets(
    calories: dayTargets.calories,
    proteinG: dayTargets.proteinG,
    carbsG: dayTargets.carbsG,
    fatG: dayTargets.fatG,
  );
}
