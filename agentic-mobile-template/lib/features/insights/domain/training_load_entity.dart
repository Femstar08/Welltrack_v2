/// Training Load Entity
/// Represents a single workout's training load calculation
class TrainingLoadEntity { // Optional average heart rate

  const TrainingLoadEntity({
    required this.id,
    required this.profileId,
    this.workoutId,
    required this.loadDate,
    required this.durationMinutes,
    required this.intensityFactor,
    required this.trainingLoad,
    required this.loadType,
    this.avgHrBpm,
  });

  factory TrainingLoadEntity.fromJson(Map<String, dynamic> json) {
    return TrainingLoadEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      workoutId: json['workout_id'] as String?,
      loadDate: DateTime.parse(json['load_date'] as String),
      durationMinutes: (json['duration_minutes'] as num).toDouble(),
      intensityFactor: (json['intensity_factor'] as num).toDouble(),
      trainingLoad: (json['training_load'] as num).toDouble(),
      loadType: TrainingLoadType.values.firstWhere(
        (e) => e.name == json['load_type'],
        orElse: () => TrainingLoadType.mixed,
      ),
      avgHrBpm: json['avg_hr_bpm'] != null
          ? (json['avg_hr_bpm'] as num).toDouble()
          : null,
    );
  }
  final String id;
  final String profileId;
  final String? workoutId; // Optional link to wt_workouts
  final DateTime loadDate;
  final double durationMinutes;
  final double intensityFactor; // 0.0 - 2.0+ (1.0 = moderate, 1.5 = hard, 2.0 = max)
  final double trainingLoad; // Computed: duration × intensity
  final TrainingLoadType loadType;
  final double? avgHrBpm;

  /// Calculate training load from duration and intensity
  static double computeTrainingLoad(
    double durationMinutes,
    double intensityFactor,
  ) {
    return durationMinutes * intensityFactor;
  }

  /// Get intensity description
  String get intensityDescription {
    if (intensityFactor >= 2.0) return 'Maximum';
    if (intensityFactor >= 1.5) return 'Hard';
    if (intensityFactor >= 1.0) return 'Moderate';
    if (intensityFactor >= 0.5) return 'Light';
    return 'Recovery';
  }

  /// Get load type label
  String get loadTypeLabel {
    switch (loadType) {
      case TrainingLoadType.cardio:
        return 'Cardio';
      case TrainingLoadType.strength:
        return 'Strength';
      case TrainingLoadType.mixed:
        return 'Mixed';
      case TrainingLoadType.recovery:
        return 'Recovery';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'workout_id': workoutId,
      'load_date': loadDate.toIso8601String(),
      'duration_minutes': durationMinutes,
      'intensity_factor': intensityFactor,
      'training_load': trainingLoad,
      'load_type': loadType.name,
      'avg_hr_bpm': avgHrBpm,
    };
  }

  TrainingLoadEntity copyWith({
    String? id,
    String? profileId,
    String? workoutId,
    DateTime? loadDate,
    double? durationMinutes,
    double? intensityFactor,
    double? trainingLoad,
    TrainingLoadType? loadType,
    double? avgHrBpm,
  }) {
    return TrainingLoadEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      workoutId: workoutId ?? this.workoutId,
      loadDate: loadDate ?? this.loadDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensityFactor: intensityFactor ?? this.intensityFactor,
      trainingLoad: trainingLoad ?? this.trainingLoad,
      loadType: loadType ?? this.loadType,
      avgHrBpm: avgHrBpm ?? this.avgHrBpm,
    );
  }
}

enum TrainingLoadType {
  cardio,
  strength,
  mixed,
  recovery,
}

/// Helper class for weekly load calculations
class WeeklyLoadSummary {

  const WeeklyLoadSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.loads,
    required this.totalLoad,
    required this.avgDailyLoad,
    required this.workoutCount,
    required this.avgIntensity,
  });

  /// Calculate weekly load summary from list of loads
  factory WeeklyLoadSummary.fromLoads({
    required DateTime weekStart,
    required List<TrainingLoadEntity> loads,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final totalLoad = loads.fold<double>(
      0,
      (sum, load) => sum + load.trainingLoad,
    );
    final avgIntensity = loads.isEmpty
        ? 0.0
        : loads.fold<double>(0, (sum, load) => sum + load.intensityFactor) /
            loads.length;

    return WeeklyLoadSummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      loads: loads,
      totalLoad: totalLoad,
      avgDailyLoad: totalLoad / 7,
      workoutCount: loads.length,
      avgIntensity: avgIntensity,
    );
  }
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<TrainingLoadEntity> loads;
  final double totalLoad;
  final double avgDailyLoad;
  final int workoutCount;
  final double avgIntensity;

  /// Calculate load ratio compared to previous week
  double getLoadRatioTo(WeeklyLoadSummary? previous) {
    if (previous == null || previous.totalLoad == 0) return 1.0;
    return totalLoad / previous.totalLoad;
  }

  /// Check if load increased significantly (>30% increase = potential overtraining)
  bool get isSignificantIncrease => totalLoad > 0;

  /// Get load distribution by type
  Map<TrainingLoadType, double> get loadByType {
    final distribution = <TrainingLoadType, double>{};
    for (final load in loads) {
      distribution[load.loadType] =
          (distribution[load.loadType] ?? 0) + load.trainingLoad;
    }
    return distribution;
  }

  /// Get formatted week label
  String get weekLabel {
    final start = weekStart;
    final end = weekEnd.subtract(const Duration(days: 1));
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }
}

/// Daily load summary for charts
class DailyLoadPoint {

  const DailyLoadPoint({
    required this.date,
    required this.load,
    required this.workoutCount,
    required this.avgIntensity,
  });

  factory DailyLoadPoint.fromLoads({
    required DateTime date,
    required List<TrainingLoadEntity> loads,
  }) {
    final totalLoad = loads.fold<double>(
      0,
      (sum, load) => sum + load.trainingLoad,
    );
    final avgIntensity = loads.isEmpty
        ? 0.0
        : loads.fold<double>(0, (sum, load) => sum + load.intensityFactor) /
            loads.length;

    return DailyLoadPoint(
      date: date,
      load: totalLoad,
      workoutCount: loads.length,
      avgIntensity: avgIntensity,
    );
  }
  final DateTime date;
  final double load;
  final int workoutCount;
  final double avgIntensity;

  String get dateLabel {
    final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekday[date.weekday - 1];
  }
}
