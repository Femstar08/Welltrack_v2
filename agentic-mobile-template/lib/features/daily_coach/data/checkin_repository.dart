// lib/features/daily_coach/data/checkin_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/checkin_entity.dart';

final checkinRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository(Supabase.instance.client);
});

class CheckInRepository {
  CheckInRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _table = 'wt_daily_checkins';

  /// Returns today's check-in or null if not yet completed.
  Future<CheckInEntity?> getTodayCheckIn(String profileId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return getCheckInForDate(profileId, DateTime.parse(today));
  }

  /// Returns the check-in for a specific date, or null if none exists.
  Future<CheckInEntity?> getCheckInForDate(
    String profileId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .eq('checkin_date', dateStr)
          .maybeSingle();

      if (response == null) return null;
      return CheckInEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch check-in for $date: $e');
    }
  }

  /// Returns last [limit] check-ins ordered by date descending.
  Future<List<CheckInEntity>> getRecentCheckIns(
    String profileId, {
    int limit = 7,
  }) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .order('checkin_date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CheckInEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent check-ins: $e');
    }
  }

  /// Upserts today's check-in (handles re-submission gracefully via
  /// UNIQUE constraint on profile_id + checkin_date).
  Future<CheckInEntity> upsertCheckIn(CheckInEntity checkIn) async {
    try {
      final response = await _supabase
          .from(_table)
          .upsert(
            checkIn.toJson(),
            onConflict: 'profile_id,checkin_date',
          )
          .select()
          .single();

      return CheckInEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to upsert check-in: $e');
    }
  }

  /// Returns Sunday weekly check-in entries for streak tracking.
  Future<List<CheckInEntity>> getWeeklyCheckIns(
    String profileId, {
    int limit = 4,
  }) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .eq('is_weekly', true)
          .order('checkin_date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CheckInEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch weekly check-ins: $e');
    }
  }
}
