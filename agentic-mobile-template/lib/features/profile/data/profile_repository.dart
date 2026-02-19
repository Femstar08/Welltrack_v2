import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/profile/data/profile_model.dart';
import 'package:welltrack/features/profile/domain/profile_entity.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<ProfileEntity> getProfile(String profileId) async {
    try {
      final response = await _client
          .from('wt_profiles')
          .select()
          .eq('id', profileId)
          .single();

      return ProfileModel.fromJson(response).toEntity();
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<ProfileEntity?> getActiveProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      // Get the oldest primary profile (handles duplicates gracefully)
      final response = await _client
          .from('wt_profiles')
          .select()
          .eq('user_id', userId)
          .order('is_primary', ascending: false)
          .order('created_at')
          .limit(1);

      if (response.isEmpty) return null;

      return ProfileModel.fromJson(response.first).toEntity();
    } catch (e) {
      throw Exception('Failed to fetch active profile: $e');
    }
  }

  Future<List<ProfileEntity>> getUserProfiles(String userId) async {
    try {
      final response = await _client
          .from('wt_profiles')
          .select()
          .eq('user_id', userId)
          .order('is_primary', ascending: false)
          .order('created_at');

      return (response as List)
          .map((json) => ProfileModel.fromJson(json).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user profiles: $e');
    }
  }

  Future<ProfileEntity> updateProfile(
    String profileId,
    Map<String, dynamic> fields,
  ) async {
    try {
      // Add updated_at timestamp
      final updateData = {
        ...fields,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('wt_profiles')
          .update(updateData)
          .eq('id', profileId)
          .select()
          .single();

      return ProfileModel.fromJson(response).toEntity();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<ProfileEntity> createProfile({
    required String userId,
    required String profileType,
    required String displayName,
    DateTime? dateOfBirth,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? fitnessGoals,
    String? dietaryRestrictions,
    String? allergies,
    String? primaryGoal,
    String? goalIntensity,
    bool isPrimary = true,
  }) async {
    try {
      final now = DateTime.now();
      final profileData = {
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
        'primary_goal': primaryGoal,
        'goal_intensity': goalIntensity,
        'is_primary': isPrimary,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _client
          .from('wt_profiles')
          .insert(profileData)
          .select()
          .single();

      return ProfileModel.fromJson(response).toEntity();
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  Future<void> ensureUserExists(String userId, {String? displayName}) async {
    await _client.from('wt_users').upsert({
      'id': userId,
      'display_name': displayName,
      'onboarding_completed': false,
    }, onConflict: 'id');
  }

  Future<void> markOnboardingComplete(String userId) async {
    try {
      await _client
          .from('wt_users')
          .update({'onboarding_completed': true})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to mark onboarding complete: $e');
    }
  }
}
