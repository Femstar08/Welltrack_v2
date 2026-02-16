// lib/features/supplements/domain/supplement_entity.dart

class SupplementEntity {
  final String id;
  final String profileId;
  final String name;
  final String? brand;
  final String? description;
  final double dosage;
  final String unit;
  final double? servingSize;
  final String? barcode;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplementEntity({
    required this.id,
    required this.profileId,
    required this.name,
    this.brand,
    this.description,
    required this.dosage,
    required this.unit,
    this.servingSize,
    this.barcode,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplementEntity.fromJson(Map<String, dynamic> json) {
    return SupplementEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      dosage: (json['dosage'] as num).toDouble(),
      unit: json['unit'] as String,
      servingSize: json['serving_size'] != null
          ? (json['serving_size'] as num).toDouble()
          : null,
      barcode: json['barcode'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      'brand': brand,
      'description': description,
      'dosage': dosage,
      'unit': unit,
      'serving_size': servingSize,
      'barcode': barcode,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SupplementEntity copyWith({
    String? id,
    String? profileId,
    String? name,
    String? brand,
    String? description,
    double? dosage,
    String? unit,
    double? servingSize,
    String? barcode,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplementEntity(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      servingSize: servingSize ?? this.servingSize,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
