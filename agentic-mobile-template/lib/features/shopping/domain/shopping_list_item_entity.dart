class ShoppingListItemEntity {

  const ShoppingListItemEntity({
    required this.id,
    required this.shoppingListId,
    required this.ingredientName,
    this.quantity,
    this.unit,
    this.aisle = 'Other',
    this.isChecked = false,
    this.notes,
    this.sourceRecipeId,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory ShoppingListItemEntity.fromJson(Map<String, dynamic> json) {
    return ShoppingListItemEntity(
      id: json['id'] as String,
      shoppingListId: json['shopping_list_id'] as String,
      ingredientName: json['ingredient_name'] as String,
      quantity: json['quantity'] != null
          ? (json['quantity'] as num).toDouble()
          : null,
      unit: json['unit'] as String?,
      aisle: json['aisle'] as String? ?? 'Other',
      isChecked: json['is_checked'] as bool? ?? false,
      notes: json['notes'] as String?,
      sourceRecipeId: json['source_recipe_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String shoppingListId;
  final String ingredientName;
  final double? quantity;
  final String? unit;
  final String aisle;
  final bool isChecked;
  final String? notes;
  final String? sourceRecipeId;
  final int sortOrder;
  final DateTime createdAt;

  ShoppingListItemEntity copyWith({
    String? shoppingListId,
    String? ingredientName,
    double? quantity,
    String? unit,
    String? aisle,
    bool? isChecked,
    String? notes,
    String? sourceRecipeId,
    int? sortOrder,
  }) {
    return ShoppingListItemEntity(
      id: id,
      shoppingListId: shoppingListId ?? this.shoppingListId,
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      aisle: aisle ?? this.aisle,
      isChecked: isChecked ?? this.isChecked,
      notes: notes ?? this.notes,
      sourceRecipeId: sourceRecipeId ?? this.sourceRecipeId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopping_list_id': shoppingListId,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'aisle': aisle,
      'is_checked': isChecked,
      'notes': notes,
      'source_recipe_id': sourceRecipeId,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayText {
    final parts = <String>[];
    if (quantity != null) {
      // Format as integer if it's a whole number
      if (quantity == quantity!.roundToDouble() && quantity!.truncate() == quantity) {
        parts.add(quantity!.truncate().toString());
      } else {
        parts.add(quantity.toString());
      }
    }
    if (unit != null) {
      parts.add(unit!);
    }
    parts.add(ingredientName);
    return parts.join(' ');
  }
}
