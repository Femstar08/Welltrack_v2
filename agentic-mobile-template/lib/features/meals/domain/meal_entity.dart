class MealEntity {

  const MealEntity({
    required this.id,
    required this.profileId,
    this.recipeId,
    required this.mealDate,
    required this.mealType,
    required this.name,
    this.servingsConsumed = 1.0,
    this.nutritionInfo,
    this.score,
    this.rating,
    this.notes,
    this.photoUrl,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealEntity.fromJson(Map<String, dynamic> json) {
    return MealEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      recipeId: json['recipe_id'] as String?,
      mealDate: DateTime.parse(json['meal_date'] as String),
      mealType: json['meal_type'] as String,
      name: json['name'] as String,
      servingsConsumed: json['servings_consumed'] != null
          ? (json['servings_consumed'] as num).toDouble()
          : 1.0,
      nutritionInfo: json['nutrition_info'] as Map<String, dynamic>?,
      score: json['score'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      notes: json['notes'] as String?,
      photoUrl: json['photo_url'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  final String id;
  final String profileId;
  final String? recipeId;
  final DateTime mealDate;
  final String mealType; // 'breakfast', 'lunch', 'dinner', 'snack'
  final String name;
  final double servingsConsumed;
  final Map<String, dynamic>? nutritionInfo;
  final String? score; // A-D or null
  final double? rating; // 1-5 stars
  final String? notes;
  final String? photoUrl;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealEntity copyWith({
    String? recipeId,
    DateTime? mealDate,
    String? mealType,
    String? name,
    double? servingsConsumed,
    Map<String, dynamic>? nutritionInfo,
    String? score,
    double? rating,
    String? notes,
    String? photoUrl,
    bool? isFavorite,
  }) {
    return MealEntity(
      id: id,
      profileId: profileId,
      recipeId: recipeId ?? this.recipeId,
      mealDate: mealDate ?? this.mealDate,
      mealType: mealType ?? this.mealType,
      name: name ?? this.name,
      servingsConsumed: servingsConsumed ?? this.servingsConsumed,
      nutritionInfo: nutritionInfo ?? this.nutritionInfo,
      score: score ?? this.score,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'recipe_id': recipeId,
      'meal_date': mealDate.toIso8601String(),
      'meal_type': mealType,
      'name': name,
      'servings_consumed': servingsConsumed,
      'nutrition_info': nutritionInfo,
      'score': score,
      'rating': rating,
      'notes': notes,
      'photo_url': photoUrl,
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get mealTypeDisplayName {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return mealType;
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mealDay = DateTime(mealDate.year, mealDate.month, mealDate.day);

    if (mealDay == today) {
      return 'Today';
    } else if (mealDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${mealDate.day}/${mealDate.month}/${mealDate.year}';
    }
  }
}
