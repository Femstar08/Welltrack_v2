/// Baseline Entity
/// Represents a 14-day calibration record for a single metric
class BaselineEntity {

  const BaselineEntity({
    required this.id,
    required this.profileId,
    required this.metricType,
    this.baselineValue,
    this.dataPointsCount = 0,
    this.captureStart,
    this.captureEnd,
    this.calibrationStatus = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BaselineEntity.fromJson(Map<String, dynamic> json) {
    return BaselineEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      metricType: json['metric_type'] as String,
      baselineValue: (json['baseline_value'] as num?)?.toDouble(),
      dataPointsCount: (json['data_points_count'] as num?)?.toInt() ?? 0,
      captureStart: json['capture_start'] != null
          ? DateTime.parse(json['capture_start'] as String)
          : null,
      captureEnd: json['capture_end'] != null
          ? DateTime.parse(json['capture_end'] as String)
          : null,
      calibrationStatus: json['calibration_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String profileId;
  final String metricType;
  final double? baselineValue;
  final int dataPointsCount;
  final DateTime? captureStart;
  final DateTime? captureEnd;
  final String calibrationStatus; // 'pending' | 'in_progress' | 'complete'
  final DateTime createdAt;
  final DateTime updatedAt;

  static const int calibrationDays = 14;

  /// Days elapsed since capture_start (0 if not started)
  int get daysElapsed {
    if (captureStart == null) return 0;
    final now = DateTime.now();
    return now.difference(captureStart!).inDays.clamp(0, calibrationDays);
  }

  /// Days remaining in the 14-day window
  int get daysRemaining => (calibrationDays - daysElapsed).clamp(0, calibrationDays);

  /// Progress as a fraction 0.0 → 1.0
  double get progressPercentage => daysElapsed / calibrationDays;

  /// True when calibration is marked complete
  bool get isComplete => calibrationStatus == 'complete';

  BaselineEntity copyWith({
    double? baselineValue,
    int? dataPointsCount,
    DateTime? captureEnd,
    String? calibrationStatus,
  }) {
    return BaselineEntity(
      id: id,
      profileId: profileId,
      metricType: metricType,
      baselineValue: baselineValue ?? this.baselineValue,
      dataPointsCount: dataPointsCount ?? this.dataPointsCount,
      captureStart: captureStart,
      captureEnd: captureEnd ?? this.captureEnd,
      calibrationStatus: calibrationStatus ?? this.calibrationStatus,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'metric_type': metricType,
      'baseline_value': baselineValue,
      'data_points_count': dataPointsCount,
      'capture_start': captureStart?.toIso8601String(),
      'capture_end': captureEnd?.toIso8601String(),
      'calibration_status': calibrationStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// The metric types we track during baseline calibration
const List<String> kBaselineMetricTypes = [
  'sleep',
  'stress',
  'resting_hr',
  'training_load',
  'steps',
  'weight',
];
