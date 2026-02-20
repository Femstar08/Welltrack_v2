import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/custom_macro_target_entity.dart';

final customMacroTargetRepositoryProvider =
    Provider<CustomMacroTargetRepository>((ref) {
  return CustomMacroTargetRepository(Supabase.instance.client);
});

class CustomMacroTargetRepository {
  CustomMacroTargetRepository(this._client);
  final SupabaseClient _client;

  Future<List<CustomMacroTargetEntity>> getTargets(String profileId) async {
    try {
      final response = await _client
          .from('wt_custom_macro_targets')
          .select()
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .order('day_type');

      return (response as List)
          .map((json) =>
              CustomMacroTargetEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch custom targets: $e');
    }
  }

  Future<CustomMacroTargetEntity?> getTarget(
      String profileId, String dayType) async {
    try {
      final response = await _client
          .from('wt_custom_macro_targets')
          .select()
          .eq('profile_id', profileId)
          .eq('day_type', dayType)
          .eq('is_active', true)
          .limit(1);

      final list = response as List;
      if (list.isEmpty) return null;
      return CustomMacroTargetEntity.fromJson(
          list.first as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch custom target: $e');
    }
  }

  Future<CustomMacroTargetEntity> saveTarget(
      CustomMacroTargetEntity entity) async {
    try {
      final data = entity.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('wt_custom_macro_targets')
          .upsert(data, onConflict: 'profile_id,day_type')
          .select()
          .single();

      return CustomMacroTargetEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to save custom target: $e');
    }
  }

  Future<void> deleteTarget(String profileId, String dayType) async {
    try {
      await _client
          .from('wt_custom_macro_targets')
          .delete()
          .eq('profile_id', profileId)
          .eq('day_type', dayType);
    } catch (e) {
      throw Exception('Failed to delete custom target: $e');
    }
  }
}
