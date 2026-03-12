import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/recovery_score_entity.dart';
import '../domain/training_load_entity.dart';
import '../domain/forecast_entity.dart';
import '../domain/insight_entity.dart';
import '../data/insights_repository.dart';
import '../data/performance_engine.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';
import '../../../shared/core/ai/ai_providers.dart';

/// Insights State
class InsightsState {

  const InsightsState({
    this.selectedPeriod = PeriodType.week,
    this.recoveryScores = const [],
    this.trainingLoads = const [],
    this.dailyLoadPoints = const [],
    this.forecasts = const [],
    this.insights = const [],
    this.metricTrends = const {},
    this.weeklyLoadTotal = 0,
    this.lastWeekLoadTotal = 0,
    this.fourWeekAverage = 0,
    this.fourWeekDailyLoadPoints = const [],
    this.overtrainingLoadRatio,
    this.overtrainingRisk = OvertrainingRisk.none,
    // US-004 deterministic trends
    this.sleepAvg7Day,
    this.sleepAvg14Day,
    this.stressTrend = TrendDirection.stable,
    this.vo2Slope,
    this.loadTrendPercent,
    this.isLoading = false,
    this.isGeneratingNarrative = false,
    this.error,
  });
  final PeriodType selectedPeriod;
  final List<RecoveryScoreEntity> recoveryScores;
  final List<TrainingLoadEntity> trainingLoads;
  final List<DailyLoadPoint> dailyLoadPoints;
  final List<ForecastEntity> forecasts;
  final List<InsightEntity> insights;
  final Map<String, List<DataPoint>> metricTrends;

  /// Current week total load (this week Monday → today)
  final double weeklyLoadTotal;

  /// Previous week total load
  final double lastWeekLoadTotal;

  /// Average weekly load over past 4 weeks
  final double fourWeekAverage;

  /// Daily load points for the full 4-week rolling window (used by bar chart)
  final List<DailyLoadPoint> fourWeekDailyLoadPoints;

  /// Ratio of current week load to 4-week average (null if no history)
  final double? overtrainingLoadRatio;

  /// Overtraining risk level based on load ratio vs 4-week average
  final OvertrainingRisk overtrainingRisk;

  // US-004: deterministic trend values (zero AI involvement)
  /// 7-day sleep average in hours
  final double? sleepAvg7Day;

  /// 14-day sleep average in hours
  final double? sleepAvg14Day;

  /// Stress trend: improving / worsening / stable (7-day vs previous 7-day)
  final TrendDirection stressTrend;

  /// VO2 max daily slope (ml/kg/min per day) over last 30 days
  final double? vo2Slope;

  /// Training load % change: this week vs last week
  final double? loadTrendPercent;

  final bool isLoading;
  final bool isGeneratingNarrative;
  final String? error;

  InsightsState copyWith({
    PeriodType? selectedPeriod,
    List<RecoveryScoreEntity>? recoveryScores,
    List<TrainingLoadEntity>? trainingLoads,
    List<DailyLoadPoint>? dailyLoadPoints,
    List<ForecastEntity>? forecasts,
    List<InsightEntity>? insights,
    Map<String, List<DataPoint>>? metricTrends,
    double? weeklyLoadTotal,
    double? lastWeekLoadTotal,
    double? fourWeekAverage,
    List<DailyLoadPoint>? fourWeekDailyLoadPoints,
    double? overtrainingLoadRatio,
    OvertrainingRisk? overtrainingRisk,
    double? sleepAvg7Day,
    double? sleepAvg14Day,
    TrendDirection? stressTrend,
    double? vo2Slope,
    double? loadTrendPercent,
    bool? isLoading,
    bool? isGeneratingNarrative,
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
      weeklyLoadTotal: weeklyLoadTotal ?? this.weeklyLoadTotal,
      lastWeekLoadTotal: lastWeekLoadTotal ?? this.lastWeekLoadTotal,
      fourWeekAverage: fourWeekAverage ?? this.fourWeekAverage,
      fourWeekDailyLoadPoints: fourWeekDailyLoadPoints ?? this.fourWeekDailyLoadPoints,
      overtrainingLoadRatio: overtrainingLoadRatio ?? this.overtrainingLoadRatio,
      overtrainingRisk: overtrainingRisk ?? this.overtrainingRisk,
      sleepAvg7Day: sleepAvg7Day ?? this.sleepAvg7Day,
      sleepAvg14Day: sleepAvg14Day ?? this.sleepAvg14Day,
      stressTrend: stressTrend ?? this.stressTrend,
      vo2Slope: vo2Slope ?? this.vo2Slope,
      loadTrendPercent: loadTrendPercent ?? this.loadTrendPercent,
      isLoading: isLoading ?? this.isLoading,
      isGeneratingNarrative: isGeneratingNarrative ?? this.isGeneratingNarrative,
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

  /// Alias for overtrainingLoadRatio — used by TrainingLoadChart
  double? get loadRatio => overtrainingLoadRatio;

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

  InsightsNotifier(
    this._repository,
    this._aiService,
    this._ref,
    this._profileId,
    this._userId,
  ) : super(const InsightsState());
  final InsightsRepository _repository;
  final AiOrchestratorService _aiService;
  final Ref _ref;
  final String _profileId;
  final String _userId;

  DateTime? _lastAiCall;

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

    // Load metric trends for charts
    final sleepTrend = await _repository.getMetricTrend(
      profileId: _profileId,
      metricType: 'sleep',
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    final vo2maxTrend = await _repository.getMetricTrend(
      profileId: _profileId,
      metricType: 'vo2max',
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    final stressTrend = await _repository.getMetricTrend(
      profileId: _profileId,
      metricType: 'stress',
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    // --- Overtraining metrics: always use a 4-week rolling window ---
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final thisWeekStart =
        todayDate.subtract(Duration(days: todayDate.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final fourWeeksAgo = thisWeekStart.subtract(const Duration(days: 28));

    final fourWeekLoads = await _repository.getTrainingLoads(
      profileId: _profileId,
      startDate: fourWeeksAgo,
      endDate: todayDate.add(const Duration(days: 1)),
    );

    // Current week total (Monday → today)
    final weeklyLoadTotal = fourWeekLoads
        .where((l) => !l.loadDate.isBefore(thisWeekStart))
        .fold<double>(0, (sum, l) => sum + l.trainingLoad);

    // Previous week total
    final lastWeekLoadTotal = fourWeekLoads
        .where(
          (l) =>
              !l.loadDate.isBefore(lastWeekStart) &&
              l.loadDate.isBefore(thisWeekStart),
        )
        .fold<double>(0, (sum, l) => sum + l.trainingLoad);

    // 4-week average: total across the 4-week window divided by 4
    final fourWeekTotal =
        fourWeekLoads.fold<double>(0, (sum, l) => sum + l.trainingLoad);
    final fourWeekAverage = fourWeekTotal / 4.0;

    // Daily load points for the 4-week window (used by bar chart)
    final fourWeekDailyLoadPoints = _calculateDailyLoadPoints(
      fourWeekLoads,
      fourWeeksAgo,
      todayDate.add(const Duration(days: 1)),
    );

    // Overtraining risk and ratio
    final overtrainingRisk = PerformanceEngine.checkOvertrainingRisk(
      weeklyLoadTotal,
      fourWeekAverage,
    );
    final overtrainingLoadRatio =
        fourWeekAverage > 0 ? weeklyLoadTotal / fourWeekAverage : null;

    // --- US-004: Deterministic trend calculations (zero AI) ---
    final sevenDaysAgo = todayDate.subtract(const Duration(days: 7));
    final fourteenDaysAgo = todayDate.subtract(const Duration(days: 14));
    final thirtyDaysAgo = todayDate.subtract(const Duration(days: 30));

    // Sleep 7-day average (stored in minutes → convert to hours)
    final sleep7Points =
        sleepTrend.where((p) => !p.date.isBefore(sevenDaysAgo)).toList();
    double? sleepAvg7Day;
    if (sleep7Points.isNotEmpty) {
      sleepAvg7Day =
          sleep7Points.map((p) => p.value / 60.0).reduce((a, b) => a + b) /
              sleep7Points.length;
    }

    // Sleep 14-day average
    final sleep14Points = await _repository.getMetricTrend(
      profileId: _profileId,
      metricType: 'sleep',
      startDate: fourteenDaysAgo,
      endDate: todayDate.add(const Duration(days: 1)),
    );
    double? sleepAvg14Day;
    if (sleep14Points.isNotEmpty) {
      sleepAvg14Day =
          sleep14Points.map((p) => p.value / 60.0).reduce((a, b) => a + b) /
              sleep14Points.length;
    }

    // Stress trend direction: recent 7-day avg vs previous 7-day avg (lower = better)
    final recent7Stress =
        stressTrend.where((p) => !p.date.isBefore(sevenDaysAgo)).toList();
    final prev7Stress = stressTrend
        .where(
          (p) => !p.date.isBefore(fourteenDaysAgo) &&
              p.date.isBefore(sevenDaysAgo),
        )
        .toList();
    var stressTrendDir = TrendDirection.stable;
    if (recent7Stress.isNotEmpty && prev7Stress.isNotEmpty) {
      final recentAvg =
          recent7Stress.map((p) => p.value).reduce((a, b) => a + b) /
              recent7Stress.length;
      final prevAvg =
          prev7Stress.map((p) => p.value).reduce((a, b) => a + b) /
              prev7Stress.length;
      stressTrendDir = PerformanceEngine.classifyTrend(
        currentAvg: recentAvg,
        previousAvg: prevAvg,
        lowerIsBetter: true,
      );
    }

    // VO2 slope over last 30 days (ml/kg/min per day)
    final vo2Points30 = await _repository.getMetricTrend(
      profileId: _profileId,
      metricType: 'vo2max',
      startDate: thirtyDaysAgo,
      endDate: todayDate.add(const Duration(days: 1)),
    );
    final vo2Slope = vo2Points30.length >= 2
        ? PerformanceEngine.calculateVo2Slope(vo2Points30)
        : null;

    // Load trend %: this week vs last week
    final loadTrendPercent = lastWeekLoadTotal > 0
        ? ((weeklyLoadTotal - lastWeekLoadTotal) / lastWeekLoadTotal) * 100
        : null;

    state = state.copyWith(
      recoveryScores: recoveryScores,
      trainingLoads: trainingLoads,
      dailyLoadPoints: dailyLoadPoints,
      forecasts: forecasts,
      insights: insights,
      metricTrends: {
        'sleep': sleepTrend,
        'vo2max': vo2maxTrend,
        'stress': stressTrend,
      },
      weeklyLoadTotal: weeklyLoadTotal,
      lastWeekLoadTotal: lastWeekLoadTotal,
      fourWeekAverage: fourWeekAverage,
      fourWeekDailyLoadPoints: fourWeekDailyLoadPoints,
      overtrainingLoadRatio: overtrainingLoadRatio,
      overtrainingRisk: overtrainingRisk,
      sleepAvg7Day: sleepAvg7Day,
      sleepAvg14Day: sleepAvg14Day,
      stressTrend: stressTrendDir,
      vo2Slope: vo2Slope,
      loadTrendPercent: loadTrendPercent,
    );

    // Persist trend snapshots (non-fatal, fire-and-forget)
    unawaited(_repository.saveTrendSnapshots(
      profileId: _profileId,
      sleepAvg7Day: sleepAvg7Day,
      sleepAvg14Day: sleepAvg14Day,
      vo2Slope: vo2Slope,
      stressTrend: stressTrendDir,
      loadTrendPercent: loadTrendPercent,
    ).catchError((_) {}));
  }

  /// Change selected period
  Future<void> changePeriod(PeriodType period) async {
    state = state.copyWith(selectedPeriod: period, isLoading: true);
    await loadData();
    state = state.copyWith(isLoading: false);
  }

  /// Returns true if a narrative insight for today already exists in the DB.
  /// Prevents burning AI quota when the user navigates away and back.
  Future<bool> _hasNarrativeForToday(String profileId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existing = await _repository.getInsights(
      profileId: profileId,
      periodType: PeriodType.day,
      limit: 1,
    );
    if (existing.isEmpty) return false;
    // Treat as cached if the most recent day-insight starts on or after today.
    return !existing.first.periodStart.isBefore(today);
  }

  /// Generate AI narrative insight for the current period.
  /// This is additive — deterministic data (recovery scores, training loads,
  /// forecasts) already loads without AI. The narrative is optional.
  ///
  /// Flow: build metrics snapshot → call AI → parse structured JSON →
  /// save to DB. On any AI failure, fall back to a deterministic summary
  /// built directly from state data so the user always sees something useful.
  Future<void> generateInsightNarrative() async {
    final now = DateTime.now();
    if (_lastAiCall != null && now.difference(_lastAiCall!).inSeconds < 3) {
      return; // Debounce: skip if called within 3 seconds
    }
    _lastAiCall = now;
    // --- Once-per-day cache guard (day-period only) ---
    // Skip the AI call when we already generated a narrative for today.
    if (state.selectedPeriod == PeriodType.day) {
      final cached = await _hasNarrativeForToday(_profileId);
      if (cached) {
        // Surface the cached record in state so the UI shows it.
        final todayInsights = await _repository.getInsights(
          profileId: _profileId,
          periodType: PeriodType.day,
          limit: 1,
        );
        if (todayInsights.isNotEmpty) {
          state = state.copyWith(
            insights: [todayInsights.first, ...state.insights],
          );
        }
        return;
      }
    }

    state = state.copyWith(isGeneratingNarrative: true, error: null);

    final dateRange = _getDateRangeForPeriod(state.selectedPeriod);

    // Pre-compute metrics needed for both AI context and fallback text
    final latestScore = state.latestRecoveryScore;
    final sleepTrend = state.metricTrends['sleep'] ?? [];
    final avgSleepHours = sleepTrend.isNotEmpty
        ? sleepTrend.map((p) => p.value).reduce((a, b) => a + b) /
            sleepTrend.length /
            60.0
        : null;

    // --- Deterministic fallback (math-only, no AI) ---
    String buildFallbackSummary() {
      final parts = <String>[];
      if (latestScore != null) {
        final label = latestScore.recoveryScore >= 80
            ? 'Excellent'
            : latestScore.recoveryScore >= 60
                ? 'Good'
                : latestScore.recoveryScore >= 40
                    ? 'Fair'
                    : 'Low';
        parts.add('Recovery: ${latestScore.recoveryScore.round()}/100 $label.');
      }
      if (state.weeklyLoadTotal > 0 && state.fourWeekAverage > 0) {
        final pct =
            ((state.weeklyLoadTotal / state.fourWeekAverage - 1) * 100)
                .round();
        final direction = pct >= 0 ? 'up $pct%' : 'down ${pct.abs()}%';
        parts.add('Training load $direction vs 4-week average.');
      }
      if (avgSleepHours != null) {
        parts.add('Sleep averaging ${avgSleepHours.toStringAsFixed(1)} hours.');
      }
      if (state.overtrainingRisk != OvertrainingRisk.none) {
        final risk = state.overtrainingRisk == OvertrainingRisk.high
            ? 'High'
            : 'Moderate';
        parts.add('$risk overtraining risk detected.');
      }
      return parts.isEmpty
          ? 'Keep logging to unlock personalised insights.'
          : parts.join(' ');
    }

    // --- Rich context snapshot for the AI summarize_insights tool ---
    final contextOverride = <String, dynamic>{
      'insights_context': {
        'period': state.selectedPeriod.name,
        'period_start': dateRange.start.toIso8601String(),
        'period_end': dateRange.end.toIso8601String(),
        if (latestScore != null) ...{
          'recovery_score': latestScore.recoveryScore,
          'sleep_component': latestScore.sleepComponent,
          'hr_component': latestScore.hrComponent,
          'load_component': latestScore.loadComponent,
          'stress_component': latestScore.stressComponent,
        },
        'weekly_training_load': state.weeklyLoadTotal,
        'last_week_training_load': state.lastWeekLoadTotal,
        'four_week_avg_load': state.fourWeekAverage,
        'overtraining_risk': state.overtrainingRisk.name,
        if (state.overtrainingLoadRatio != null)
          'load_ratio': state.overtrainingLoadRatio,
        if (avgSleepHours != null) 'avg_sleep_hours': avgSleepHours,
        if (state.sleepAvg7Day != null) 'sleep_avg_7day_hours': state.sleepAvg7Day,
        if (state.sleepAvg14Day != null) 'sleep_avg_14day_hours': state.sleepAvg14Day,
        if (state.vo2Slope != null) 'vo2_trend_slope': state.vo2Slope,
        if (state.loadTrendPercent != null) 'load_trend_pct': state.loadTrendPercent,
      },
      // Tone and length instructions for the AI narrative response.
      'narrative_instructions':
          'Respond in 2-3 sentences using suggestive language only. '
          'Never use the phrases: you must, you should, you need to, you have to. '
          'Use language like: consider, it may help to, you might find, '
          'many athletes notice that.',
    };

    try {
      final response = await _aiService.orchestrate(
        userId: _userId,
        profileId: _profileId,
        workflowType: 'summarize_insights',
        message: 'Summarise my wellness for the ${state.selectedPeriod.name}',
        contextOverride: contextOverride,
      );

      // Update global AI usage
      _ref.read(aiUsageProvider.notifier).state = response.usage;

      // Parse structured JSON from the assistant message.
      // Supports new schema: { insights: [{title, explanation, suggestion}] }
      // and legacy schema: { summary, key_patterns[], recommendations[], flags[] }
      String summaryText = response.assistantMessage;
      Map<String, dynamic> snapshotData = {'is_fallback': false};

      try {
        final raw = response.assistantMessage;
        final jsonStart = raw.indexOf('{');
        final jsonEnd = raw.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          final parsed =
              jsonDecode(raw.substring(jsonStart, jsonEnd + 1))
                  as Map<String, dynamic>;

          if (parsed.containsKey('insights') && parsed['insights'] is List) {
            // New schema: convert insights array to summary text
            final insights = parsed['insights'] as List;
            final buffer = StringBuffer();
            final recommendations = <Map<String, dynamic>>[];
            for (final insight in insights) {
              final i = insight as Map<String, dynamic>;
              buffer.writeln('${i['title']}: ${i['explanation']}');
              if (i['suggestion'] != null) {
                recommendations.add({
                  'action': i['suggestion'],
                  'rationale': i['explanation'],
                });
              }
            }
            summaryText = buffer.toString().trim();
            snapshotData = {
              'is_fallback': false,
              'recommendations': recommendations,
            };
          } else {
            // Legacy schema
            summaryText =
                parsed['summary'] as String? ?? response.assistantMessage;
            snapshotData = {
              'is_fallback': false,
              if (parsed['key_patterns'] != null)
                'key_patterns': parsed['key_patterns'],
              if (parsed['recommendations'] != null)
                'recommendations': parsed['recommendations'],
              if (parsed['flags'] != null) 'flags': parsed['flags'],
            };
          }
        }
      } catch (_) {
        // JSON parsing failed — keep raw assistantMessage as the summary text
      }

      final insight = await _repository.saveInsight(InsightEntity(
        id: '',
        profileId: _profileId,
        periodType: state.selectedPeriod,
        periodStart: dateRange.start,
        periodEnd: dateRange.end,
        summaryText: summaryText,
        aiModel: 'claude',
        metricsSnapshot: snapshotData,
        createdAt: now,
      ));

      state = state.copyWith(
        insights: [insight, ...state.insights],
        isGeneratingNarrative: false,
      );
    } catch (_) {
      // AI failed — save a deterministic fallback so the user always sees
      // something useful rather than an empty card.
      final fallbackSummary = buildFallbackSummary();
      try {
        final insight = await _repository.saveInsight(InsightEntity(
          id: '',
          profileId: _profileId,
          periodType: state.selectedPeriod,
          periodStart: dateRange.start,
          periodEnd: dateRange.end,
          summaryText: fallbackSummary,
          aiModel: null,
          metricsSnapshot: {'is_fallback': true},
          createdAt: now,
        ));
        state = state.copyWith(
          insights: [insight, ...state.insights],
          isGeneratingNarrative: false,
        );
      } catch (_) {
        state = state.copyWith(isGeneratingNarrative: false);
      }
    }
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

  /// Load or refresh a single metric trend
  Future<void> loadMetricTrend(String metricType) async {
    final dateRange = _getDateRangeForPeriod(state.selectedPeriod);
    final trend = await _repository.getMetricTrend(
      profileId: _profileId,
      metricType: metricType,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );
    final updated = Map<String, List<DataPoint>>.from(state.metricTrends)
      ..[metricType] = trend;
    state = state.copyWith(metricTrends: updated);
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

  const DateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// Insights provider factory
final insightsProvider =
    StateNotifierProvider.family<InsightsNotifier, InsightsState, ({String profileId, String userId})>(
  (ref, params) {
    final repository = ref.watch(insightsRepositoryProvider);
    final aiService = ref.watch(aiOrchestratorServiceProvider);
    return InsightsNotifier(
      repository,
      aiService,
      ref,
      params.profileId,
      params.userId,
    );
  },
);
