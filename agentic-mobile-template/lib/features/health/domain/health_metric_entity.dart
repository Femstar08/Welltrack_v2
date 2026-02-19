/// Represents a normalized health metric from any source
class HealthMetricEntity {

  const HealthMetricEntity({
    this.id,
    required this.userId,
    required this.profileId,
    required this.source,
    required this.metricType,
    this.valueNum,
    this.valueText,
    required this.unit,
    required this.startTime,
    this.endTime,
    required this.recordedAt,
    this.rawPayload,
    this.dedupeHash,
    this.validationStatus = ValidationStatus.raw,
    this.ingestionSourceVersion,
    this.processingStatus = ProcessingStatus.pending,
    this.isPrimary = false,
  });

  factory HealthMetricEntity.fromSupabaseJson(Map<String, dynamic> json) {
    return HealthMetricEntity(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      profileId: json['profile_id'] as String,
      source: HealthSource.values.firstWhere((e) => e.name == json['source']),
      metricType: MetricType.values.firstWhere((e) => e.name == json['metric_type']),
      valueNum: (json['value_num'] as num?)?.toDouble(),
      valueText: json['value_text'] as String?,
      unit: json['unit'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      rawPayload: json['raw_payload_json'] as Map<String, dynamic>?,
      dedupeHash: json['dedupe_hash'] as String?,
      validationStatus: ValidationStatus.values.firstWhere(
        (e) => e.name == (json['validation_status'] ?? 'raw'),
        orElse: () => ValidationStatus.raw,
      ),
      ingestionSourceVersion: json['ingestion_source_version'] as String?,
      processingStatus: ProcessingStatus.values.firstWhere(
        (e) => e.name == (json['processing_status'] ?? 'pending'),
        orElse: () => ProcessingStatus.pending,
      ),
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
  final String? id;
  final String userId;
  final String profileId;
  final HealthSource source;
  final MetricType metricType;
  final double? valueNum;
  final String? valueText;
  final String unit;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime recordedAt;
  final Map<String, dynamic>? rawPayload;
  final String? dedupeHash;
  final ValidationStatus validationStatus;
  final String? ingestionSourceVersion;
  final ProcessingStatus processingStatus;
  final bool isPrimary;

  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'profile_id': profileId,
      'source': source.name,
      'metric_type': metricType.name,
      'value_num': valueNum,
      'value_text': valueText,
      'unit': unit,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'recorded_at': recordedAt.toIso8601String(),
      'raw_payload_json': rawPayload,
      'dedupe_hash': dedupeHash,
      'validation_status': validationStatus.name,
      'ingestion_source_version': ingestionSourceVersion,
      'processing_status': processingStatus.name,
      'is_primary': isPrimary,
    };
  }
}

enum HealthSource {
  healthconnect,
  healthkit,
  garmin,
  strava,
  manual;
}

enum MetricType {
  sleep,
  stress,
  vo2max,
  steps,
  hr,
  hrv,
  calories,
  distance,
  activeMinutes,
  weight,
  bodyFat,
  bloodPressure,
  spo2;
}

enum ValidationStatus {
  raw,
  validated,
  rejected;
}

enum ProcessingStatus {
  pending,
  processed,
  error;
}
