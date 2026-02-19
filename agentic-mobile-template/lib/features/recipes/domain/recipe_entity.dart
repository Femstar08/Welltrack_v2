import 'recipe_ingredient.dart';
import 'recipe_step.dart';

class RecipeEntity {

  const RecipeEntity({
    required this.id,
    required this.profileId,
    required this.title,
    this.description,
    required this.servings,
    this.prepTimeMin,
    this.cookTimeMin,
    required this.sourceType,
    this.sourceUrl,
    this.nutritionScore,
    this.tags = const [],
    this.imageUrl,
    this.rating,
    this.isFavorite = false,
    this.isPublic = false,
    this.steps = const [],
    this.ingredients = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecipeEntity.fromJson(Map<String, dynamic> json) {
    return RecipeEntity(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      servings: json['servings'] as int,
      prepTimeMin: json['prep_time_min'] as int?,
      cookTimeMin: json['cook_time_min'] as int?,
      sourceType: json['source_type'] as String,
      sourceUrl: json['source_url'] as String?,
      nutritionScore: json['nutrition_score'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
      imageUrl: json['image_url'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      isFavorite: json['is_favorite'] as bool? ?? false,
      isPublic: json['is_public'] as bool? ?? false,
      steps: [], // Loaded separately
      ingredients: [], // Loaded separately
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  final String id;
  final String profileId;
  final String title;
  final String? description;
  final int servings;
  final int? prepTimeMin;
  final int? cookTimeMin;
  final String sourceType; // 'url', 'ocr', 'ai', 'manual'
  final String? sourceUrl;
  final String? nutritionScore; // 'A', 'B', 'C', 'D'
  final List<String> tags;
  final String? imageUrl;
  final double? rating;
  final bool isFavorite;
  final bool isPublic;
  final List<RecipeStep> steps;
  final List<RecipeIngredient> ingredients;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeEntity copyWith({
    String? title,
    String? description,
    int? servings,
    int? prepTimeMin,
    int? cookTimeMin,
    String? sourceType,
    String? sourceUrl,
    String? nutritionScore,
    List<String>? tags,
    String? imageUrl,
    double? rating,
    bool? isFavorite,
    bool? isPublic,
    List<RecipeStep>? steps,
    List<RecipeIngredient>? ingredients,
  }) {
    return RecipeEntity(
      id: id,
      profileId: profileId,
      title: title ?? this.title,
      description: description ?? this.description,
      servings: servings ?? this.servings,
      prepTimeMin: prepTimeMin ?? this.prepTimeMin,
      cookTimeMin: cookTimeMin ?? this.cookTimeMin,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      nutritionScore: nutritionScore ?? this.nutritionScore,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      isPublic: isPublic ?? this.isPublic,
      steps: steps ?? this.steps,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'title': title,
      'description': description,
      'servings': servings,
      'prep_time_min': prepTimeMin,
      'cook_time_min': cookTimeMin,
      'source_type': sourceType,
      'source_url': sourceUrl,
      'nutrition_score': nutritionScore,
      'tags': tags,
      'image_url': imageUrl,
      'rating': rating,
      'is_favorite': isFavorite,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int? get totalTimeMin {
    if (prepTimeMin == null && cookTimeMin == null) return null;
    return (prepTimeMin ?? 0) + (cookTimeMin ?? 0);
  }

  String get difficultyLevel {
    if (steps.isEmpty) return 'Unknown';
    if (steps.length <= 3) return 'Easy';
    if (steps.length <= 6) return 'Medium';
    return 'Hard';
  }

  String get displayTime {
    final total = totalTimeMin;
    if (total == null) return 'Time not specified';
    if (total < 60) return '$total min';
    final hours = total ~/ 60;
    final mins = total % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }
}
