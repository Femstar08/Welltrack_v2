import '../domain/profile_entity.dart';

class ProfileModel {

  const ProfileModel({
    required this.id,
    required this.userId,
    required this.profileType,
    required this.displayName,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.fitnessGoals,
    this.dietaryRestrictions,
    this.allergies,
    this.preferredIngredients = const [],
    this.excludedIngredients = const [],
    this.primaryGoal,
    this.goalIntensity,
    this.isPrimary = true,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      profileType: json['profile_type'] as String,
      displayName: json['display_name'] as String,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      heightCm: json['height_cm'] != null
          ? (json['height_cm'] as num).toDouble()
          : null,
      weightKg: json['weight_kg'] != null
          ? (json['weight_kg'] as num).toDouble()
          : null,
      activityLevel: json['activity_level'] as String?,
      fitnessGoals: json['fitness_goals'] as String?,
      dietaryRestrictions: json['dietary_restrictions'] as String?,
      allergies: json['allergies'] as String?,
      preferredIngredients: (json['preferred_ingredients'] as List<dynamic>?)?.cast<String>() ?? [],
      excludedIngredients: (json['excluded_ingredients'] as List<dynamic>?)?.cast<String>() ?? [],
      primaryGoal: json['primary_goal'] as String?,
      goalIntensity: json['goal_intensity'] as String?,
      isPrimary: json['is_primary'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory ProfileModel.fromEntity(ProfileEntity entity) {
    return ProfileModel(
      id: entity.id,
      userId: entity.userId,
      profileType: entity.profileType,
      displayName: entity.displayName,
      dateOfBirth: entity.dateOfBirth,
      gender: entity.gender,
      heightCm: entity.heightCm,
      weightKg: entity.weightKg,
      activityLevel: entity.activityLevel,
      fitnessGoals: entity.fitnessGoals,
      dietaryRestrictions: entity.dietaryRestrictions,
      allergies: entity.allergies,
      preferredIngredients: entity.preferredIngredients,
      excludedIngredients: entity.excludedIngredients,
      primaryGoal: entity.primaryGoal,
      goalIntensity: entity.goalIntensity,
      isPrimary: entity.isPrimary,
      avatarUrl: entity.avatarUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
  final String id;
  final String userId;
  final String profileType;
  final String displayName;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final String? fitnessGoals;
  final String? dietaryRestrictions;
  final String? allergies;
  final List<String> preferredIngredients;
  final List<String> excludedIngredients;
  final String? primaryGoal;
  final String? goalIntensity;
  final bool isPrimary;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'profile_type': profileType,
      'display_name': displayName,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'activity_level': activityLevel,
      'fitness_goals': fitnessGoals,
      'dietary_restrictions': dietaryRestrictions,
      'allergies': allergies,
      'preferred_ingredients': preferredIngredients,
      'excluded_ingredients': excludedIngredients,
      'primary_goal': primaryGoal,
      'goal_intensity': goalIntensity,
      'is_primary': isPrimary,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      userId: userId,
      profileType: profileType,
      displayName: displayName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      fitnessGoals: fitnessGoals,
      dietaryRestrictions: dietaryRestrictions,
      allergies: allergies,
      preferredIngredients: preferredIngredients,
      excludedIngredients: excludedIngredients,
      primaryGoal: primaryGoal,
      goalIntensity: goalIntensity,
      isPrimary: isPrimary,
      avatarUrl: avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
