/// Insight Entity
/// AI-generated narrative summary for a time period
class InsightEntity {
  final String id;
  final String profileId;
  final PeriodType periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String summaryText; // AI-generated narrative
  final String? aiModel; // e.g., 'gpt-4', 'claude-3'
  final Map<String, dynamic>? metricsSnapshot; // Key metrics for the period
  final DateTime createdAt;

  const InsightEntity({
    required this.id,
    required this.profileId,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.summaryText,
    this.aiModel,
    this.metricsSnapshot,
    required this.createdAt,
  });

  /// Get period label
  String get periodLabel {
    switch (periodType) {
      case PeriodType.day:
        return _formatDate(periodStart);
      case PeriodType.week:
        final end = periodEnd.subtract(const Duration(days: 1));
        return '${_formatDate(periodStart)} - ${_formatDate(end)}';
      case PeriodType.month:
        return _formatMonth(periodStart);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatMonth(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Get metric value from snapshot
  double? getMetric(String key) {
    if (metricsSnapshot == null) return null;
    final value = metricsSnapshot![key];
    if (value is num) return value.toDouble();
    return null;
  }

  /// Check if insight is recent (within last 24 hours)
  bool get isRecent {
    return DateTime.now().difference(createdAt).inHours < 24;
  }

  /// Check if insight is for current period
  bool get isCurrent {
    final now = DateTime.now();
    return now.isAfter(periodStart) && now.isBefore(periodEnd);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'period_type': periodType.name,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'summary_text': summaryText,
      'ai_model': aiModel,
      'metrics_snapshot': metricsSnapshot,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InsightEntity.fromJson(Map<String, dynamic> json) {
    return InsightEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      periodType: PeriodType.values.firstWhere(
        (e) => e.name == json['period_type'],
        orElse: () => PeriodType.week,
      ),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      summaryText: json['summary_text'] as String,
      aiModel: json['ai_model'] as String?,
      metricsSnapshot: json['metrics_snapshot'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  InsightEntity copyWith({
    String? id,
    String? profileId,
    PeriodType? periodType,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? summaryText,
    String? aiModel,
    Map<String, dynamic>? metricsSnapshot,
    DateTime? createdAt,
  }) {
    return InsightEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      periodType: periodType ?? this.periodType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      summaryText: summaryText ?? this.summaryText,
      aiModel: aiModel ?? this.aiModel,
      metricsSnapshot: metricsSnapshot ?? this.metricsSnapshot,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum PeriodType {
  day,
  week,
  month,
}

/// Metrics snapshot structure for consistency
class MetricsSnapshot {
  final double? avgRecoveryScore;
  final double? avgSleepHours;
  final double? avgStress;
  final double? totalTrainingLoad;
  final int? totalWorkouts;
  final double? avgVO2Max;
  final int? totalSteps;
  final int? activeDays;

  const MetricsSnapshot({
    this.avgRecoveryScore,
    this.avgSleepHours,
    this.avgStress,
    this.totalTrainingLoad,
    this.totalWorkouts,
    this.avgVO2Max,
    this.totalSteps,
    this.activeDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'avg_recovery_score': avgRecoveryScore,
      'avg_sleep_hours': avgSleepHours,
      'avg_stress': avgStress,
      'total_training_load': totalTrainingLoad,
      'total_workouts': totalWorkouts,
      'avg_vo2_max': avgVO2Max,
      'total_steps': totalSteps,
      'active_days': activeDays,
    };
  }

  factory MetricsSnapshot.fromJson(Map<String, dynamic> json) {
    return MetricsSnapshot(
      avgRecoveryScore: json['avg_recovery_score'] != null
          ? (json['avg_recovery_score'] as num).toDouble()
          : null,
      avgSleepHours: json['avg_sleep_hours'] != null
          ? (json['avg_sleep_hours'] as num).toDouble()
          : null,
      avgStress: json['avg_stress'] != null
          ? (json['avg_stress'] as num).toDouble()
          : null,
      totalTrainingLoad: json['total_training_load'] != null
          ? (json['total_training_load'] as num).toDouble()
          : null,
      totalWorkouts: json['total_workouts'] as int?,
      avgVO2Max: json['avg_vo2_max'] != null
          ? (json['avg_vo2_max'] as num).toDouble()
          : null,
      totalSteps: json['total_steps'] as int?,
      activeDays: json['active_days'] as int?,
    );
  }
}
