import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../health/data/health_repository.dart';
import '../../health/domain/health_metric_entity.dart';
import '../../health/presentation/health_provider.dart';
import '../../insights/domain/forecast_entity.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../../shared/core/logging/app_logger.dart';

// --- Enums & Data Classes ---

enum TrendDirection { up, down, stable }

class PrimaryMetricData {

  const PrimaryMetricData({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.trend = TrendDirection.stable,
  });
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final TrendDirection trend;
}

class KeySignal {

  const KeySignal({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
}

// --- State ---

class DashboardHomeState {

  const DashboardHomeState({
    this.primaryGoal,
    this.goalIntensity,
    this.primaryMetric,
    this.keySignals = const [],
    this.insightText,
    this.trendData = const [],
    this.trendLabel = '',
    this.trendDirection = TrendDirection.stable,
    this.isLoading = true,
  });
  final String? primaryGoal;
  final String? goalIntensity;
  final PrimaryMetricData? primaryMetric;
  final List<KeySignal> keySignals;
  final String? insightText;
  final List<DataPoint> trendData;
  final String trendLabel;
  final TrendDirection trendDirection;
  final bool isLoading;

  DashboardHomeState copyWith({
    String? primaryGoal,
    String? goalIntensity,
    PrimaryMetricData? primaryMetric,
    List<KeySignal>? keySignals,
    String? insightText,
    List<DataPoint>? trendData,
    String? trendLabel,
    TrendDirection? trendDirection,
    bool? isLoading,
  }) {
    return DashboardHomeState(
      primaryGoal: primaryGoal ?? this.primaryGoal,
      goalIntensity: goalIntensity ?? this.goalIntensity,
      primaryMetric: primaryMetric ?? this.primaryMetric,
      keySignals: keySignals ?? this.keySignals,
      insightText: insightText ?? this.insightText,
      trendData: trendData ?? this.trendData,
      trendLabel: trendLabel ?? this.trendLabel,
      trendDirection: trendDirection ?? this.trendDirection,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// --- Notifier ---

class DashboardHomeNotifier extends StateNotifier<DashboardHomeState> {

  DashboardHomeNotifier(this.ref) : super(const DashboardHomeState());
  final Ref ref;
  final AppLogger _logger = AppLogger();

  Future<void> initialize(String profileId) async {
    try {
      state = state.copyWith(isLoading: true);

      // 1. Load profile to get primaryGoal
      final profileAsync = ref.read(activeProfileProvider);
      final profile = profileAsync.valueOrNull;

      final goal = profile?.primaryGoal ?? 'wellness';
      final intensity = profile?.goalIntensity;

      // 2. Read latest metrics
      Map<MetricType, HealthMetricEntity?> metrics = {};
      try {
        metrics = await ref.read(latestMetricsProvider(profileId).future);
      } catch (e) {
        _logger.warning('Could not load metrics: $e');
      }

      // 3. Map goal to primary metric + key signals
      final primaryMetric = _buildPrimaryMetric(goal, metrics);
      final keySignals = _buildKeySignals(goal, metrics);

      // 4. Insight placeholder (real data from wt_insights later)
      const insightText =
          'Connect a device and log a few days of data to see personalized insights here.';

      // 5. Build real 7-day trend data from health metrics
      final trendLabel = _trendLabelForGoal(goal);
      final trendData = await _buildTrendData(profileId, goal);

      // Compute trend direction from data
      final trendDirection = _computeTrendDirection(trendData);

      state = DashboardHomeState(
        primaryGoal: goal,
        goalIntensity: intensity,
        primaryMetric: primaryMetric,
        keySignals: keySignals,
        insightText: insightText,
        trendData: trendData,
        trendLabel: '$trendLabel — 7 Days',
        trendDirection: trendDirection,
        isLoading: false,
      );
    } catch (e, stack) {
      _logger.error('Error initializing dashboard home', e, stack);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh(String profileId) async {
    await initialize(profileId);
  }

  // --- Goal-to-metric mapping ---

  PrimaryMetricData _buildPrimaryMetric(
    String goal,
    Map<MetricType, HealthMetricEntity?> metrics,
  ) {
    switch (goal) {
      case 'performance':
        return _metricData(
          'VO2 Max',
          metrics[MetricType.vo2max],
          'mL/kg/min',
          Icons.speed,
        );
      case 'stress':
        return _metricData(
          'Stress Score',
          metrics[MetricType.stress],
          '',
          Icons.self_improvement,
        );
      case 'sleep':
        return _metricData(
          'Sleep Quality',
          metrics[MetricType.sleep],
          'hrs',
          Icons.bedtime_outlined,
        );
      case 'strength':
        return _metricData(
          'Training Load',
          null, // derived metric — not yet available
          '',
          Icons.fitness_center,
        );
      case 'fat_loss':
        return _metricData(
          'Activity Score',
          metrics[MetricType.steps],
          'steps',
          Icons.local_fire_department_outlined,
        );
      default: // wellness
        return _metricData(
          'Recovery Score',
          null, // composite — not yet available
          '',
          Icons.favorite_outline,
        );
    }
  }

  PrimaryMetricData _metricData(
    String label,
    HealthMetricEntity? metric,
    String unit,
    IconData icon,
  ) {
    final value = metric?.valueNum != null
        ? metric!.valueNum!.toStringAsFixed(
            metric.valueNum! == metric.valueNum!.roundToDouble() ? 0 : 1,
          )
        : '---';

    return PrimaryMetricData(
      label: label,
      value: value,
      unit: unit,
      icon: icon,
    );
  }

  List<KeySignal> _buildKeySignals(
    String goal,
    Map<MetricType, HealthMetricEntity?> metrics,
  ) {
    // Define which 4 signals each goal shows
    final List<_SignalDef> defs;
    switch (goal) {
      case 'performance':
        defs = [
          const _SignalDef('Recovery', MetricType.hr, '', Icons.favorite_outline, Color(0xFF4CAF50)),
          const _SignalDef('Sleep', MetricType.sleep, 'hrs', Icons.bedtime_outlined, Color(0xFF5C6BC0)),
          const _SignalDef('Steps', MetricType.steps, '', Icons.directions_walk, Color(0xFFFF9800)),
          const _SignalDef('Heart Rate', MetricType.hr, 'bpm', Icons.monitor_heart_outlined, Color(0xFFEF5350)),
        ];
      case 'stress':
        defs = [
          const _SignalDef('Sleep', MetricType.sleep, 'hrs', Icons.bedtime_outlined, Color(0xFF5C6BC0)),
          const _SignalDef('Recovery', MetricType.hr, '', Icons.favorite_outline, Color(0xFF4CAF50)),
          const _SignalDef('Steps', MetricType.steps, '', Icons.directions_walk, Color(0xFFFF9800)),
          const _SignalDef('Heart Rate', MetricType.hr, 'bpm', Icons.monitor_heart_outlined, Color(0xFFEF5350)),
        ];
      case 'sleep':
        defs = [
          const _SignalDef('Sleep Hours', MetricType.sleep, 'hrs', Icons.schedule, Color(0xFF5C6BC0)),
          const _SignalDef('Heart Rate', MetricType.hr, 'bpm', Icons.monitor_heart_outlined, Color(0xFFEF5350)),
          const _SignalDef('Steps', MetricType.steps, '', Icons.directions_walk, Color(0xFFFF9800)),
          const _SignalDef('Stress', MetricType.stress, '', Icons.self_improvement, Color(0xFF7E57C2)),
        ];
      case 'strength':
        defs = [
          const _SignalDef('Recovery', MetricType.hr, '', Icons.favorite_outline, Color(0xFF4CAF50)),
          const _SignalDef('Sleep', MetricType.sleep, 'hrs', Icons.bedtime_outlined, Color(0xFF5C6BC0)),
          const _SignalDef('Steps', MetricType.steps, '', Icons.directions_walk, Color(0xFFFF9800)),
          const _SignalDef('Heart Rate', MetricType.hr, 'bpm', Icons.monitor_heart_outlined, Color(0xFFEF5350)),
        ];
      case 'fat_loss':
        defs = [
          const _SignalDef('Steps', MetricType.steps, '', Icons.directions_walk, Color(0xFFFF9800)),
          const _SignalDef('Sleep', MetricType.sleep, 'hrs', Icons.bedtime_outlined, Color(0xFF5C6BC0)),
          const _SignalDef('Heart Rate', MetricType.hr, 'bpm', Icons.monitor_heart_outlined, Color(0xFFEF5350)),
          const _SignalDef('Recovery', MetricType.hr, '', Icons.favorite_outline, Color(0xFF4CAF50)),
        ];
      default: // wellness
        defs = [
          const _SignalDef('Sleep', MetricType.sleep, 'hrs', Icons.bedtime_outlined, Color(0xFF5C6BC0)),
          const _SignalDef('Steps', MetricType.steps, '', Icons.directions_walk, Color(0xFFFF9800)),
          const _SignalDef('Heart Rate', MetricType.hr, 'bpm', Icons.monitor_heart_outlined, Color(0xFFEF5350)),
          const _SignalDef('Stress', MetricType.stress, '', Icons.self_improvement, Color(0xFF7E57C2)),
        ];
    }

    return defs.map((d) {
      final metric = metrics[d.metricType];
      final val = metric?.valueNum != null
          ? metric!.valueNum!.toStringAsFixed(
              metric.valueNum! == metric.valueNum!.roundToDouble() ? 0 : 1,
            )
          : '---';
      return KeySignal(
        label: d.label,
        value: val,
        unit: d.unit,
        icon: d.icon,
        color: d.color,
      );
    }).toList();
  }

  String _trendLabelForGoal(String goal) {
    switch (goal) {
      case 'performance':
        return 'VO2 Max';
      case 'stress':
        return 'Stress Score';
      case 'sleep':
        return 'Sleep Quality';
      case 'strength':
        return 'Training Load';
      case 'fat_loss':
        return 'Activity Score';
      default:
        return 'Recovery Score';
    }
  }

  /// Build real 7-day trend data from health metrics
  Future<List<DataPoint>> _buildTrendData(String profileId, String goal) async {
    try {
      final repository = ref.read(healthRepositoryProvider);
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      // Map goal to the metric type to query
      final metricType = _metricTypeForGoal(goal);
      if (metricType == null) return [];

      final metrics = await repository.getMetrics(
        profileId,
        metricType,
        startDate: sevenDaysAgo,
        endDate: now,
      );

      if (metrics.isEmpty) return [];

      // Group by day, taking latest value per day
      final Map<String, DataPoint> dailyMap = {};
      for (final metric in metrics) {
        final dayKey =
            '${metric.startTime.year}-${metric.startTime.month}-${metric.startTime.day}';
        if (!dailyMap.containsKey(dayKey) && metric.valueNum != null) {
          // Convert sleep from minutes to hours for display
          final displayValue = metricType == MetricType.sleep
              ? metric.valueNum! / 60.0
              : metric.valueNum!;
          dailyMap[dayKey] = DataPoint(
            date: DateTime(
              metric.startTime.year,
              metric.startTime.month,
              metric.startTime.day,
            ),
            value: displayValue,
          );
        }
      }

      final sorted = dailyMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return sorted;
    } catch (e) {
      _logger.warning('Failed to build trend data: $e');
      return [];
    }
  }

  TrendDirection _computeTrendDirection(List<DataPoint> data) {
    if (data.length < 2) return TrendDirection.stable;
    final firstHalf = data.sublist(0, data.length ~/ 2);
    final secondHalf = data.sublist(data.length ~/ 2);
    final firstAvg =
        firstHalf.map((d) => d.value).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg =
        secondHalf.map((d) => d.value).reduce((a, b) => a + b) / secondHalf.length;
    final diff = secondAvg - firstAvg;
    if (diff.abs() < firstAvg * 0.02) return TrendDirection.stable;
    return diff > 0 ? TrendDirection.up : TrendDirection.down;
  }

  MetricType? _metricTypeForGoal(String goal) {
    switch (goal) {
      case 'performance':
        return MetricType.vo2max;
      case 'stress':
        return MetricType.stress;
      case 'sleep':
        return MetricType.sleep;
      case 'strength':
        return MetricType.steps; // proxy until training load exists
      case 'fat_loss':
        return MetricType.steps;
      default:
        return MetricType.hr;
    }
  }
}

class _SignalDef {

  const _SignalDef(this.label, this.metricType, this.unit, this.icon, this.color);
  final String label;
  final MetricType metricType;
  final String unit;
  final IconData icon;
  final Color color;
}

// --- Provider ---

final dashboardHomeProvider =
    StateNotifierProvider<DashboardHomeNotifier, DashboardHomeState>(
  (ref) => DashboardHomeNotifier(ref),
);
