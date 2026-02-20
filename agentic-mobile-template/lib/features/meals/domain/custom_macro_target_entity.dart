import '../data/macro_calculator.dart';

class CustomMacroTargetEntity {
  const CustomMacroTargetEntity({
    this.id,
    required this.profileId,
    required this.dayType,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomMacroTargetEntity.fromJson(Map<String, dynamic> json) {
    return CustomMacroTargetEntity(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String,
      dayType: json['day_type'] as String,
      calories: json['calories'] as int,
      proteinG: json['protein_g'] as int,
      carbsG: json['carbs_g'] as int,
      fatG: json['fat_g'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  final String? id;
  final String profileId;
  final String dayType;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'profile_id': profileId,
        'day_type': dayType,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'is_active': isActive,
      };

  MacroTargets toMacroTargets() => MacroTargets(
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
      );
}
