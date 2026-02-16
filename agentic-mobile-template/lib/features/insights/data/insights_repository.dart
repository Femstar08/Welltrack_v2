import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/insights/domain/recovery_score_entity.dart';
import 'package:welltrack/features/insights/domain/training_load_entity.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';
import 'package:welltrack/features/insights/domain/insight_entity.dart';
import 'package:welltrack/features/insights/data/performance_engine.dart';

/// Insights Repository
/// Handles all insights data operations with Supabase
class InsightsRepository {
  final SupabaseClient _supabase;

  InsightsRepository(this._supabase);

  // Recovery Scores

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
        .gte('score_date', startDate.toIso8601String())
        .lte('score_date', endDate.toIso8601String())
        .order('score_date', ascending: true);

    return (response as List)
        .map((json) => RecoveryScoreEntity.fromJson(json))
        .toList();
  }

  /// Save recovery score
  Future<RecoveryScoreEntity> saveRecoveryScore(
    RecoveryScoreEntity score,
  ) async {
    final json = score.toJson();
    json.remove('id'); // Let database generate ID

    final response = await _supabase
        .from('wt_recovery_scores')
        .insert(json)
        .select()
        .single();

    return RecoveryScoreEntity.fromJson(response);
  }

  /// Calculate and save daily recovery score
  /// Fetches all required inputs and calls PerformanceEngine
  Future<RecoveryScoreEntity?> calculateAndSaveDailyRecovery({
    required String profileId,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

    // Fetch stress data for the date
    final stressData = await _getAvgStress(profileId, dateOnly);

    // Fetch sleep data for the date
    final sleepData = await _getSleepData(profileId, dateOnly);

    // Fetch HR data (current resting HR and baseline)
    final hrData = await _getHRData(profileId, dateOnly);

    // Fetch training load (current week and previous week)
    final loadData = await _getLoadData(profileId, dateOnly);

    // Calculate recovery score
    final score = PerformanceEngine.calculateRecoveryScore(
      profileId: profileId,
      date: dateOnly,
      stressAvg: stressData['avg_stress'],
      sleepDurationMin: sleepData['duration_min'],
      sleepQualityScore: sleepData['quality_score'],
      restingHr: hrData['current_hr'],
      baselineHr: hrData['baseline_hr'],
      currentWeekLoad: loadData['current_week'],
      previousWeekLoad: loadData['previous_week'],
    );

    // Only save if we have at least one component
    if (score.componentsAvailable > 0) {
      return await saveRecoveryScore(score);
    }

    return null;
  }

  // Training Load

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
        .gte('load_date', startDate.toIso8601String())
        .lte('load_date', endDate.toIso8601String())
        .order('load_date', ascending: true);

    return (response as List)
        .map((json) => TrainingLoadEntity.fromJson(json))
        .toList();
  }

  /// Save training load
  Future<TrainingLoadEntity> saveTrainingLoad(
    TrainingLoadEntity load,
  ) async {
    final json = load.toJson();
    json.remove('id'); // Let database generate ID

    final response = await _supabase
        .from('wt_training_loads')
        .insert(json)
        .select()
        .single();

    return TrainingLoadEntity.fromJson(response);
  }

  // Forecasts

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
    json.remove('id'); // Let database generate ID

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
    // Fetch historical data for metric
    final dataPoints = await _getMetricHistory(profileId, metricType);

    if (dataPoints.isEmpty) {
      throw Exception('No historical data available for $metricType');
    }

    // Use earliest date as baseline
    final sortedPoints = List<DataPoint>.from(dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    final baselineDate = sortedPoints.first.date;

    // Calculate forecast
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

  // Insights

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
    json.remove('id'); // Let database generate ID

    final response = await _supabase
        .from('wt_insights')
        .insert(json)
        .select()
        .single();

    return InsightEntity.fromJson(response);
  }

  // Helper methods for fetching component data

  Future<Map<String, double?>> _getAvgStress(
    String profileId,
    DateTime date,
  ) async {
    final response = await _supabase
        .from('wt_health_metrics')
        .select('value_num')
        .eq('profile_id', profileId)
        .eq('metric_type', 'stress')
        .gte('start_time', date.toIso8601String())
        .lt('start_time', date.add(const Duration(days: 1)).toIso8601String());

    if (response.isEmpty) {
      return {'avg_stress': null};
    }

    final values = (response as List)
        .map((r) => (r['value_num'] as num?)?.toDouble())
        .where((v) => v != null)
        .cast<double>()
        .toList();

    if (values.isEmpty) return {'avg_stress': null};

    final avg = values.reduce((a, b) => a + b) / values.length;
    return {'avg_stress': avg};
  }

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
        .lt('start_time', date.add(const Duration(days: 1)).toIso8601String())
        .order('start_time', ascending: false)
        .limit(1);

    if (response.isEmpty) {
      return {'duration_min': null, 'quality_score': null};
    }

    final record = response.first;
    final durationMin = (record['value_num'] as num?)?.toDouble();

    // Try to extract quality score from raw payload
    double? qualityScore;
    if (record['raw_payload_json'] != null) {
      final payload = record['raw_payload_json'] as Map<String, dynamic>;
      qualityScore = (payload['quality_score'] as num?)?.toDouble();
    }

    return {
      'duration_min': durationMin,
      'quality_score': qualityScore,
    };
  }

  Future<Map<String, double?>> _getHRData(
    String profileId,
    DateTime date,
  ) async {
    // Get current resting HR (most recent)
    final currentResponse = await _supabase
        .from('wt_health_metrics')
        .select('value_num')
        .eq('profile_id', profileId)
        .eq('metric_type', 'resting_hr')
        .lte('start_time', date.add(const Duration(days: 1)).toIso8601String())
        .order('start_time', ascending: false)
        .limit(1);

    // Get baseline HR (average of first 14 days)
    final baselineResponse = await _supabase.rpc(
      'get_baseline_resting_hr',
      params: {'p_profile_id': profileId},
    );

    return {
      'current_hr': currentResponse.isNotEmpty
          ? (currentResponse.first['value_num'] as num?)?.toDouble()
          : null,
      'baseline_hr': (baselineResponse as num?)?.toDouble(),
    };
  }

  Future<Map<String, double?>> _getLoadData(
    String profileId,
    DateTime date,
  ) async {
    final currentWeekStart = date.subtract(Duration(days: date.weekday - 1));
    final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));
    final previousWeekStart = currentWeekStart.subtract(const Duration(days: 7));

    // Current week load
    final currentResponse = await _supabase
        .from('wt_training_loads')
        .select('training_load')
        .eq('profile_id', profileId)
        .gte('load_date', currentWeekStart.toIso8601String())
        .lt('load_date', currentWeekEnd.toIso8601String());

    final currentLoad = (currentResponse as List)
        .fold<double>(0, (sum, r) => sum + ((r['training_load'] as num?)?.toDouble() ?? 0));

    // Previous week load
    final previousResponse = await _supabase
        .from('wt_training_loads')
        .select('training_load')
        .eq('profile_id', profileId)
        .gte('load_date', previousWeekStart.toIso8601String())
        .lt('load_date', currentWeekStart.toIso8601String());

    final previousLoad = (previousResponse as List)
        .fold<double>(0, (sum, r) => sum + ((r['training_load'] as num?)?.toDouble() ?? 0));

    return {
      'current_week': currentLoad,
      'previous_week': previousLoad,
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
        .limit(90); // Last 90 data points

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
