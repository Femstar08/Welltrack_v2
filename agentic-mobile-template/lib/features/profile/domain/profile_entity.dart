class ProfileEntity {

  const ProfileEntity({
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
  final String id;
  final String userId;
  final String profileType; // 'parent' or 'dependent'
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

  ProfileEntity copyWith({
    String? displayName,
    DateTime? dateOfBirth,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? fitnessGoals,
    String? dietaryRestrictions,
    String? allergies,
    List<String>? preferredIngredients,
    List<String>? excludedIngredients,
    String? primaryGoal,
    String? goalIntensity,
    String? avatarUrl,
  }) {
    return ProfileEntity(
      id: id,
      userId: userId,
      profileType: profileType,
      displayName: displayName ?? this.displayName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      allergies: allergies ?? this.allergies,
      preferredIngredients: preferredIngredients ?? this.preferredIngredients,
      excludedIngredients: excludedIngredients ?? this.excludedIngredients,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      goalIntensity: goalIntensity ?? this.goalIntensity,
      isPrimary: isPrimary,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
