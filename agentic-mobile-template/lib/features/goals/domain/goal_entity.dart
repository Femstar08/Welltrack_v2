import '../../insights/domain/forecast_entity.dart';

class GoalEntity {

  const GoalEntity({
    required this.id,
    required this.profileId,
    required this.metricType,
    this.goalDescription,
    required this.targetValue,
    required this.currentValue,
    this.initialValue,
    required this.unit,
    this.deadline,
    this.priority = 0,
    this.expectedDate,
    this.confidenceScore,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.forecast,
  });

  factory GoalEntity.fromJson(
    Map<String, dynamic> json, {
    ForecastEntity? forecast,
  }) {
    return GoalEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      metricType: json['metric_type'] as String? ?? '',
      goalDescription: json['goal_description'] as String?,
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      initialValue: (json['initial_value'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? '',
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      priority: json['priority'] as int? ?? 0,
      expectedDate: json['expected_date'] != null
          ? DateTime.parse(json['expected_date'] as String)
          : null,
      confidenceScore:
          (json['confidence_score'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      forecast: forecast,
    );
  }
  final String id;
  final String profileId;
  final String metricType;
  final String? goalDescription;
  final double targetValue;
  final double currentValue;
  final double? initialValue;
  final String unit;
  final DateTime? deadline;
  final int priority;
  final DateTime? expectedDate;
  final double? confidenceScore;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ForecastEntity? forecast;

  double get progressPercentage {
    if (targetValue == currentValue) return 100.0;
    final start = initialValue ?? currentValue;
    final totalRange = (targetValue - start).abs();
    if (totalRange == 0) return 100.0;
    final progress = (currentValue - start).abs();
    return (progress / totalRange * 100).clamp(0, 100);
  }

  String get statusLabel {
    if (forecast == null) return 'No Data';
    if (!forecast!.isAchievable) return 'Off Track';
    if (forecast!.isMovingTowardTarget) {
      if (forecast!.confidence == ForecastConfidence.high) return 'On Track';
      return 'Slightly Behind';
    }
    return 'Off Track';
  }

  String get statusColor {
    switch (statusLabel) {
      case 'On Track':
        return 'green';
      case 'Slightly Behind':
        return 'amber';
      case 'Off Track':
        return 'red';
      default:
        return 'grey';
    }
  }

  String get metricDisplayName {
    return displayNameForMetricType(metricType);
  }

  static String displayNameForMetricType(String type) {
    switch (type) {
      case 'weight':
        return 'Weight';
      case 'vo2max':
        return 'VO2 Max';
      case 'steps':
        return 'Daily Steps';
      case 'sleep':
        return 'Sleep Duration';
      case 'hr':
        return 'Resting Heart Rate';
      case 'hrv':
        return 'Heart Rate Variability';
      case 'calories':
        return 'Calories';
      case 'distance':
        return 'Distance';
      case 'active_minutes':
        return 'Active Minutes';
      case 'body_fat':
        return 'Body Fat';
      case 'blood_pressure':
        return 'Blood Pressure';
      case 'spo2':
        return 'SpO2';
      case 'stress':
        return 'Stress Score';
      default:
        return type;
    }
  }

  static String defaultUnitForMetricType(String type) {
    switch (type) {
      case 'weight':
        return 'kg';
      case 'vo2max':
        return 'mL/kg/min';
      case 'steps':
        return 'steps';
      case 'sleep':
        return 'hours';
      case 'hr':
        return 'bpm';
      case 'hrv':
        return 'ms';
      case 'calories':
        return 'kcal';
      case 'distance':
        return 'km';
      case 'active_minutes':
        return 'min';
      case 'body_fat':
        return '%';
      case 'blood_pressure':
        return 'mmHg';
      case 'spo2':
        return '%';
      case 'stress':
        return '';
      default:
        return '';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'metric_type': metricType,
      'goal_description': goalDescription,
      'target_value': targetValue,
      'current_value': currentValue,
      'initial_value': initialValue,
      'unit': unit,
      'deadline': deadline?.toIso8601String().split('T').first,
      'priority': priority,
      'expected_date': expectedDate?.toIso8601String().split('T').first,
      'confidence_score': confidenceScore,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  GoalEntity copyWith({
    String? metricType,
    String? goalDescription,
    double? targetValue,
    double? currentValue,
    double? initialValue,
    String? unit,
    DateTime? deadline,
    int? priority,
    DateTime? expectedDate,
    double? confidenceScore,
    bool? isActive,
    ForecastEntity? forecast,
  }) {
    return GoalEntity(
      id: id,
      profileId: profileId,
      metricType: metricType ?? this.metricType,
      goalDescription: goalDescription ?? this.goalDescription,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      initialValue: initialValue ?? this.initialValue,
      unit: unit ?? this.unit,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      expectedDate: expectedDate ?? this.expectedDate,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      forecast: forecast ?? this.forecast,
    );
  }
}
