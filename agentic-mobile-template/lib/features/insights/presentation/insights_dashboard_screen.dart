import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'insights_provider.dart';
import 'widgets/recovery_score_card.dart';
import 'widgets/training_load_chart.dart';
import 'widgets/trend_chart_widget.dart';
import '../domain/insight_entity.dart';
import '../domain/forecast_entity.dart';
import '../../../shared/core/auth/session_manager.dart';

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
    // Initialize insights data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(insightsProvider(_params).notifier).initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = _params;
    final state = ref.watch(insightsProvider(params));
    final notifier = ref.read(insightsProvider(params).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(notifier.initialize()),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildError(state.error!, params)
              : RefreshIndicator(
                  onRefresh: () => notifier.initialize(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Period selector
                        _buildPeriodSelector(state.selectedPeriod, notifier),
                        const SizedBox(height: 24),

                        // Recovery score card (prominent)
                        if (state.latestRecoveryScore != null)
                          RecoveryScoreCard(
                            score: state.latestRecoveryScore!,
                            trend: state.recoveryTrend,
                          ),
                        const SizedBox(height: 24),

                        // Training load chart
                        if (state.dailyLoadPoints.isNotEmpty) ...[
                          _buildSectionHeader('Training Load (7 Days)'),
                          const SizedBox(height: 12),
                          TrainingLoadChart(
                            dailyLoads: state.dailyLoadPoints.length >= 7
                                ? state.dailyLoadPoints
                                    .skip(state.dailyLoadPoints.length - 7)
                                    .toList()
                                : state.dailyLoadPoints,
                            loadRatio: state.loadRatio,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // VO2 max trend with forecast
                        if (_hasForecast(state.forecasts, 'vo2max')) ...[
                          _buildSectionHeader('VO2 Max Trend & Forecast'),
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

                        // AI weekly summary
                        _buildSectionHeader('AI Weekly Summary'),
                        const SizedBox(height: 12),
                        if (state.currentInsight != null)
                          _buildAISummaryCard(state.currentInsight!),
                        if (state.currentInsight == null &&
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
                        const SizedBox(height: 24),

                        // Baseline comparison
                        _buildBaselineComparison(state),
                        const SizedBox(height: 24),

                        // Recalculate button
                        ElevatedButton.icon(
                          onPressed: () => _showRecalculateDialog(context, notifier),
                          icon: const Icon(Icons.calculate),
                          label: const Text('Recalculate Forecasts'),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildVO2MaxChart(InsightsState state) {
    final forecast = state.forecasts.firstWhere(
      (f) => f.metricType == 'vo2max',
      orElse: () => state.forecasts.first,
    );

    // Generate sample data points (would come from metric trends)
    final dataPoints = <DataPoint>[
      DataPoint(date: DateTime.now().subtract(const Duration(days: 30)), value: 42.0),
      DataPoint(date: DateTime.now().subtract(const Duration(days: 23)), value: 42.5),
      DataPoint(date: DateTime.now().subtract(const Duration(days: 16)), value: 43.0),
      DataPoint(date: DateTime.now().subtract(const Duration(days: 9)), value: 43.2),
      DataPoint(date: DateTime.now().subtract(const Duration(days: 2)), value: 43.8),
    ];

    return TrendChartWidget(
      dataPoints: dataPoints,
      forecast: forecast,
      yAxisLabel: 'VO2 Max',
      color: Colors.blue,
    );
  }

  Widget _buildSleepTrend(InsightsState state) {
    // Placeholder - would use actual sleep data
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('Sleep trend chart placeholder'),
      ),
    );
  }

  Widget _buildStressTrend(InsightsState state) {
    // Placeholder - would use actual stress data
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

  Widget _buildAISummaryCard(InsightEntity insight) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  insight.periodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (insight.aiModel != null)
                  Chip(
                    label: Text(insight.aiModel!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.summaryText,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateNarrativeButton(InsightsNotifier notifier) {
    return OutlinedButton.icon(
      onPressed: () => notifier.generateInsightNarrative(),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Generate AI Summary'),
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
