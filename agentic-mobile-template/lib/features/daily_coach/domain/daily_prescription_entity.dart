// lib/features/daily_coach/domain/daily_prescription_entity.dart

/// Score-based plan type per CLAUDE.md Phase 2 table.
enum PlanType {
  push,   // recovery 80–100
  normal, // recovery 60–79
  easy,   // recovery 40–59
  rest,   // recovery 0–39
}

extension PlanTypeExtension on PlanType {
  String get dbValue => name;

  static PlanType fromDbValue(String value) {
    switch (value) {
      case 'push':
        return PlanType.push;
      case 'normal':
        return PlanType.normal;
      case 'easy':
        return PlanType.easy;
      case 'rest':
        return PlanType.rest;
      default:
        return PlanType.normal;
    }
  }
}

enum PrescriptionScenario {
  wellRested,
  tiredNotSore,
  sore,
  verySore,
  behindSteps,
  weightStalling,
  busyDay,
  unwell,
  defaultPlan,
}

extension PrescriptionScenarioExtension on PrescriptionScenario {
  /// DB-friendly snake_case string representation.
  String get dbValue {
    switch (this) {
      case PrescriptionScenario.wellRested:
        return 'well_rested';
      case PrescriptionScenario.tiredNotSore:
        return 'tired_not_sore';
      case PrescriptionScenario.sore:
        return 'sore';
      case PrescriptionScenario.verySore:
        return 'very_sore';
      case PrescriptionScenario.behindSteps:
        return 'behind_steps';
      case PrescriptionScenario.weightStalling:
        return 'weight_stalling';
      case PrescriptionScenario.busyDay:
        return 'busy_day';
      case PrescriptionScenario.unwell:
        return 'unwell';
      case PrescriptionScenario.defaultPlan:
        return 'default';
    }
  }

  static PrescriptionScenario fromDbValue(String value) {
    switch (value) {
      case 'well_rested':
        return PrescriptionScenario.wellRested;
      case 'tired_not_sore':
        return PrescriptionScenario.tiredNotSore;
      case 'sore':
        return PrescriptionScenario.sore;
      case 'very_sore':
        return PrescriptionScenario.verySore;
      case 'behind_steps':
        return PrescriptionScenario.behindSteps;
      case 'weight_stalling':
        return PrescriptionScenario.weightStalling;
      case 'busy_day':
        return PrescriptionScenario.busyDay;
      case 'unwell':
        return PrescriptionScenario.unwell;
      default:
        return PrescriptionScenario.defaultPlan;
    }
  }
}

enum WorkoutDirective {
  fullSession,
  reducedVolume,
  activeRecovery,
  quickSession,
  rest,
}

extension WorkoutDirectiveExtension on WorkoutDirective {
  String get dbValue {
    switch (this) {
      case WorkoutDirective.fullSession:
        return 'full_session';
      case WorkoutDirective.reducedVolume:
        return 'reduced_volume';
      case WorkoutDirective.activeRecovery:
        return 'active_recovery';
      case WorkoutDirective.quickSession:
        return 'quick_session';
      case WorkoutDirective.rest:
        return 'rest';
    }
  }

  static WorkoutDirective fromDbValue(String value) {
    switch (value) {
      case 'full_session':
        return WorkoutDirective.fullSession;
      case 'reduced_volume':
        return WorkoutDirective.reducedVolume;
      case 'active_recovery':
        return WorkoutDirective.activeRecovery;
      case 'quick_session':
        return WorkoutDirective.quickSession;
      case 'rest':
        return WorkoutDirective.rest;
      default:
        return WorkoutDirective.fullSession;
    }
  }
}

enum MealDirective {
  standard,
  extraCarbs,
  highProtein,
  light,
  grabAndGo,
  hydrationFocus,
}

extension MealDirectiveExtension on MealDirective {
  String get dbValue {
    switch (this) {
      case MealDirective.standard:
        return 'standard';
      case MealDirective.extraCarbs:
        return 'extra_carbs';
      case MealDirective.highProtein:
        return 'high_protein';
      case MealDirective.light:
        return 'light';
      case MealDirective.grabAndGo:
        return 'grab_and_go';
      case MealDirective.hydrationFocus:
        return 'hydration_focus';
    }
  }

  static MealDirective fromDbValue(String value) {
    switch (value) {
      case 'extra_carbs':
        return MealDirective.extraCarbs;
      case 'high_protein':
        return MealDirective.highProtein;
      case 'light':
        return MealDirective.light;
      case 'grab_and_go':
        return MealDirective.grabAndGo;
      case 'hydration_focus':
        return MealDirective.hydrationFocus;
      default:
        return MealDirective.standard;
    }
  }
}

class DailyPrescriptionEntity {
  const DailyPrescriptionEntity({
    this.id,
    required this.profileId,
    this.checkinId,
    required this.prescriptionDate,
    this.planType = PlanType.normal,
    this.recoveryScore,
    required this.scenario,
    required this.workoutDirective,
    this.workoutVolumeModifier = 1.0,
    this.workoutNote,
    required this.mealDirective,
    this.calorieModifier = 0,
    this.calorieAdjustmentPercent = 0.0,
    this.stepsNudge,
    this.aiFocusTip,
    this.aiNarrative,
    this.bedtimeHour,
    this.bedtimeMinute,
    this.generatedAt,
    this.aiModel,
    this.isFallback = false,
    this.createdAt,
    this.updatedAt,
  });

  factory DailyPrescriptionEntity.fromJson(Map<String, dynamic> json) {
    return DailyPrescriptionEntity(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String,
      checkinId: json['checkin_id'] as String?,
      prescriptionDate: DateTime.parse(json['prescription_date'] as String),
      planType: json['plan_type'] != null
          ? PlanTypeExtension.fromDbValue(json['plan_type'] as String)
          : PlanType.normal,
      recoveryScore: json['recovery_score'] != null
          ? (json['recovery_score'] as num).toDouble()
          : null,
      scenario: PrescriptionScenarioExtension.fromDbValue(
        json['scenario'] as String,
      ),
      workoutDirective: WorkoutDirectiveExtension.fromDbValue(
        json['workout_directive'] as String,
      ),
      workoutVolumeModifier: json['workout_volume_modifier'] != null
          ? (json['workout_volume_modifier'] as num).toDouble()
          : 1.0,
      workoutNote: json['workout_note'] as String?,
      mealDirective: MealDirectiveExtension.fromDbValue(
        json['meal_directive'] as String,
      ),
      calorieModifier: json['calorie_modifier'] != null
          ? (json['calorie_modifier'] as num).toInt()
          : 0,
      calorieAdjustmentPercent: json['calorie_adjustment_percent'] != null
          ? (json['calorie_adjustment_percent'] as num).toDouble()
          : 0.0,
      stepsNudge: json['steps_nudge'] as String?,
      aiFocusTip: json['ai_focus_tip'] as String?,
      aiNarrative: json['ai_narrative'] as String?,
      bedtimeHour: json['bedtime_hour'] != null
          ? (json['bedtime_hour'] as num).toInt()
          : null,
      bedtimeMinute: json['bedtime_minute'] != null
          ? (json['bedtime_minute'] as num).toInt()
          : null,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : null,
      aiModel: json['ai_model'] as String?,
      isFallback: json['is_fallback'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  final String? id;
  final String profileId;
  final String? checkinId;
  final DateTime prescriptionDate;
  final PlanType planType;

  /// Recovery score 0–100 used to determine plan type.
  final double? recoveryScore;

  final PrescriptionScenario scenario;
  final WorkoutDirective workoutDirective;
  final double workoutVolumeModifier;
  final String? workoutNote;
  final MealDirective mealDirective;
  final int calorieModifier;

  /// Percentage calorie adjustment (e.g. -0.10 = -10%).
  final double calorieAdjustmentPercent;

  final String? stepsNudge;
  final String? aiFocusTip;
  final String? aiNarrative;
  final int? bedtimeHour;
  final int? bedtimeMinute;
  final DateTime? generatedAt;
  final String? aiModel;
  final bool isFallback;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasWorkout => workoutDirective != WorkoutDirective.rest;

  /// e.g. "10:45 PM"
  String get bedtimeDisplay {
    if (bedtimeHour == null) return '';
    final hour = bedtimeHour!;
    final minute = bedtimeMinute ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      if (checkinId != null) 'checkin_id': checkinId,
      'prescription_date':
          prescriptionDate.toIso8601String().substring(0, 10),
      'plan_type': planType.dbValue,
      if (recoveryScore != null) 'recovery_score': recoveryScore,
      'scenario': scenario.dbValue,
      'workout_directive': workoutDirective.dbValue,
      'workout_volume_modifier': workoutVolumeModifier,
      if (workoutNote != null) 'workout_note': workoutNote,
      'meal_directive': mealDirective.dbValue,
      'calorie_modifier': calorieModifier,
      'calorie_adjustment_percent': calorieAdjustmentPercent,
      if (stepsNudge != null) 'steps_nudge': stepsNudge,
      if (aiFocusTip != null) 'ai_focus_tip': aiFocusTip,
      if (aiNarrative != null) 'ai_narrative': aiNarrative,
      if (bedtimeHour != null) 'bedtime_hour': bedtimeHour,
      if (bedtimeMinute != null) 'bedtime_minute': bedtimeMinute,
      'generated_at':
          (generatedAt ?? DateTime.now()).toIso8601String(),
      if (aiModel != null) 'ai_model': aiModel,
      'is_fallback': isFallback,
    };
  }

  DailyPrescriptionEntity copyWith({
    String? id,
    String? profileId,
    String? checkinId,
    DateTime? prescriptionDate,
    PlanType? planType,
    double? recoveryScore,
    PrescriptionScenario? scenario,
    WorkoutDirective? workoutDirective,
    double? workoutVolumeModifier,
    String? workoutNote,
    MealDirective? mealDirective,
    int? calorieModifier,
    double? calorieAdjustmentPercent,
    String? stepsNudge,
    String? aiFocusTip,
    String? aiNarrative,
    int? bedtimeHour,
    int? bedtimeMinute,
    DateTime? generatedAt,
    String? aiModel,
    bool? isFallback,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyPrescriptionEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      checkinId: checkinId ?? this.checkinId,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      planType: planType ?? this.planType,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      scenario: scenario ?? this.scenario,
      workoutDirective: workoutDirective ?? this.workoutDirective,
      workoutVolumeModifier:
          workoutVolumeModifier ?? this.workoutVolumeModifier,
      workoutNote: workoutNote ?? this.workoutNote,
      mealDirective: mealDirective ?? this.mealDirective,
      calorieModifier: calorieModifier ?? this.calorieModifier,
      calorieAdjustmentPercent:
          calorieAdjustmentPercent ?? this.calorieAdjustmentPercent,
      stepsNudge: stepsNudge ?? this.stepsNudge,
      aiFocusTip: aiFocusTip ?? this.aiFocusTip,
      aiNarrative: aiNarrative ?? this.aiNarrative,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
      generatedAt: generatedAt ?? this.generatedAt,
      aiModel: aiModel ?? this.aiModel,
      isFallback: isFallback ?? this.isFallback,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
