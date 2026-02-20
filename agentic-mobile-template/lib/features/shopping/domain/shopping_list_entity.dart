import 'shopping_list_item_entity.dart';

class ShoppingListEntity {

  const ShoppingListEntity({
    required this.id,
    required this.profileId,
    required this.name,
    this.recipeIds = const [],
    this.status = 'active',
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingListEntity.fromJson(Map<String, dynamic> json) {
    return ShoppingListEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      name: json['name'] as String,
      recipeIds: json['recipe_ids'] != null
          ? List<String>.from(json['recipe_ids'] as List)
          : [],
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      items: [], // Loaded separately via join or second query
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String profileId;
  final String name;
  final List<String> recipeIds;
  final String status; // 'active', 'completed', 'archived'
  final String? notes;
  final List<ShoppingListItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingListEntity copyWith({
    String? name,
    List<String>? recipeIds,
    String? status,
    String? notes,
    List<ShoppingListItemEntity>? items,
  }) {
    return ShoppingListEntity(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      recipeIds: recipeIds ?? this.recipeIds,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      'recipe_ids': recipeIds,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get checkedCount => items.where((i) => i.isChecked).length;

  int get totalCount => items.length;

  double get progressPercent =>
      totalCount == 0 ? 0 : checkedCount / totalCount;

  bool get isComplete => totalCount > 0 && checkedCount == totalCount;

  Map<String, List<ShoppingListItemEntity>> get itemsByAisle {
    final grouped = <String, List<ShoppingListItemEntity>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.aisle, () => []).add(item);
    }
    // Sort keys by aisle order, then sort items within each aisle by sortOrder
    final sorted = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    for (final entry in sorted.entries) {
      entry.value.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return sorted;
  }
}
