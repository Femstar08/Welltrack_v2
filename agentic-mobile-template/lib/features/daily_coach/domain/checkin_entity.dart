// lib/features/daily_coach/domain/checkin_entity.dart

enum FeelingLevel { great, good, tired, sore, unwell }

enum ScheduleType { busy, normal, flexible }

extension FeelingLevelExtension on FeelingLevel {
  String get value => name;

  static FeelingLevel? fromString(String? s) {
    if (s == null) return null;
    return FeelingLevel.values.firstWhere(
      (e) => e.name == s,
      orElse: () => FeelingLevel.good,
    );
  }
}

extension ScheduleTypeExtension on ScheduleType {
  String get value => name;

  static ScheduleType? fromString(String? s) {
    if (s == null) return null;
    return ScheduleType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ScheduleType.normal,
    );
  }
}

class CheckInEntity {
  const CheckInEntity({
    this.id,
    required this.profileId,
    required this.checkinDate,
    this.feelingLevel,
    this.sleepQuality,
    this.sleepQualityOverride = false,
    this.morningErection,
    this.injuriesNotes,
    this.scheduleType,
    this.isWeekly = false,
    this.erectionQualityWeekly,
    this.isSensitive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String profileId;
  final DateTime checkinDate;

  /// 'great' | 'good' | 'tired' | 'sore' | 'unwell'
  final String? feelingLevel;

  /// 1.0–10.0 (auto-filled from health data; hours approximation)
  final double? sleepQuality;

  final bool sleepQualityOverride;

  /// Sensitive — encrypted in transit via HTTPS + RLS row isolation.
  final bool? morningErection;

  final String? injuriesNotes;

  /// 'busy' | 'normal' | 'flexible'
  final String? scheduleType;

  /// true when this is the Sunday weekly entry
  final bool isWeekly;

  /// 1–10 weekly rating, sensitive
  final int? erectionQualityWeekly;

  /// Marks row for export exclusion and AI stripping
  final bool isSensitive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CheckInEntity.fromJson(Map<String, dynamic> json) {
    return CheckInEntity(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String,
      checkinDate: DateTime.parse(json['checkin_date'] as String),
      feelingLevel: json['feeling_level'] as String?,
      sleepQuality: json['sleep_quality'] != null
          ? (json['sleep_quality'] as num).toDouble()
          : null,
      sleepQualityOverride: json['sleep_quality_override'] as bool? ?? false,
      morningErection: json['morning_erection'] as bool?,
      injuriesNotes: json['injuries_notes'] as String?,
      scheduleType: json['schedule_type'] as String?,
      isWeekly: json['is_weekly'] as bool? ?? false,
      erectionQualityWeekly: json['erection_quality_weekly'] != null
          ? (json['erection_quality_weekly'] as num).toInt()
          : null,
      isSensitive: json['is_sensitive'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Full serialization for DB writes — includes all fields.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      'checkin_date': checkinDate.toIso8601String().substring(0, 10),
      'feeling_level': feelingLevel,
      'sleep_quality': sleepQuality,
      'sleep_quality_override': sleepQualityOverride,
      'morning_erection': morningErection,
      'injuries_notes': injuriesNotes,
      'schedule_type': scheduleType,
      'is_weekly': isWeekly,
      'erection_quality_weekly': erectionQualityWeekly,
      'is_sensitive': isSensitive,
    };
  }

  /// Strips sensitive fields before passing context to AI.
  /// Set [includeVitality] to true only when the user has given explicit consent
  /// via the "Share vitality data with AI" toggle.
  Map<String, dynamic> toAiContextJson({required bool includeVitality}) {
    final base = <String, dynamic>{
      'feeling_level': feelingLevel,
      'sleep_quality': sleepQuality,
      'injuries_notes': injuriesNotes,
      'schedule_type': scheduleType,
      'checkin_date': checkinDate.toIso8601String().substring(0, 10),
    };

    if (includeVitality) {
      base['morning_erection'] = morningErection;
      base['erection_quality_weekly'] = erectionQualityWeekly;
    }

    return base;
  }

  CheckInEntity copyWith({
    String? id,
    String? profileId,
    DateTime? checkinDate,
    String? feelingLevel,
    double? sleepQuality,
    bool? sleepQualityOverride,
    bool? morningErection,
    String? injuriesNotes,
    String? scheduleType,
    bool? isWeekly,
    int? erectionQualityWeekly,
    bool? isSensitive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckInEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      checkinDate: checkinDate ?? this.checkinDate,
      feelingLevel: feelingLevel ?? this.feelingLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      sleepQualityOverride: sleepQualityOverride ?? this.sleepQualityOverride,
      morningErection: morningErection ?? this.morningErection,
      injuriesNotes: injuriesNotes ?? this.injuriesNotes,
      scheduleType: scheduleType ?? this.scheduleType,
      isWeekly: isWeekly ?? this.isWeekly,
      erectionQualityWeekly:
          erectionQualityWeekly ?? this.erectionQualityWeekly,
      isSensitive: isSensitive ?? this.isSensitive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
