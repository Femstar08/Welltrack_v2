// lib/features/workouts/domain/exercise_entity.dart

class ExerciseEntity {
  const ExerciseEntity({
    required this.id,
    required this.name,
    this.muscleGroup,
    required this.muscleGroups,
    required this.secondaryMuscles,
    this.equipmentType,
    this.category,
    this.instructions,
    this.difficulty,
    this.imageUrl,
    this.gifUrl,
    required this.isCustom,
    this.profileId,
  });

  factory ExerciseEntity.fromJson(Map<String, dynamic> json) {
    return ExerciseEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscle_group'] as String?,
      muscleGroups:
          (json['muscle_groups'] as List?)?.cast<String>() ?? [],
      secondaryMuscles:
          (json['secondary_muscles'] as List?)?.cast<String>() ?? [],
      equipmentType: json['equipment_type'] as String?,
      category: json['category'] as String?,
      instructions: json['instructions'] as String?,
      difficulty: json['difficulty'] as String?,
      imageUrl: json['image_url'] as String?,
      gifUrl: json['gif_url'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
      profileId: json['profile_id'] as String?,
    );
  }

  final String id;
  final String name;

  /// Legacy single muscle group value. Prefer [muscleGroups] for new code.
  final String? muscleGroup;
  final List<String> muscleGroups;
  final List<String> secondaryMuscles;
  final String? equipmentType;
  final String? category;
  final String? instructions;
  final String? difficulty;
  final String? imageUrl;
  final String? gifUrl;
  final bool isCustom;
  final String? profileId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscle_group': muscleGroup,
      'muscle_groups': muscleGroups,
      'secondary_muscles': secondaryMuscles,
      'equipment_type': equipmentType,
      'category': category,
      'instructions': instructions,
      'difficulty': difficulty,
      'image_url': imageUrl,
      'gif_url': gifUrl,
      'is_custom': isCustom,
      'profile_id': profileId,
    };
  }

  ExerciseEntity copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    List<String>? muscleGroups,
    List<String>? secondaryMuscles,
    String? equipmentType,
    String? category,
    String? instructions,
    String? difficulty,
    String? imageUrl,
    String? gifUrl,
    bool? isCustom,
    String? profileId,
  }) {
    return ExerciseEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipmentType: equipmentType ?? this.equipmentType,
      category: category ?? this.category,
      instructions: instructions ?? this.instructions,
      difficulty: difficulty ?? this.difficulty,
      imageUrl: imageUrl ?? this.imageUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      isCustom: isCustom ?? this.isCustom,
      profileId: profileId ?? this.profileId,
    );
  }
}
