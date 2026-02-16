import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/insights/domain/recovery_score_entity.dart';
import 'package:welltrack/features/insights/domain/training_load_entity.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';
import 'package:welltrack/features/insights/domain/insight_entity.dart';
import 'package:welltrack/features/insights/data/insights_repository.dart';

/// Insights State
class InsightsState {
  final PeriodType selectedPeriod;
  final List<RecoveryScoreEntity> recoveryScores;
  final List<TrainingLoadEntity> trainingLoads;
  final List<DailyLoadPoint> dailyLoadPoints;
  final List<ForecastEntity> forecasts;
  final List<InsightEntity> insights;
  final Map<String, List<DataPoint>> metricTrends;
  final bool isLoading;
  final String? error;

  const InsightsState({
    this.selectedPeriod = PeriodType.week,
    this.recoveryScores = const [],
    this.trainingLoads = const [],
    this.dailyLoadPoints = const [],
    this.forecasts = const [],
    this.insights = const [],
    this.metricTrends = const {},
    this.isLoading = false,
    this.error,
  });

  InsightsState copyWith({
    PeriodType? selectedPeriod,
    List<RecoveryScoreEntity>? recoveryScores,
    List<TrainingLoadEntity>? trainingLoads,
    List<DailyLoadPoint>? dailyLoadPoints,
    List<ForecastEntity>? forecasts,
    List<InsightEntity>? insights,
    Map<String, List<DataPoint>>? metricTrends,
    bool? isLoading,
    String? error,
  }) {
    return InsightsState(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      recoveryScores: recoveryScores ?? this.recoveryScores,
      trainingLoads: trainingLoads ?? this.trainingLoads,
      dailyLoadPoints: dailyLoadPoints ?? this.dailyLoadPoints,
      forecasts: forecasts ?? this.forecasts,
      insights: insights ?? this.insights,
      metricTrends: metricTrends ?? this.metricTrends,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get most recent recovery score
  RecoveryScoreEntity? get latestRecoveryScore =>
      recoveryScores.isNotEmpty ? recoveryScores.last : null;

  /// Get recovery trend (compared to previous score)
  RecoveryTrend get recoveryTrend {
    if (recoveryScores.length < 2) return RecoveryTrend.flat;
    final latest = recoveryScores.last;
    final previous = recoveryScores[recoveryScores.length - 2];
    return latest.getTrendComparedTo(previous);
  }

  /// Get total training load for period
  double get totalTrainingLoad {
    return trainingLoads.fold<double>(
      0,
      (sum, load) => sum + load.trainingLoad,
    );
  }

  /// Get current week load vs previous week ratio
  double? get loadRatio {
    if (dailyLoadPoints.length < 14) return null;

    final currentWeek = dailyLoadPoints.skip(7).take(7);
    final previousWeek = dailyLoadPoints.take(7);

    final currentTotal = currentWeek.fold<double>(0, (sum, p) => sum + p.load);
    final previousTotal = previousWeek.fold<double>(0, (sum, p) => sum + p.load);

    if (previousTotal == 0) return null;
    return currentTotal / previousTotal;
  }

  /// Get most recent insight for selected period
  InsightEntity? get currentInsight {
    if (insights.isEmpty) return null;
    return insights.firstWhere(
      (i) => i.periodType == selectedPeriod,
      orElse: () => insights.first,
    );
  }
}

/// Insights StateNotifier
class InsightsNotifier extends StateNotifier<InsightsState> {
  final InsightsRepository _repository;
  final String _profileId;

  InsightsNotifier(this._repository, this._profileId)
      : super(const InsightsState());

  /// Initialize insights for profile
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await loadData();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load insights: $e',
      );
    }
  }

  /// Load all insights data
  Future<void> loadData() async {
    final dateRange = _getDateRangeForPeriod(state.selectedPeriod);

    // Load recovery scores
    final recoveryScores = await _repository.getRecoveryScores(
      profileId: _profileId,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    // Load training loads
    final trainingLoads = await _repository.getTrainingLoads(
      profileId: _profileId,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    // Calculate daily load points
    final dailyLoadPoints = _calculateDailyLoadPoints(
      trainingLoads,
      dateRange.start,
      dateRange.end,
    );

    // Load forecasts
    final forecasts = await _repository.getForecasts(
      profileId: _profileId,
    );

    // Load insights
    final insights = await _repository.getInsights(
      profileId: _profileId,
      periodType: state.selectedPeriod,
      limit: 5,
    );

    state = state.copyWith(
      recoveryScores: recoveryScores,
      trainingLoads: trainingLoads,
      dailyLoadPoints: dailyLoadPoints,
      forecasts: forecasts,
      insights: insights,
    );
  }

  /// Change selected period
  Future<void> changePeriod(PeriodType period) async {
    state = state.copyWith(selectedPeriod: period, isLoading: true);
    await loadData();
    state = state.copyWith(isLoading: false);
  }

  /// Calculate and save today's recovery score
  Future<void> calculateTodayRecovery() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final score = await _repository.calculateAndSaveDailyRecovery(
        profileId: _profileId,
      );

      if (score != null) {
        // Refresh recovery scores
        await loadData();
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to calculate recovery: $e',
      );
    }
  }

  /// Recalculate forecast for a metric
  Future<void> recalculateForecast({
    required String metricType,
    required double targetValue,
    String? goalForecastId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.calculateAndSaveForecast(
        profileId: _profileId,
        metricType: metricType,
        targetValue: targetValue,
        goalForecastId: goalForecastId,
      );

      // Refresh forecasts
      final forecasts = await _repository.getForecasts(
        profileId: _profileId,
      );

      state = state.copyWith(
        forecasts: forecasts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to recalculate forecast: $e',
      );
    }
  }

  /// Load metric trend data
  Future<void> loadMetricTrend(String metricType) async {
    // This would fetch health metrics data for charting
    // Implementation depends on health metrics data structure
  }

  /// Get date range based on period type
  DateRange _getDateRangeForPeriod(PeriodType period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case PeriodType.day:
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case PeriodType.week:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(
          start: weekStart.subtract(const Duration(days: 7)), // Include previous week
          end: weekStart.add(const Duration(days: 14)),
        );
      case PeriodType.month:
        final monthStart = DateTime(today.year, today.month, 1);
        final monthEnd = DateTime(today.year, today.month + 1, 1);
        return DateRange(
          start: monthStart.subtract(const Duration(days: 30)), // Include previous month
          end: monthEnd,
        );
    }
  }

  /// Calculate daily load points for charting
  List<DailyLoadPoint> _calculateDailyLoadPoints(
    List<TrainingLoadEntity> loads,
    DateTime start,
    DateTime end,
  ) {
    final points = <DailyLoadPoint>[];
    final loadsByDate = <DateTime, List<TrainingLoadEntity>>{};

    // Group loads by date
    for (final load in loads) {
      final dateOnly = DateTime(
        load.loadDate.year,
        load.loadDate.month,
        load.loadDate.day,
      );
      loadsByDate.putIfAbsent(dateOnly, () => []).add(load);
    }

    // Create daily points
    var currentDate = start;
    while (currentDate.isBefore(end)) {
      final loadsForDate = loadsByDate[currentDate] ?? [];
      points.add(DailyLoadPoint.fromLoads(
        date: currentDate,
        loads: loadsForDate,
      ));
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return points;
  }
}

/// Date range helper
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});
}

/// Insights provider factory
final insightsProvider = StateNotifierProvider.family<InsightsNotifier, InsightsState, String>(
  (ref, profileId) {
    final repository = ref.watch(insightsRepositoryProvider);
    return InsightsNotifier(repository, profileId);
  },
);
