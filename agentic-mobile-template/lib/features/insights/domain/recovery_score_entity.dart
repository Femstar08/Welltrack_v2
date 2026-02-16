/// Recovery Score Entity
/// Deterministic score calculated from stress, sleep, HR, and training load components
class RecoveryScoreEntity {
  final String id;
  final String profileId;
  final DateTime scoreDate;
  final double? stressComponent; // 0-100, nullable if no stress data
  final double? sleepComponent; // 0-100, nullable if no sleep data
  final double? hrComponent; // 0-100, nullable if no HR data
  final double? loadComponent; // 0-100, nullable if no load data
  final double recoveryScore; // Weighted average of available components
  final int componentsAvailable; // Count of non-null components
  final Map<String, dynamic>? rawData; // Optional debug/audit data

  const RecoveryScoreEntity({
    required this.id,
    required this.profileId,
    required this.scoreDate,
    this.stressComponent,
    this.sleepComponent,
    this.hrComponent,
    this.loadComponent,
    required this.recoveryScore,
    required this.componentsAvailable,
    this.rawData,
  });

  /// Get interpretation label for the recovery score
  String get interpretationLabel {
    if (recoveryScore >= 80) return 'Excellent';
    if (recoveryScore >= 60) return 'Good';
    if (recoveryScore >= 40) return 'Moderate';
    if (recoveryScore >= 20) return 'Low';
    return 'Critical';
  }

  /// Get color code for the recovery score
  RecoveryScoreColor get colorCode {
    if (recoveryScore >= 80) return RecoveryScoreColor.green;
    if (recoveryScore >= 60) return RecoveryScoreColor.lightGreen;
    if (recoveryScore >= 40) return RecoveryScoreColor.yellow;
    if (recoveryScore >= 20) return RecoveryScoreColor.orange;
    return RecoveryScoreColor.red;
  }

  /// Get interpretation description
  String get description {
    switch (interpretationLabel) {
      case 'Excellent':
        return 'Your body is well-recovered and ready for intense training.';
      case 'Good':
        return 'Good recovery. You can proceed with moderate to high intensity.';
      case 'Moderate':
        return 'Moderate recovery. Consider lighter training or active recovery.';
      case 'Low':
        return 'Low recovery. Focus on rest and recovery activities.';
      case 'Critical':
        return 'Critical recovery state. Rest is strongly recommended.';
      default:
        return '';
    }
  }

  /// Check if score is complete (all components available)
  bool get isComplete => componentsAvailable == 4;

  /// Get list of missing components
  List<String> get missingComponents {
    final missing = <String>[];
    if (stressComponent == null) missing.add('Stress');
    if (sleepComponent == null) missing.add('Sleep');
    if (hrComponent == null) missing.add('Heart Rate');
    if (loadComponent == null) missing.add('Training Load');
    return missing;
  }

  /// Calculate trend compared to another score
  RecoveryTrend getTrendComparedTo(RecoveryScoreEntity? previous) {
    if (previous == null) return RecoveryTrend.flat;
    final diff = recoveryScore - previous.recoveryScore;
    if (diff > 5) return RecoveryTrend.up;
    if (diff < -5) return RecoveryTrend.down;
    return RecoveryTrend.flat;
  }

  /// Get component breakdown as formatted string
  String get componentBreakdown {
    final parts = <String>[];
    if (stressComponent != null) {
      parts.add('Stress: ${stressComponent!.toStringAsFixed(0)}');
    }
    if (sleepComponent != null) {
      parts.add('Sleep: ${sleepComponent!.toStringAsFixed(0)}');
    }
    if (hrComponent != null) {
      parts.add('HR: ${hrComponent!.toStringAsFixed(0)}');
    }
    if (loadComponent != null) {
      parts.add('Load: ${loadComponent!.toStringAsFixed(0)}');
    }
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'score_date': scoreDate.toIso8601String(),
      'stress_component': stressComponent,
      'sleep_component': sleepComponent,
      'hr_component': hrComponent,
      'load_component': loadComponent,
      'recovery_score': recoveryScore,
      'components_available': componentsAvailable,
      'raw_data': rawData,
    };
  }

  factory RecoveryScoreEntity.fromJson(Map<String, dynamic> json) {
    return RecoveryScoreEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      scoreDate: DateTime.parse(json['score_date'] as String),
      stressComponent: json['stress_component'] as double?,
      sleepComponent: json['sleep_component'] as double?,
      hrComponent: json['hr_component'] as double?,
      loadComponent: json['load_component'] as double?,
      recoveryScore: (json['recovery_score'] as num).toDouble(),
      componentsAvailable: json['components_available'] as int,
      rawData: json['raw_data'] as Map<String, dynamic>?,
    );
  }

  RecoveryScoreEntity copyWith({
    String? id,
    String? profileId,
    DateTime? scoreDate,
    double? stressComponent,
    double? sleepComponent,
    double? hrComponent,
    double? loadComponent,
    double? recoveryScore,
    int? componentsAvailable,
    Map<String, dynamic>? rawData,
  }) {
    return RecoveryScoreEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      scoreDate: scoreDate ?? this.scoreDate,
      stressComponent: stressComponent ?? this.stressComponent,
      sleepComponent: sleepComponent ?? this.sleepComponent,
      hrComponent: hrComponent ?? this.hrComponent,
      loadComponent: loadComponent ?? this.loadComponent,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      componentsAvailable: componentsAvailable ?? this.componentsAvailable,
      rawData: rawData ?? this.rawData,
    );
  }
}

enum RecoveryScoreColor {
  green, // 80-100
  lightGreen, // 60-79
  yellow, // 40-59
  orange, // 20-39
  red, // 0-19
}

enum RecoveryTrend {
  up,
  down,
  flat,
}
