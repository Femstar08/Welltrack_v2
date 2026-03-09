import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'insights_provider.dart';
import '../data/performance_engine.dart';
import 'baseline_provider.dart';
import '../domain/baseline_entity.dart';
import 'widgets/recovery_score_card.dart';
import 'widgets/training_load_chart.dart';
import 'widgets/trend_chart_widget.dart';
import '../domain/insight_entity.dart';
import '../domain/forecast_entity.dart';
import '../../../shared/core/auth/session_manager.dart';
import '../../health/presentation/health_connections_provider.dart';
import '../../health/presentation/widgets/garmin_attribution_widget.dart';
import '../../health/presentation/widgets/strava_attribution_widget.dart';
import '../../bloodwork/presentation/bloodwork_provider.dart';
import '../../bloodwork/presentation/widgets/bloodwork_summary_card.dart';

/// Insights Dashboard Screen
/// Main performance intelligence dashboard
class InsightsDashboardScreen extends ConsumerStatefulWidget {

  const InsightsDashboardScreen({
    super.key,
    required this.profileId,
  });
  final String profileId;

  @override
  ConsumerState<InsightsDashboardScreen> createState() =>
      _InsightsDashboardScreenState();
}

class _InsightsDashboardScreenState
    extends ConsumerState<InsightsDashboardScreen> {
  ({String profileId, String userId}) get _params => (
        profileId: widget.profileId,
        userId: ref.read(currentUserIdProvider) ?? '',
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize baseline first (creates records if needed)
      unawaited(
        ref
            .read(baselineProvider(widget.profileId).notifier)
            .initializeIfNeeded(),
      );
      unawaited(ref.read(insightsProvider(_params).notifier).initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = _params;
    final state = ref.watch(insightsProvider(params));
    final notifier = ref.read(insightsProvider(params).notifier);
    final baselineState = ref.watch(baselineProvider(widget.profileId));
    final connectionsState =
        ref.watch(healthConnectionsProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              unawaited(
                ref
                    .read(baselineProvider(widget.profileId).notifier)
                    .load(),
              );
              unawaited(notifier.initialize());
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: state.isLoading || baselineState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildError(state.error!, params)
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(baselineProvider(widget.profileId).notifier)
                        .load();
                    await notifier.initialize();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Baseline calibration banner (shown when in progress)
                        if (baselineState.isInBaselinePeriod) ...[
                          _buildBaselineBanner(baselineState),
                          const SizedBox(height: 16),
                        ],

                        // Period selector
                        _buildPeriodSelector(state.selectedPeriod, notifier),
                        const SizedBox(height: 24),

                        // Recovery score card — shown always when a score exists,
                        // with a "Calibrating" note during the 14-day baseline window.
                        if (state.latestRecoveryScore != null) ...[
                          RecoveryScoreCard(
                            score: state.latestRecoveryScore!,
                            trend: state.recoveryTrend,
                          ),
                          if (baselineState.isInBaselinePeriod) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Calibrating — accuracy improves as more data is collected.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                          if (!baselineState.isInBaselinePeriod &&
                              state.recoveryScores.length > 1) ...[
                            const SizedBox(height: 12),
                            _buildSectionHeader('Recovery History'),
                            const SizedBox(height: 12),
                            TrendChartWidget(
                              dataPoints: state.recoveryScores
                                  .map((s) => DataPoint(
                                        date: s.scoreDate,
                                        value: s.recoveryScore,
                                      ))
                                  .toList(),
                              yAxisLabel: 'Score',
                              color: Colors.green,
                              minY: 0,
                              maxY: 100,
                            ),
                          ],
                        ] else if (baselineState.isInBaselinePeriod)
                          _buildGatedSection('Recovery Score'),

                        // Brand attribution for recovery data source
                        if (connectionsState.garminConnected ||
                            connectionsState.stravaConnected) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              GarminAttributionWidget(
                                visible: connectionsState.garminConnected,
                              ),
                              if (connectionsState.garminConnected &&
                                  connectionsState.stravaConnected)
                                const SizedBox(width: 12),
                              StravaAttributionWidget(
                                visible: connectionsState.stravaConnected,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Training load chart — 4-week rolling window
                        if (state.fourWeekDailyLoadPoints.isNotEmpty) ...[
                          _buildSectionHeader('Training Load (4 Weeks)'),
                          const SizedBox(height: 12),
                          if (state.overtrainingRisk != OvertrainingRisk.none)
                            _buildOvertrainingAlert(state.overtrainingRisk),
                          if (state.overtrainingRisk != OvertrainingRisk.none)
                            const SizedBox(height: 12),
                          TrainingLoadChart(
                            dailyLoads: state.fourWeekDailyLoadPoints,
                            loadRatio: state.overtrainingLoadRatio,
                            weeklyLoadTotal: state.weeklyLoadTotal,
                            lastWeekLoadTotal: state.lastWeekLoadTotal,
                            fourWeekAverage: state.fourWeekAverage,
                          ),
                          // Training load attribution — shown when a connected
                          // provider is supplying workout data
                          if (connectionsState.garminConnected ||
                              connectionsState.stravaConnected) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                GarminAttributionWidget(
                                  visible: connectionsState.garminConnected,
                                ),
                                if (connectionsState.garminConnected &&
                                    connectionsState.stravaConnected)
                                  const SizedBox(width: 12),
                                StravaAttributionWidget(
                                  visible: connectionsState.stravaConnected,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],

                        // VO2 max trend with forecast (gated during baseline)
                        if (baselineState.isInBaselinePeriod) ...[
                          _buildSectionHeader('VO2 Max Trend & Forecast'),
                          const SizedBox(height: 12),
                          _buildGatedSection('Forecasts'),
                          const SizedBox(height: 24),
                        ] else if (_hasForecast(state.forecasts, 'vo2max') ||
                            (state.metricTrends['vo2max']?.isNotEmpty ?? false)) ...[
                          _buildSectionHeader('VO2 Max Trend & Forecast'),
                          const SizedBox(height: 8),
                          _buildVO2ProminentValue(state),
                          const SizedBox(height: 4),
                          _buildVO2ClassificationChip(state),
                          const SizedBox(height: 12),
                          _buildVO2MaxChart(state),
                          const SizedBox(height: 24),
                        ],

                        // Sleep trend
                        _buildSectionHeader('Sleep Trend'),
                        const SizedBox(height: 12),
                        _buildSleepTrend(state),
                        const SizedBox(height: 24),

                        // Stress trend
                        _buildSectionHeader('Stress Trend'),
                        const SizedBox(height: 12),
                        _buildStressTrend(state),
                        const SizedBox(height: 24),

                        // AI weekly summary (gated during baseline)
                        _buildSectionHeader('AI Weekly Summary'),
                        const SizedBox(height: 12),
                        if (baselineState.isInBaselinePeriod)
                          _buildGatedSection('AI Insights')
                        else ...[
                          if (state.currentInsight != null)
                            _buildAISummaryCard(
                                state.currentInsight!, notifier),
                          // Show generate button if no insight OR stale (>7 days)
                          if ((state.currentInsight == null ||
                                  !state.currentInsight!.isWithinLast7Days) &&
                              !state.isGeneratingNarrative)
                            _buildGenerateNarrativeButton(notifier),
                          if (state.isGeneratingNarrative)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text(
                                      'Generating AI insight...',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),

                        // Bloodwork summary — only shown when the user has
                        // at least one result logged.
                        _buildBloodworkSection(),
                        const SizedBox(height: 24),

                        // Baseline comparison (shown after baseline is complete)
                        if (!baselineState.isInBaselinePeriod &&
                            baselineState.calibrationStatus == 'complete')
                          _buildBaselineComparison(state),
                        const SizedBox(height: 24),

                        // Recalculate button (only after baseline)
                        if (!baselineState.isInBaselinePeriod)
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showRecalculateDialog(context, notifier),
                            icon: const Icon(Icons.calculate),
                            label: const Text('Recalculate Forecasts'),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Banner shown during the 14-day baseline collection window
  Widget _buildBaselineBanner(BaselineState baseline) {
    final day = baseline.daysCompleted;
    const total = BaselineEntity.calibrationDays;
    final progress = baseline.progressPercentage.clamp(0.0, 1.0);

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Collecting your baseline...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                Text(
                  'Day $day of $total',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep logging your workouts, sleep, and steps. '
              'Optimization features unlock after ${baseline.daysRemaining} more day${baseline.daysRemaining == 1 ? '' : 's'}.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder shown for gated sections during baseline period
  Widget _buildGatedSection(String featureName) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              '$featureName — Unlocks after 14 days',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// Alert banner shown when training load is above the 4-week average threshold
  Widget _buildOvertrainingAlert(OvertrainingRisk risk) {
    final isHigh = risk == OvertrainingRisk.high;
    final color = isHigh ? Colors.red : Colors.orange;
    final icon = isHigh ? Icons.warning_rounded : Icons.info_outline_rounded;
    final message = isHigh
        ? 'Training load is significantly elevated. A rest or recovery day may help you avoid overtraining.'
        : 'Your training load is above your recent average. Consider balancing with lighter sessions.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(PeriodType selected, InsightsNotifier notifier) {
    return SegmentedButton<PeriodType>(
      segments: const [
        ButtonSegment(
          value: PeriodType.day,
          label: Text('Day'),
          icon: Icon(Icons.today),
        ),
        ButtonSegment(
          value: PeriodType.week,
          label: Text('Week'),
          icon: Icon(Icons.view_week),
        ),
        ButtonSegment(
          value: PeriodType.month,
          label: Text('Month'),
          icon: Icon(Icons.calendar_month),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (Set<PeriodType> selection) {
        notifier.changePeriod(selection.first);
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Bloodwork summary card — shown only when the user has logged at least one
  /// bloodwork result (avoids an empty section for new users).
  Widget _buildBloodworkSection() {
    final bloodworkState =
        ref.watch(bloodworkProvider(widget.profileId));

    // Trigger a load if the state is still pristine (no results, not loading).
    if (!bloodworkState.isLoading && bloodworkState.results.isEmpty &&
        bloodworkState.error == null) {
      Future.microtask(() {
        ref
            .read(bloodworkProvider(widget.profileId).notifier)
            .loadResults();
      });
    }

    // If the user has never logged any bloodwork AND the load has completed,
    // hide the section entirely to keep the dashboard uncluttered.
    if (!bloodworkState.isLoading && bloodworkState.latestByTest.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Bloodwork'),
        const SizedBox(height: 12),
        BloodworkSummaryCard(profileId: widget.profileId),
      ],
    );
  }

  Widget _buildVO2MaxChart(InsightsState state) {
    final vo2maxData = state.metricTrends['vo2max'] ?? [];

    // Fewer than 7 data points — show empty state instead of a sparse chart.
    if (vo2maxData.length < 7) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.directions_run_outlined,
                  color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep training — more data needed',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final forecast = _hasForecast(state.forecasts, 'vo2max')
        ? state.forecasts.firstWhere((f) => f.metricType == 'vo2max')
        : null;

    return TrendChartWidget(
      dataPoints: vo2maxData,
      forecast: forecast,
      yAxisLabel: 'VO2 Max',
      color: Colors.blue,
    );
  }

  /// Large numeric display of the most recent VO2 max value, shown prominently
  /// above the classification chip.
  Widget _buildVO2ProminentValue(InsightsState state) {
    final vo2maxData = state.metricTrends['vo2max'] ?? [];
    if (vo2maxData.isEmpty) return const SizedBox.shrink();
    final latestVo2 = vo2maxData.last.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          latestVo2.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'ml/kg/min',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  /// Returns a classification label chip/badge beneath the VO2 max section
  /// header, showing the current (most recent) VO2 max classification.
  Widget _buildVO2ClassificationChip(InsightsState state) {
    final vo2maxData = state.metricTrends['vo2max'] ?? [];
    if (vo2maxData.isEmpty) return const SizedBox.shrink();

    final latestVo2 = vo2maxData.last.value;
    // Use male norms as default; age placeholder — no age data wired yet.
    final label = _vo2Classification(latestVo2, 30, true);

    Color chipColor;
    switch (label) {
      case 'Superior':
        chipColor = Colors.green;
        break;
      case 'Excellent':
        chipColor = Colors.lightGreen;
        break;
      case 'Good':
        chipColor = Colors.blue;
        break;
      case 'Fair':
        chipColor = Colors.orange;
        break;
      default: // 'Poor'
        chipColor = Colors.red;
    }

    return Row(
      children: [
        Chip(
          label: Text(
            '${latestVo2.toStringAsFixed(1)} ml/kg/min  •  $label',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          backgroundColor: chipColor.withValues(alpha: 0.12),
          side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ],
    );
  }

  /// Deterministic VO2 max fitness classification using male norms.
  /// [ageYears] and [isMale] are reserved for future sex/age-adjusted norms.
  String _vo2Classification(double vo2max, int ageYears, bool isMale) {
    if (vo2max >= 58) return 'Superior';
    if (vo2max >= 50) return 'Excellent';
    if (vo2max >= 42) return 'Good';
    if (vo2max >= 35) return 'Fair';
    return 'Poor';
  }

  Widget _buildSleepTrend(InsightsState state) {
    final sleepData = state.metricTrends['sleep'] ?? [];
    return TrendChartWidget(
      dataPoints: sleepData,
      yAxisLabel: 'Sleep (min)',
      color: Colors.indigo,
      minY: 0,
    );
  }

  Widget _buildStressTrend(InsightsState state) {
    final stressData = state.metricTrends['stress'] ?? [];
    if (stressData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 32),
              SizedBox(height: 8),
              Text(
                'Connect Garmin for stress data',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return TrendChartWidget(
      dataPoints: stressData,
      yAxisLabel: 'Stress (0–100)',
      color: Colors.orange,
      minY: 0,
      maxY: 100,
    );
  }

  Widget _buildAISummaryCard(InsightEntity insight, InsightsNotifier notifier) {
    final isFallback = insight.isFallback;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFallback ? Icons.analytics_outlined : Icons.auto_awesome,
                  color: isFallback ? Colors.grey : Colors.purple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.periodLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isFallback)
                  const Chip(
                    label: Text('Summary'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                else if (insight.aiModel != null)
                  Chip(
                    label: Text(insight.aiModel!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Regenerate',
                  onPressed: () => notifier.generateInsightNarrative(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Summary text
            Text(
              insight.summaryText,
              style: const TextStyle(fontSize: 14),
            ),
            // Warning flags
            if (insight.flags.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...insight.flags.map(
                (flag) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          flag,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Key patterns as chips
            if (insight.keyPatterns.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Key Patterns',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: insight.keyPatterns
                    .map(
                      (p) => Chip(
                        label: Text(
                          p['pattern'] as String? ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.purple.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: Colors.purple.withValues(alpha: 0.3)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            // Recommendations as bullet list
            if (insight.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Recommendations',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...insight.recommendations.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          r['action'] as String? ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateNarrativeButton(InsightsNotifier notifier) {
    return OutlinedButton.icon(
      onPressed: () => notifier.generateInsightNarrative(),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Generate Weekly Summary'),
    );
  }

  Widget _buildBaselineComparison(InsightsState state) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Baseline Comparison',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'vs your first 14 days',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Baseline comparison data will be displayed here.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(
    String error,
    ({String profileId, String userId}) params,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                unawaited(
                  ref.read(insightsProvider(params).notifier).initialize(),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasForecast(List<ForecastEntity> forecasts, String metricType) {
    return forecasts.any((f) => f.metricType == metricType);
  }

  void _showRecalculateDialog(BuildContext context, InsightsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalculate Forecasts'),
        content: const Text(
          'This will recalculate all goal forecasts based on your latest data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Would trigger recalculation for all active goals
              notifier.recalculateForecast(
                metricType: 'vo2max',
                targetValue: 50.0,
              );
            },
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );
  }
}
