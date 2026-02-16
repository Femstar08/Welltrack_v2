// lib/features/supplements/domain/supplement_log_entity.dart

import 'package:welltrack/features/supplements/domain/supplement_protocol_entity.dart';

enum SupplementLogStatus {
  taken,
  skipped,
  planned;

  String get label {
    switch (this) {
      case SupplementLogStatus.taken:
        return 'Taken';
      case SupplementLogStatus.skipped:
        return 'Skipped';
      case SupplementLogStatus.planned:
        return 'Planned';
    }
  }

  static SupplementLogStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'taken':
        return SupplementLogStatus.taken;
      case 'skipped':
        return SupplementLogStatus.skipped;
      case 'planned':
        return SupplementLogStatus.planned;
      default:
        return SupplementLogStatus.planned;
    }
  }

  String toJson() {
    switch (this) {
      case SupplementLogStatus.taken:
        return 'taken';
      case SupplementLogStatus.skipped:
        return 'skipped';
      case SupplementLogStatus.planned:
        return 'planned';
    }
  }
}

class SupplementLogEntity {
  final String id;
  final String profileId;
  final String supplementId;
  final String supplementName;
  final DateTime takenAt;
  final ProtocolTimeOfDay protocolTime;
  final double dosageTaken;
  final String unit;
  final SupplementLogStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplementLogEntity({
    required this.id,
    required this.profileId,
    required this.supplementId,
    required this.supplementName,
    required this.takenAt,
    required this.protocolTime,
    required this.dosageTaken,
    required this.unit,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplementLogEntity.fromJson(Map<String, dynamic> json) {
    return SupplementLogEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      supplementId: json['supplement_id'] as String,
      supplementName: json['supplement_name'] as String,
      takenAt: DateTime.parse(json['taken_at'] as String),
      protocolTime: ProtocolTimeOfDay.fromString(json['protocol_time'] as String),
      dosageTaken: (json['dosage_taken'] as num).toDouble(),
      unit: json['unit'] as String,
      status: SupplementLogStatus.fromString(json['status'] as String),
      notes: json['notes'] as String?,
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
      'taken_at': takenAt.toIso8601String(),
      'protocol_time': protocolTime.toJson(),
      'dosage_taken': dosageTaken,
      'unit': unit,
      'status': status.toJson(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SupplementLogEntity copyWith({
    String? id,
    String? profileId,
    String? supplementId,
    String? supplementName,
    DateTime? takenAt,
    ProtocolTimeOfDay? protocolTime,
    double? dosageTaken,
    String? unit,
    SupplementLogStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplementLogEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      supplementId: supplementId ?? this.supplementId,
      supplementName: supplementName ?? this.supplementName,
      takenAt: takenAt ?? this.takenAt,
      protocolTime: protocolTime ?? this.protocolTime,
      dosageTaken: dosageTaken ?? this.dosageTaken,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isTaken => status == SupplementLogStatus.taken;
  bool get isSkipped => status == SupplementLogStatus.skipped;
  bool get isPlanned => status == SupplementLogStatus.planned;
}
