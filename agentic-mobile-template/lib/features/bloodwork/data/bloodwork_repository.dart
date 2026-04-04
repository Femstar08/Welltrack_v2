// lib/features/bloodwork/data/bloodwork_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/bloodwork_entity.dart';

final bloodworkRepositoryProvider = Provider<BloodworkRepository>((ref) {
  return BloodworkRepository(Supabase.instance.client);
});

/// Data-access layer for [wt_bloodwork_results].
///
/// All methods throw a descriptive [Exception] on Supabase errors so that
/// the provider layer can catch them and surface a user-facing error message.
class BloodworkRepository {
  BloodworkRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _table = 'wt_bloodwork_results';

  // ─── Read ────────────────────────────────────────────────────────────────

  /// Returns all results for [profileId] ordered by test date descending.
  Future<List<BloodworkEntity>> getResults(String profileId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .order('test_date', ascending: false);

      return (response as List)
          .map((json) => BloodworkEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bloodwork results: $e');
    }
  }

  /// Returns all results for a specific [testName] ordered by test date
  /// ascending — useful for building a trend chart.
  Future<List<BloodworkEntity>> getResultsByTest(
    String profileId,
    String testName,
  ) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .eq('test_name', testName)
          .order('test_date', ascending: true);

      return (response as List)
          .map((json) => BloodworkEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch results for $testName: $e');
    }
  }

  /// Returns the single most recent result per distinct test name.
  ///
  /// The deduplication is done client-side after fetching all results ordered
  /// by date descending — Supabase does not expose DISTINCT ON via the REST
  /// API.  Result count is bounded by the number of distinct test types so
  /// memory usage is negligible.
  Future<List<BloodworkEntity>> getLatestResults(String profileId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .order('test_date', ascending: false);

      final all = (response as List)
          .map((json) => BloodworkEntity.fromJson(json as Map<String, dynamic>))
          .toList();

      // Keep only the first (most recent) entry per test name.
      final seen = <String>{};
      final latest = <BloodworkEntity>[];
      for (final entity in all) {
        if (seen.add(entity.testName)) {
          latest.add(entity);
        }
      }
      return latest;
    } catch (e) {
      throw Exception('Failed to fetch latest bloodwork results: $e');
    }
  }

  /// Returns all results where the computed [is_out_of_range] flag is true.
  Future<List<BloodworkEntity>> getOutOfRangeResults(String profileId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('profile_id', profileId)
          .eq('is_out_of_range', true)
          .order('test_date', ascending: false);

      return (response as List)
          .map((json) => BloodworkEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch out-of-range results: $e');
    }
  }

  // ─── Write ───────────────────────────────────────────────────────────────

  /// Inserts a new bloodwork result.  Returns the persisted entity including
  /// the server-assigned UUID and the computed [isOutOfRange] value.
  Future<BloodworkEntity> addResult(BloodworkEntity entity) async {
    try {
      final response = await _supabase
          .from(_table)
          .insert(entity.toJson())
          .select()
          .single();

      return BloodworkEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add bloodwork result: $e');
    }
  }

  /// Updates an existing bloodwork result.  [entity.id] must be non-null.
  Future<BloodworkEntity> updateResult(BloodworkEntity entity) async {
    assert(entity.id != null, 'Cannot update an entity without an id');
    try {
      final payload = entity.toJson()
        ..['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from(_table)
          .update(payload)
          .eq('id', entity.id!)
          .select()
          .single();

      return BloodworkEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update bloodwork result: $e');
    }
  }

  /// Deletes the result with the given [id].
  Future<void> deleteResult(String id) async {
    try {
      await _supabase.from(_table).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete bloodwork result: $e');
    }
  }
}
