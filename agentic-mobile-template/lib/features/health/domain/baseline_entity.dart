import 'health_metric_entity.dart';

/// Represents a baseline calibration record for a health metric
class BaselineEntity {

  const BaselineEntity({
    this.id,
    required this.profileId,
    required this.metricType,
    this.baselineValue,
    this.dataPointsCount = 0,
    required this.captureStart,
    this.captureEnd,
    this.isComplete = false,
    this.calibrationStatus = CalibrationStatus.pending,
    this.notes,
  });

  factory BaselineEntity.fromSupabaseJson(Map<String, dynamic> json) {
    return BaselineEntity(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String,
      metricType: MetricType.values.firstWhere(
        (e) => e.name == json['metric_type'],
      ),
      baselineValue: (json['baseline_value'] as num?)?.toDouble(),
      dataPointsCount: json['data_points_count'] as int? ?? 0,
      captureStart: DateTime.parse(json['capture_start'] as String),
      captureEnd: json['capture_end'] != null
          ? DateTime.parse(json['capture_end'] as String)
          : null,
      isComplete: json['is_complete'] as bool? ?? false,
      calibrationStatus: CalibrationStatus.values.firstWhere(
        (e) => e.name == (json['calibration_status'] ?? 'pending'),
        orElse: () => CalibrationStatus.pending,
      ),
      notes: json['notes'] as String?,
    );
  }
  final String? id;
  final String profileId;
  final MetricType metricType;
  final double? baselineValue;
  final int dataPointsCount;
  final DateTime captureStart;
  final DateTime? captureEnd;
  final bool isComplete;
  final CalibrationStatus calibrationStatus;
  final String? notes;

  /// Check if baseline calibration has sufficient data
  /// Requires: 14-day span + at least 10 data points
  bool isCalibrationReady() {
    if (captureEnd == null) return false;

    final daysDuration = captureEnd!.difference(captureStart).inDays;
    return daysDuration >= 14 && dataPointsCount >= 10;
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      'metric_type': metricType.name,
      'baseline_value': baselineValue,
      'data_points_count': dataPointsCount,
      'capture_start': captureStart.toIso8601String(),
      'capture_end': captureEnd?.toIso8601String(),
      'is_complete': isComplete,
      'calibration_status': calibrationStatus.name,
      'notes': notes,
    };
  }

  BaselineEntity copyWith({
    String? id,
    String? profileId,
    MetricType? metricType,
    double? baselineValue,
    int? dataPointsCount,
    DateTime? captureStart,
    DateTime? captureEnd,
    bool? isComplete,
    CalibrationStatus? calibrationStatus,
    String? notes,
  }) {
    return BaselineEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      metricType: metricType ?? this.metricType,
      baselineValue: baselineValue ?? this.baselineValue,
      dataPointsCount: dataPointsCount ?? this.dataPointsCount,
      captureStart: captureStart ?? this.captureStart,
      captureEnd: captureEnd ?? this.captureEnd,
      isComplete: isComplete ?? this.isComplete,
      calibrationStatus: calibrationStatus ?? this.calibrationStatus,
      notes: notes ?? this.notes,
    );
  }
}

enum CalibrationStatus {
  pending,
  inProgress,
  complete;
}
