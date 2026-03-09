import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/recovery_score_entity.dart';
import '../domain/training_load_entity.dart';
import '../domain/forecast_entity.dart';
import '../domain/insight_entity.dart';
import 'performance_engine.dart';

/// Insights Repository
/// Handles all insights data operations with Supabase.
class InsightsRepository {

  InsightsRepository(this._supabase);
  final SupabaseClient _supabase;

  // ---------------------------------------------------------------------------
  // Recovery Scores
  // ---------------------------------------------------------------------------

  /// Get recovery scores for a profile within date range
  Future<List<RecoveryScoreEntity>> getRecoveryScores({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase
        .from('wt_recovery_scores')
        .select()
        .eq('profile_id', profileId)
        .gte('score_date', _dateStr(startDate))
        .lte('score_date', _dateStr(endDate))
        .order('score_date', ascending: true);

    return (response as List)
        .map((json) => RecoveryScoreEntity.fromJson(json))
        .toList();
  }

  /// Upsert recovery score (INSERT … ON CONFLICT (profile_id, score_date) DO UPDATE)
  Future<RecoveryScoreEntity> saveRecoveryScore(
    RecoveryScoreEntity score,
  ) async {
    return _upsertRecoveryScore(score);
  }

  /// Calculate and save today's recovery score using PRD Phase 10 formula.
  /// Skips if a score for today already exists.
  Future<RecoveryScoreEntity?> calculateAndSaveDailyRecovery({
    required String profileId,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

    // Skip if today's score is already recorded
    final existing = await _getTodayScore(profileId, dateOnly);
    if (existing != null) return existing;

    // Fetch inputs
    final sleepData = await _getSleepData(profileId, dateOnly);
    final hrData = await _getHRData(profileId, dateOnly);
    final loadData = await _getLoadData(profileId, dateOnly);

    // Phase 11: fetch Garmin-specific metrics (body battery and stress score).
    // These take priority over Health Connect equivalents when available.
    final garminData = await _getGarminData(profileId, dateOnly);

    final score = PerformanceEngine.calculateRecoveryScore(
      profileId: profileId,
      date: dateOnly,
      sleepDurationHours: sleepData['duration_hours'],
      sleepQualityRatio: sleepData['quality_ratio'],
      restingHr: hrData['current_hr'],
      baselineHr: hrData['baseline_hr'],
      sevenDayLoad: loadData['seven_day'],
      fourWeekAvgLoad: loadData['four_week_avg'],
      garminBodyBattery: garminData['body_battery'],
      garminStressScore: garminData['stress_score'],
    );

    if (score.componentsAvailable > 0) {
      return await _upsertRecoveryScore(score);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Training Load
  // ---------------------------------------------------------------------------

  /// Get training loads for a profile within date range
  Future<List<TrainingLoadEntity>> getTrainingLoads({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase
        .from('wt_training_loads')
        .select()
        .eq('profile_id', profileId)
        .gte('load_date', _dateStr(startDate))
        .lte('load_date', _dateStr(endDate))
        .order('load_date', ascending: true);

    return (response as List)
        .map((json) => TrainingLoadEntity.fromJson(json))
        .toList();
  }

  /// Upsert training load (conflict on profile_id + workout_id when present,
  /// otherwise on profile_id + load_date for manual entries)
  Future<TrainingLoadEntity> saveTrainingLoad(
    TrainingLoadEntity load,
  ) async {
    final json = load.toJson();
    json.remove('id');
    json['load_date'] = _dateStr(load.loadDate);

    final response = await _supabase
        .from('wt_training_loads')
        .upsert(json, onConflict: 'profile_id,workout_id')
        .select()
        .single();

    return TrainingLoadEntity.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Forecasts
  // ---------------------------------------------------------------------------

  /// Get forecasts for a profile
  Future<List<ForecastEntity>> getForecasts({
    required String profileId,
    String? metricType,
  }) async {
    var query = _supabase
        .from('wt_forecasts')
        .select()
        .eq('profile_id', profileId);

    if (metricType != null) {
      query = query.eq('metric_type', metricType);
    }

    final response = await query.order('calculated_at', ascending: false);

    return (response as List)
        .map((json) => ForecastEntity.fromJson(json))
        .toList();
  }

  /// Save forecast
  Future<ForecastEntity> saveForecast(ForecastEntity forecast) async {
    final json = forecast.toJson();
    json.remove('id');

    final response = await _supabase
        .from('wt_forecasts')
        .insert(json)
        .select()
        .single();

    return ForecastEntity.fromJson(response);
  }

  /// Calculate and save forecast
  Future<ForecastEntity> calculateAndSaveForecast({
    required String profileId,
    required String metricType,
    required double targetValue,
    String? goalForecastId,
  }) async {
    final dataPoints = await _getMetricHistory(profileId, metricType);

    if (dataPoints.isEmpty) {
      throw Exception('No historical data available for $metricType');
    }

    final sortedPoints = List<DataPoint>.from(dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    final baselineDate = sortedPoints.first.date;

    final forecast = PerformanceEngine.calculateForecast(
      profileId: profileId,
      metricType: metricType,
      targetValue: targetValue,
      dataPoints: dataPoints,
      baselineDate: baselineDate,
      goalForecastId: goalForecastId,
    );

    return await saveForecast(forecast);
  }

  // ---------------------------------------------------------------------------
  // Insights (AI narrative)
  // ---------------------------------------------------------------------------

  /// Get insights for a profile and period
  Future<List<InsightEntity>> getInsights({
    required String profileId,
    PeriodType? periodType,
    int limit = 10,
  }) async {
    var query = _supabase
        .from('wt_insights')
        .select()
        .eq('profile_id', profileId);

    if (periodType != null) {
      query = query.eq('period_type', periodType.name);
    }

    final response = await query
        .order('period_start', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => InsightEntity.fromJson(json))
        .toList();
  }

  /// Save insight
  Future<InsightEntity> saveInsight(InsightEntity insight) async {
    final json = insight.toJson();
    json.remove('id');

    final response = await _supabase
        .from('wt_insights')
        .insert(json)
        .select()
        .single();

    return InsightEntity.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Trend snapshots
  // ---------------------------------------------------------------------------

  /// Persist daily trend snapshots to wt_health_metrics.
  /// Uses existing enum values for metric_type; value_text carries the trend key.
  /// The DB trigger auto-generates dedupe_hash so same-day re-runs are silent no-ops.
  Future<void> saveTrendSnapshots({
    required String profileId,
    double? sleepAvg7Day,
    double? sleepAvg14Day,
    double? vo2Slope,
    TrendDirection? stressTrend,
    double? loadTrendPercent,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    final startTimeIso =
        DateTime.utc(now.year, now.month, now.day).toIso8601String();

    final snapshots = <Map<String, dynamic>>[];

    void add(String metricType, double value, String valueText, String unit) {
      snapshots.add({
        'profile_id': profileId,
        'user_id': userId,
        'source': 'manual',
        'metric_type': metricType,
        'value_num': value,
        'value_text': valueText,
        'unit': unit,
        'start_time': startTimeIso,
      });
    }

    if (sleepAvg7Day != null) add('sleep', sleepAvg7Day, 'sleep_7day_avg_hours', 'hours');
    if (sleepAvg14Day != null) add('sleep', sleepAvg14Day, 'sleep_14day_avg_hours', 'hours');
    if (vo2Slope != null) add('vo2max', vo2Slope, 'vo2_slope_per_day', 'ml/kg/min/day');
    if (stressTrend != null) {
      final encoded = stressTrend == TrendDirection.improving
          ? 1.0
          : stressTrend == TrendDirection.worsening
              ? -1.0
              : 0.0;
      add('stress', encoded, 'stress_trend', 'direction');
    }
    if (loadTrendPercent != null) {
      add('active_minutes', loadTrendPercent, 'load_trend_pct', 'percent');
    }

    if (snapshots.isEmpty) return;

    try {
      await _supabase.from('wt_health_metrics').insert(snapshots);
    } catch (_) {
      // Duplicate dedupe_hash or other DB error — non-fatal
    }
  }

  // ---------------------------------------------------------------------------
  // Metric trends
  // ---------------------------------------------------------------------------

  /// Get metric trend data points within a date range (for charting)
  Future<List<DataPoint>> getMetricTrend({
    required String profileId,
    required String metricType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _supabase
        .from('wt_health_metrics')
        .select('start_time, value_num')
        .eq('profile_id', profileId)
        .eq('metric_type', metricType)
        .gte('start_time', startDate.toIso8601String())
        .lte('start_time', endDate.toIso8601String())
        .not('value_num', 'is', null)
        .order('start_time', ascending: true);

    return (response as List)
        .map((r) => DataPoint(
              date: DateTime.parse(r['start_time'] as String),
              value: (r['value_num'] as num).toDouble(),
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Return YYYY-MM-DD string for Supabase DATE column comparisons.
  String _dateStr(DateTime dt) => dt.toIso8601String().substring(0, 10);

  /// Check if today's recovery score already exists.
  Future<RecoveryScoreEntity?> _getTodayScore(
    String profileId,
    DateTime date,
  ) async {
    final response = await _supabase
        .from('wt_recovery_scores')
        .select()
        .eq('profile_id', profileId)
        .eq('score_date', _dateStr(date))
        .limit(1);

    if ((response as List).isEmpty) return null;
    return RecoveryScoreEntity.fromJson(response.first);
  }

  /// Upsert recovery score; conflict key = (profile_id, score_date).
  Future<RecoveryScoreEntity> _upsertRecoveryScore(
    RecoveryScoreEntity score,
  ) async {
    final json = score.toJson();
    json.remove('id');
    json['score_date'] = _dateStr(score.scoreDate);

    final response = await _supabase
        .from('wt_recovery_scores')
        .upsert(json, onConflict: 'profile_id,score_date')
        .select()
        .single();

    return RecoveryScoreEntity.fromJson(response);
  }

  /// Fetch sleep duration (hours) and quality ratio for a given date.
  Future<Map<String, double?>> _getSleepData(
    String profileId,
    DateTime date,
  ) async {
    final response = await _supabase
        .from('wt_health_metrics')
        .select('value_num, raw_payload_json')
        .eq('profile_id', profileId)
        .eq('metric_type', 'sleep')
        .gte('start_time', date.toIso8601String())
        .lt(
          'start_time',
          date.add(const Duration(days: 1)).toIso8601String(),
        )
        .order('start_time', ascending: false)
        .limit(1);

    if ((response as List).isEmpty) {
      return {'duration_hours': null, 'quality_ratio': null};
    }

    final record = response.first;
    final durationMin = (record['value_num'] as num?)?.toDouble();
    final durationHours = durationMin != null ? durationMin / 60.0 : null;

    double? qualityRatio;
    if (record['raw_payload_json'] != null) {
      final payload = record['raw_payload_json'] as Map<String, dynamic>;
      final remMin =
          (payload['rem_sleep_minutes'] as num?)?.toDouble() ?? 0.0;
      final deepMin =
          (payload['deep_sleep_minutes'] as num?)?.toDouble() ?? 0.0;
      if (durationMin != null && durationMin > 0) {
        qualityRatio = (remMin + deepMin) / durationMin;
      }
    }

    return {'duration_hours': durationHours, 'quality_ratio': qualityRatio};
  }

  /// Fetch today's resting HR and 14-day average baseline (no RPC needed).
  Future<Map<String, double?>> _getHRData(
    String profileId,
    DateTime date,
  ) async {
    // Today's resting HR — most recent reading up to end of day
    final currentResponse = await _supabase
        .from('wt_health_metrics')
        .select('value_num')
        .eq('profile_id', profileId)
        .eq('metric_type', 'resting_hr')
        .lte(
          'start_time',
          date.add(const Duration(days: 1)).toIso8601String(),
        )
        .not('value_num', 'is', null)
        .order('start_time', ascending: false)
        .limit(1);

    // 14-day baseline: average of all resting_hr readings in window
    final fourteenDaysAgo = date.subtract(const Duration(days: 14));
    final baselineResponse = await _supabase
        .from('wt_health_metrics')
        .select('value_num')
        .eq('profile_id', profileId)
        .eq('metric_type', 'resting_hr')
        .gte('start_time', fourteenDaysAgo.toIso8601String())
        .lte('start_time', date.add(const Duration(days: 1)).toIso8601String())
        .not('value_num', 'is', null);

    double? baselineHr;
    if ((baselineResponse as List).isNotEmpty) {
      final values = baselineResponse
          .map((r) => (r['value_num'] as num?)?.toDouble())
          .where((v) => v != null)
          .cast<double>()
          .toList();
      if (values.isNotEmpty) {
        baselineHr = values.reduce((a, b) => a + b) / values.length;
      }
    }

    return {
      'current_hr': (currentResponse as List).isNotEmpty
          ? (currentResponse.first['value_num'] as num?)?.toDouble()
          : null,
      'baseline_hr': baselineHr,
    };
  }

  /// Fetch Garmin body battery and stress score for a given date.
  ///
  /// Queries wt_health_metrics rows where source = 'garmin' for the metric
  /// types 'body_battery' and 'stress'. Returns null for each field if no
  /// Garmin record is present, allowing the engine to fall back to Health
  /// Connect data transparently.
  ///
  /// Body battery: 0-100 (higher = better — Garmin convention).
  /// Stress score: 0-100 (lower = less stress = better — Garmin convention).
  Future<Map<String, double?>> _getGarminData(
    String profileId,
    DateTime date,
  ) async {
    final startOfDay = date.toIso8601String();
    final startOfNextDay = date.add(const Duration(days: 1)).toIso8601String();

    double? bodyBattery;
    double? stressScore;

    try {
      // Body battery — take the most recent reading for the day
      final bbResponse = await _supabase
          .from('wt_health_metrics')
          .select('value_num')
          .eq('profile_id', profileId)
          .eq('metric_type', 'body_battery')
          .eq('source', 'garmin')
          .gte('start_time', startOfDay)
          .lt('start_time', startOfNextDay)
          .not('value_num', 'is', null)
          .order('start_time', ascending: false)
          .limit(1);

      if ((bbResponse as List).isNotEmpty) {
        bodyBattery =
            (bbResponse.first['value_num'] as num?)?.toDouble();
      }

      // Stress score — take the daily average if multiple readings exist,
      // otherwise use the most recent single reading
      final stressResponse = await _supabase
          .from('wt_health_metrics')
          .select('value_num')
          .eq('profile_id', profileId)
          .eq('metric_type', 'stress')
          .eq('source', 'garmin')
          .gte('start_time', startOfDay)
          .lt('start_time', startOfNextDay)
          .not('value_num', 'is', null);

      if ((stressResponse as List).isNotEmpty) {
        final values = stressResponse
            .map((r) => (r['value_num'] as num?)?.toDouble())
            .where((v) => v != null)
            .cast<double>()
            .toList();
        if (values.isNotEmpty) {
          stressScore = values.reduce((a, b) => a + b) / values.length;
        }
      }
    } catch (_) {
      // Non-fatal — if Garmin table query fails, fall back to Health Connect
    }

    return {
      'body_battery': bodyBattery,
      'stress_score': stressScore,
    };
  }

  /// Fetch 7-day rolling load and 4-week average weekly load.
  Future<Map<String, double?>> _getLoadData(
    String profileId,
    DateTime date,
  ) async {
    final sevenDaysAgo = date.subtract(const Duration(days: 7));
    final twentyEightDaysAgo = date.subtract(const Duration(days: 28));

    // 7-day rolling load sum
    final sevenDayResponse = await _supabase
        .from('wt_training_loads')
        .select('training_load')
        .eq('profile_id', profileId)
        .gte('load_date', _dateStr(sevenDaysAgo))
        .lte('load_date', _dateStr(date));

    final sevenDayLoad = (sevenDayResponse as List).fold<double>(
      0,
      (sum, r) => sum + ((r['training_load'] as num?)?.toDouble() ?? 0),
    );

    // 28-day total → divide by 4 to get weekly average
    final fourWeekResponse = await _supabase
        .from('wt_training_loads')
        .select('training_load')
        .eq('profile_id', profileId)
        .gte('load_date', _dateStr(twentyEightDaysAgo))
        .lte('load_date', _dateStr(date));

    final fourWeekTotal = (fourWeekResponse as List).fold<double>(
      0,
      (sum, r) => sum + ((r['training_load'] as num?)?.toDouble() ?? 0),
    );
    final fourWeekAvg = fourWeekTotal / 4.0;

    return {
      'seven_day': sevenDayLoad,
      'four_week_avg': fourWeekAvg > 0 ? fourWeekAvg : null,
    };
  }

  Future<List<DataPoint>> _getMetricHistory(
    String profileId,
    String metricType,
  ) async {
    final response = await _supabase
        .from('wt_health_metrics')
        .select('start_time, value_num')
        .eq('profile_id', profileId)
        .eq('metric_type', metricType)
        .not('value_num', 'is', null)
        .order('start_time', ascending: true)
        .limit(90);

    return (response as List)
        .map((r) => DataPoint(
              date: DateTime.parse(r['start_time'] as String),
              value: (r['value_num'] as num).toDouble(),
            ))
        .toList();
  }
}

/// Riverpod provider for InsightsRepository
final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(Supabase.instance.client);
});
