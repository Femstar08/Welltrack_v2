class RecipeIngredient {
  final String id;
  final String ingredientName;
  final double? quantity;
  final String? unit;
  final String? notes;
  final int sortOrder;

  const RecipeIngredient({
    required this.id,
    required this.ingredientName,
    this.quantity,
    this.unit,
    this.notes,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
      'sort_order': sortOrder,
    };
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String,
      ingredientName: json['ingredient_name'] as String,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      unit: json['unit'] as String?,
      notes: json['notes'] as String?,
      sortOrder: json['sort_order'] as int,
    );
  }

  RecipeIngredient copyWith({
    String? ingredientName,
    double? quantity,
    String? unit,
    String? notes,
    int? sortOrder,
  }) {
    return RecipeIngredient(
      id: id,
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  String get displayText {
    final parts = <String>[];
    if (quantity != null) {
      parts.add(quantity.toString());
    }
    if (unit != null) {
      parts.add(unit!);
    }
    parts.add(ingredientName);
    if (notes != null && notes!.isNotEmpty) {
      parts.add('($notes)');
    }
    return parts.join(' ');
  }
}
