// lib/features/daily_coach/data/daily_prescription_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/daily_prescription_entity.dart';

final dailyPrescriptionRepositoryProvider =
    Provider<DailyPrescriptionRepository>((ref) {
  return DailyPrescriptionRepository(Supabase.instance.client);
});

class DailyPrescriptionRepository {
  DailyPrescriptionRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _table = 'wt_daily_prescriptions';

  /// Returns today's prescription or null if not yet generated.
  Future<DailyPrescriptionEntity?> getTodayPrescription(
    String profileId,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return getPrescriptionForDate(profileId, DateTime.parse(today));
  }

  /// Returns prescription for a specific date, or null if not found.
  Future<DailyPrescriptionEntity?> getPrescriptionForDate(
    String profileId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .eq('prescription_date', dateStr)
          .maybeSingle();

      if (response == null) return null;
      return DailyPrescriptionEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch prescription for $date: $e');
    }
  }

  /// Upserts a prescription (one per day per profile).
  Future<DailyPrescriptionEntity> upsertPrescription(
    DailyPrescriptionEntity prescription,
  ) async {
    try {
      final response = await _supabase
          .from(_table)
          .upsert(
            prescription.toJson(),
            onConflict: 'profile_id,prescription_date',
          )
          .select()
          .single();

      return DailyPrescriptionEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to upsert prescription: $e');
    }
  }

  /// Merges AI-generated narrative fields into an existing prescription row.
  Future<DailyPrescriptionEntity> updateAiNarrative({
    required String prescriptionId,
    String? focusTip,
    String? narrative,
    String? model,
  }) async {
    try {
      final response = await _supabase
          .from(_table)
          .update({
            if (focusTip != null) 'ai_focus_tip': focusTip,
            if (narrative != null) 'ai_narrative': narrative,
            if (model != null) 'ai_model': model,
            'is_fallback': false,
          })
          .eq('id', prescriptionId)
          .select()
          .single();

      return DailyPrescriptionEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update AI narrative: $e');
    }
  }

  /// Returns last [limit] prescriptions for trend analysis.
  Future<List<DailyPrescriptionEntity>> getRecentPrescriptions(
    String profileId, {
    int limit = 14,
  }) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .order('prescription_date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) =>
              DailyPrescriptionEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent prescriptions: $e');
    }
  }
}
