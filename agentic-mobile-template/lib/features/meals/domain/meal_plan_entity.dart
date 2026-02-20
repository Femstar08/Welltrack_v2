class MealPlanItemEntity {
  const MealPlanItemEntity({
    required this.id,
    required this.mealPlanId,
    required this.mealType,
    required this.name,
    this.description,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.recipeId,
    this.sortOrder = 0,
    this.isLogged = false,
    this.swapCount = 0,
    required this.createdAt,
  });

  factory MealPlanItemEntity.fromJson(Map<String, dynamic> json) {
    return MealPlanItemEntity(
      id: json['id'] as String,
      mealPlanId: json['meal_plan_id'] as String,
      mealType: json['meal_type'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      calories: json['calories'] as int?,
      proteinG: json['protein_g'] as int?,
      carbsG: json['carbs_g'] as int?,
      fatG: json['fat_g'] as int?,
      recipeId: json['recipe_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isLogged: json['is_logged'] as bool? ?? false,
      swapCount: json['swap_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String mealPlanId;
  final String mealType; // 'breakfast', 'lunch', 'dinner', 'snack'
  final String name;
  final String? description;
  final int? calories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final String? recipeId;
  final int sortOrder;
  final bool isLogged;
  final int swapCount;
  final DateTime createdAt;

  MealPlanItemEntity copyWith({
    String? mealType,
    String? name,
    String? description,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    String? recipeId,
    int? sortOrder,
    bool? isLogged,
    int? swapCount,
  }) {
    return MealPlanItemEntity(
      id: id,
      mealPlanId: mealPlanId,
      mealType: mealType ?? this.mealType,
      name: name ?? this.name,
      description: description ?? this.description,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      recipeId: recipeId ?? this.recipeId,
      sortOrder: sortOrder ?? this.sortOrder,
      isLogged: isLogged ?? this.isLogged,
      swapCount: swapCount ?? this.swapCount,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meal_plan_id': mealPlanId,
      'meal_type': mealType,
      'name': name,
      'description': description,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'recipe_id': recipeId,
      'sort_order': sortOrder,
      'is_logged': isLogged,
      'swap_count': swapCount,
      'created_at': createdAt.toIso8601String(),
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
}

class MealPlanEntity {
  const MealPlanEntity({
    required this.id,
    required this.profileId,
    required this.planDate,
    this.dayType = 'rest',
    this.totalCalories,
    this.totalProteinG,
    this.totalCarbsG,
    this.totalFatG,
    this.status = 'active',
    this.aiRationale,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealPlanEntity.fromJson(Map<String, dynamic> json) {
    final itemsList = json['wt_meal_plan_items'] as List?;
    return MealPlanEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      planDate: DateTime.parse(json['plan_date'] as String),
      dayType: json['day_type'] as String? ?? 'rest',
      totalCalories: json['total_calories'] as int?,
      totalProteinG: json['total_protein_g'] as int?,
      totalCarbsG: json['total_carbs_g'] as int?,
      totalFatG: json['total_fat_g'] as int?,
      status: json['status'] as String? ?? 'active',
      aiRationale: json['ai_rationale'] as String?,
      items: itemsList
              ?.map((item) =>
                  MealPlanItemEntity.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String profileId;
  final DateTime planDate;
  final String dayType; // 'strength', 'cardio', 'rest'
  final int? totalCalories;
  final int? totalProteinG;
  final int? totalCarbsG;
  final int? totalFatG;
  final String status; // 'active', 'completed', 'skipped'
  final String? aiRationale;
  final List<MealPlanItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPlanEntity copyWith({
    DateTime? planDate,
    String? dayType,
    int? totalCalories,
    int? totalProteinG,
    int? totalCarbsG,
    int? totalFatG,
    String? status,
    String? aiRationale,
    List<MealPlanItemEntity>? items,
  }) {
    return MealPlanEntity(
      id: id,
      profileId: profileId,
      planDate: planDate ?? this.planDate,
      dayType: dayType ?? this.dayType,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalFatG: totalFatG ?? this.totalFatG,
      status: status ?? this.status,
      aiRationale: aiRationale ?? this.aiRationale,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'plan_date': '${planDate.year}-${planDate.month.toString().padLeft(2, '0')}-${planDate.day.toString().padLeft(2, '0')}',
      'day_type': dayType,
      'total_calories': totalCalories,
      'total_protein_g': totalProteinG,
      'total_carbs_g': totalCarbsG,
      'total_fat_g': totalFatG,
      'status': status,
      'ai_rationale': aiRationale,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get totalCaloriesActual =>
      items.fold(0, (sum, item) => sum + (item.calories ?? 0));

  int get totalProteinActual =>
      items.fold(0, (sum, item) => sum + (item.proteinG ?? 0));

  int get totalCarbsActual =>
      items.fold(0, (sum, item) => sum + (item.carbsG ?? 0));

  int get totalFatActual =>
      items.fold(0, (sum, item) => sum + (item.fatG ?? 0));

  int get loggedCount => items.where((i) => i.isLogged).length;

  double get completionPercent {
    if (items.isEmpty) return 0.0;
    return (loggedCount / items.length) * 100;
  }

  List<MealPlanItemEntity> mealsForType(String type) =>
      items.where((i) => i.mealType == type).toList();

  String get dayTypeDisplayName {
    switch (dayType) {
      case 'strength':
        return 'Strength Day';
      case 'cardio':
        return 'Cardio Day';
      case 'rest':
        return 'Rest Day';
      default:
        return dayType;
    }
  }
}
