class PantryItemEntity {
  final String id;
  final String profileId;
  final String name;
  final String category; // 'fridge', 'cupboard', 'freezer'
  final double? quantity;
  final String? unit;
  final DateTime? expiryDate;
  final bool isAvailable;
  final String? barcode;
  final double? cost;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PantryItemEntity({
    required this.id,
    required this.profileId,
    required this.name,
    required this.category,
    this.quantity,
    this.unit,
    this.expiryDate,
    this.isAvailable = true,
    this.barcode,
    this.cost,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  PantryItemEntity copyWith({
    String? name,
    String? category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    bool? isAvailable,
    String? barcode,
    double? cost,
    String? notes,
  }) {
    return PantryItemEntity(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      isAvailable: isAvailable ?? this.isAvailable,
      barcode: barcode ?? this.barcode,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'expiry_date': expiryDate?.toIso8601String(),
      'is_available': isAvailable,
      'barcode': barcode,
      'cost': cost,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PantryItemEntity.fromJson(Map<String, dynamic> json) {
    return PantryItemEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      unit: json['unit'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      isAvailable: json['is_available'] as bool? ?? true,
      barcode: json['barcode'] as String?,
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate!.difference(now).inDays;
    return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  String get displayQuantity {
    if (quantity == null) return '';
    if (unit == null) return quantity.toString();
    return '$quantity $unit';
  }
}
