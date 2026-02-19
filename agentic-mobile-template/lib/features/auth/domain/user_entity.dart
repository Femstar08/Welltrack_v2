/// Domain entity representing a WellTrack user
/// This is the core user model used across the app
class UserEntity { // 'free' or 'pro'

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.onboardingCompleted = false,
    this.planTier = 'free',
  });
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final bool onboardingCompleted;
  final String planTier;

  /// Create a copy of this user with updated fields
  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? onboardingCompleted,
    String? planTier,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      planTier: planTier ?? this.planTier,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl &&
          onboardingCompleted == other.onboardingCompleted &&
          planTier == other.planTier;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      avatarUrl.hashCode ^
      onboardingCompleted.hashCode ^
      planTier.hashCode;

  @override
  String toString() {
    return 'UserEntity{id: $id, email: $email, displayName: $displayName, planTier: $planTier}';
  }
}
