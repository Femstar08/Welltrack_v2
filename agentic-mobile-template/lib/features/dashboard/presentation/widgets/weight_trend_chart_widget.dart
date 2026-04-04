import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../health/data/health_repository.dart';
import '../../../health/domain/health_metric_entity.dart';
import '../../../goals/presentation/goals_provider.dart';

/// Provider that fetches the last 90 days of weight metrics.
final weightTrendProvider =
    FutureProvider.family<List<HealthMetricEntity>, String>(
        (ref, profileId) async {
  final repo = ref.watch(healthRepositoryProvider);
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 90));
  final metrics = await repo.getMetrics(
    profileId,
    MetricType.weight,
    startDate: start,
    endDate: now,
  );
  // Sort chronologically
  metrics.sort((a, b) => a.startTime.compareTo(b.startTime));
  return metrics;
});

/// 90-day weight trend line chart with optional goal target line.
class WeightTrendChartWidget extends ConsumerWidget {
  const WeightTrendChartWidget({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weightAsync = ref.watch(weightTrendProvider(profileId));
    final goalsAsync = ref.watch(goalsProvider(profileId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push('/goals'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weight Trend',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              weightAsync.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Unable to load weight data',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                data: (metrics) {
                  if (metrics.isEmpty) {
                    return _buildEmptyState(context, theme);
                  }

                  // Find body_composition / weight goal target
                  double? goalTarget;
                  final goals = goalsAsync.valueOrNull;
                  if (goals != null) {
                    for (final g in goals) {
                      if (g.metricType == 'weight' && g.isActive) {
                        goalTarget = g.targetValue;
                        break;
                      }
                    }
                  }

                  return SizedBox(
                    height: 160,
                    child: _buildChart(theme, metrics, goalTarget),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No weight data yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/weight/log'),
              child: const Text('Log your first weight'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    ThemeData theme,
    List<HealthMetricEntity> metrics,
    double? goalTarget,
  ) {
    final spots = <FlSpot>[];
    final dateLabels = <int, String>{};
    final firstDate = metrics.first.startTime;

    for (final m in metrics) {
      if (m.valueNum == null) continue;
      final dayOffset =
          m.startTime.difference(firstDate).inDays.toDouble();
      spots.add(FlSpot(dayOffset, m.valueNum!));
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No valid weight readings',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Build date labels for first, middle, and last points
    if (spots.length >= 2) {
      dateLabels[spots.first.x.toInt()] =
          DateFormat('d MMM').format(firstDate);
      final lastDate = firstDate.add(Duration(days: spots.last.x.toInt()));
      dateLabels[spots.last.x.toInt()] =
          DateFormat('d MMM').format(lastDate);
      if (spots.length >= 3) {
        final midIdx = spots.length ~/ 2;
        final midDay = spots[midIdx].x.toInt();
        final midDate = firstDate.add(Duration(days: midDay));
        dateLabels[midDay] = DateFormat('d MMM').format(midDate);
      }
    }

    // Calculate y-axis bounds with padding
    final values = spots.map((s) => s.y).toList();
    if (goalTarget != null) values.add(goalTarget);
    final minY = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 2;

    final primaryColor = theme.colorScheme.primary;

    final lineBars = <LineChartBarData>[
      // Weight trend line
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: primaryColor,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: spots.length <= 15,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: primaryColor,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: primaryColor.withValues(alpha: 0.08),
        ),
      ),
    ];

    // Goal target dashed line
    if (goalTarget != null) {
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(spots.first.x, goalTarget),
            FlSpot(spots.last.x, goalTarget),
          ],
          isCurved: false,
          color: theme.colorScheme.tertiary.withValues(alpha: 0.6),
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: [6, 4],
        ),
      );
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == minY || value == maxY) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final label = dateLabels[value.toInt()];
                if (label == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.barIndex > 0) return null; // skip goal line
                final date = firstDate.add(Duration(days: spot.x.toInt()));
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} kg\n${DateFormat('d MMM').format(date)}',
                  TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}
