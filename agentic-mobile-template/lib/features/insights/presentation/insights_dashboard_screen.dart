import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/insights/presentation/insights_provider.dart';
import 'package:welltrack/features/insights/presentation/widgets/recovery_score_card.dart';
import 'package:welltrack/features/insights/presentation/widgets/training_load_chart.dart';
import 'package:welltrack/features/insights/presentation/widgets/trend_chart_widget.dart';
import 'package:welltrack/features/insights/domain/insight_entity.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';

/// Insights Dashboard Screen
/// Main performance intelligence dashboard
class InsightsDashboardScreen extends ConsumerStatefulWidget {
  final String profileId;

  const InsightsDashboardScreen({
    super.key,
    required this.profileId,
  });

  @override
  ConsumerState<InsightsDashboardScreen> createState() =>
      _InsightsDashboardScreenState();
}

class _InsightsDashboardScreenState
    extends ConsumerState<InsightsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize insights data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(insightsProvider(widget.profileId).notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider(widget.profileId));
    final notifier = ref.read(insightsProvider(widget.profileId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.initialize(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildError(state.error!)
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
                        if (state.currentInsight != null) ...[
                          _buildSectionHeader('AI Weekly Summary'),
                          const SizedBox(height: 12),
                          _buildAISummaryCard(state.currentInsight!),
                          const SizedBox(height: 24),
                        ],

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

  Widget _buildBaselineComparison(InsightsState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Baseline Comparison',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'vs your first 14 days',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Baseline comparison data will be displayed here.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
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
                ref.read(insightsProvider(widget.profileId).notifier).initialize();
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
