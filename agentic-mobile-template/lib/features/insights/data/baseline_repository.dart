import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/baseline_entity.dart';

/// Baseline Repository
/// Manages 14-day calibration records in wt_baselines
class BaselineRepository {

  BaselineRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Get all baselines for a profile
  Future<List<BaselineEntity>> getBaselines(String profileId) async {
    final response = await _supabase
        .from('wt_baselines')
        .select()
        .eq('profile_id', profileId)
        .order('metric_type');

    return (response as List)
        .map((json) => BaselineEntity.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Determine overall calibration status for a profile.
  /// Returns 'complete' if ALL key metrics are complete,
  /// 'in_progress' if any have data (capture_start set),
  /// 'pending' if none have started yet.
  Future<String> getCalibrationStatus(String profileId) async {
    final baselines = await getBaselines(profileId);

    if (baselines.isEmpty) return 'pending';

    final allComplete = baselines.every((b) => b.isComplete);
    if (allComplete) return 'complete';

    final anyStarted = baselines.any(
      (b) => b.captureStart != null || b.calibrationStatus != 'pending',
    );
    return anyStarted ? 'in_progress' : 'pending';
  }

  /// Create baseline records for all key metrics (capture_start = now, status = in_progress).
  /// Uses upsert so it's safe to call multiple times.
  Future<void> initializeBaselines(String profileId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = kBaselineMetricTypes.map((metric) => {
      'profile_id': profileId,
      'metric_type': metric,
      'calibration_status': 'in_progress',
      'capture_start': now,
      'data_points_count': 0,
    }).toList();

    await _supabase.from('wt_baselines').upsert(
      rows,
      onConflict: 'profile_id,metric_type',
      ignoreDuplicates: true, // Don't overwrite if already exists
    );
  }

  /// Update baseline value and data point count for a metric
  Future<void> updateBaselineValue(
    String profileId,
    String metricType,
    double value,
    int dataPointsCount,
  ) async {
    await _supabase
        .from('wt_baselines')
        .update({
          'baseline_value': value,
          'data_points_count': dataPointsCount,
          'calibration_status': 'in_progress',
        })
        .eq('profile_id', profileId)
        .eq('metric_type', metricType);
  }

  /// Mark all baselines for a profile as complete
  Future<void> completeBaselines(String profileId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase
        .from('wt_baselines')
        .update({
          'calibration_status': 'complete',
          'capture_end': now,
        })
        .eq('profile_id', profileId)
        .neq('calibration_status', 'complete'); // Only update incomplete ones
  }

  /// Count the number of distinct days health metrics have been recorded for
  /// this profile, update wt_profiles.baseline_days_count, and mark
  /// baseline_complete if the count reaches 14.
  /// Returns the distinct-day count.
  Future<int> updateBaselineDaysCount(String profileId) async {
    // Server-side RPC: COUNT(DISTINCT DATE(start_time)) for last 60 days.
    // Replaces the old unbounded client-side SELECT for performance.
    int count;
    try {
      final rpcResult = await _supabase.rpc(
        'get_baseline_day_count',
        params: {'p_profile_id': profileId},
      );
      count = (rpcResult as int?) ?? 0;
    } catch (_) {
      // Fallback to client-side count if RPC not deployed yet
      final response = await _supabase
          .from('wt_health_metrics')
          .select('start_time')
          .eq('profile_id', profileId)
          .gte('start_time', DateTime.now().subtract(const Duration(days: 60)).toIso8601String());
      final rows = response as List;
      final distinctDates = rows
          .map((r) {
            final raw = r['start_time'] as String?;
            if (raw == null) return null;
            return DateTime.parse(raw).toLocal().toIso8601String().substring(0, 10);
          })
          .whereType<String>()
          .toSet();
      count = distinctDates.length;
    }

    // Build the update payload
    final Map<String, dynamic> profileUpdate = {
      'baseline_days_count': count,
    };

    if (count >= 14) {
      // Only set completed_at the first time — check current value first
      final profileRow = await _supabase
          .from('wt_profiles')
          .select('baseline_complete')
          .eq('id', profileId)
          .maybeSingle();

      final alreadyComplete =
          profileRow != null && (profileRow['baseline_complete'] as bool? ?? false);

      if (!alreadyComplete) {
        profileUpdate['baseline_complete'] = true;
        profileUpdate['baseline_completed_at'] =
            DateTime.now().toUtc().toIso8601String();
      }
    }

    await _supabase
        .from('wt_profiles')
        .update(profileUpdate)
        .eq('id', profileId);

    return count;
  }
}

/// Riverpod provider
final baselineRepositoryProvider = Provider<BaselineRepository>((ref) {
  return BaselineRepository(Supabase.instance.client);
});
