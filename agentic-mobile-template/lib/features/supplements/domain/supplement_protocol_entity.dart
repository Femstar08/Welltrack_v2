// lib/features/supplements/domain/supplement_protocol_entity.dart

enum ProtocolTimeOfDay {
  am,
  pm,
  withMeal,
  bedtime;

  String get label {
    switch (this) {
      case ProtocolTimeOfDay.am:
        return 'Morning';
      case ProtocolTimeOfDay.pm:
        return 'Evening';
      case ProtocolTimeOfDay.withMeal:
        return 'With Meal';
      case ProtocolTimeOfDay.bedtime:
        return 'Bedtime';
    }
  }

  static ProtocolTimeOfDay fromString(String value) {
    switch (value.toLowerCase()) {
      case 'am':
        return ProtocolTimeOfDay.am;
      case 'pm':
        return ProtocolTimeOfDay.pm;
      case 'with_meal':
        return ProtocolTimeOfDay.withMeal;
      case 'bedtime':
        return ProtocolTimeOfDay.bedtime;
      default:
        return ProtocolTimeOfDay.am;
    }
  }

  String toJson() {
    switch (this) {
      case ProtocolTimeOfDay.am:
        return 'am';
      case ProtocolTimeOfDay.pm:
        return 'pm';
      case ProtocolTimeOfDay.withMeal:
        return 'with_meal';
      case ProtocolTimeOfDay.bedtime:
        return 'bedtime';
    }
  }
}

class SupplementProtocolEntity {
  final String id;
  final String profileId;
  final String supplementId;
  final String supplementName;
  final ProtocolTimeOfDay timeOfDay;
  final double dosage;
  final String unit;
  final String? linkedGoalId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplementProtocolEntity({
    required this.id,
    required this.profileId,
    required this.supplementId,
    required this.supplementName,
    required this.timeOfDay,
    required this.dosage,
    required this.unit,
    this.linkedGoalId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplementProtocolEntity.fromJson(Map<String, dynamic> json) {
    return SupplementProtocolEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      supplementId: json['supplement_id'] as String,
      supplementName: json['supplement_name'] as String,
      timeOfDay: ProtocolTimeOfDay.fromString(json['time_of_day'] as String),
      dosage: (json['dosage'] as num).toDouble(),
      unit: json['unit'] as String,
      linkedGoalId: json['linked_goal_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'supplement_id': supplementId,
      'supplement_name': supplementName,
      'time_of_day': timeOfDay.toJson(),
      'dosage': dosage,
      'unit': unit,
      'linked_goal_id': linkedGoalId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SupplementProtocolEntity copyWith({
    String? id,
    String? profileId,
    String? supplementId,
    String? supplementName,
    ProtocolTimeOfDay? timeOfDay,
    double? dosage,
    String? unit,
    String? linkedGoalId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplementProtocolEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      supplementId: supplementId ?? this.supplementId,
      supplementName: supplementName ?? this.supplementName,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
