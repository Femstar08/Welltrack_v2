import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/goal_entity.dart';
import '../../../insights/domain/forecast_entity.dart';

class GoalProjectionChart extends StatelessWidget {
  const GoalProjectionChart({
    super.key,
    required this.goal,
    required this.actualDataPoints,
  });

  final GoalEntity goal;
  final List<DataPoint> actualDataPoints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Need at least 7 data points for a meaningful projection
    if (actualDataPoints.length < 7) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Need at least 7 data points',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Keep logging to unlock your projection',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final forecast = goal.forecast;
    final now = DateTime.now();

    // Historical spots from real data — x = days relative to today (negative = past)
    final historicalSpots = actualDataPoints
        .map((dp) => FlSpot(
              dp.date.difference(now).inDays.toDouble(),
              dp.value,
            ))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    // Projection line from today forward using forecast regression slope
    final projectionSpots = <FlSpot>[];
    if (forecast != null) {
      final startValue = forecast.currentValue;
      final daysForward = forecast.projectedDate != null
          ? forecast.projectedDate!.difference(now).inDays.clamp(1, 365)
          : 90;
      final step = daysForward > 90 ? 7 : (daysForward > 30 ? 3 : 1);
      for (int i = 0; i <= daysForward; i += step) {
        projectionSpots.add(FlSpot(i.toDouble(), startValue + forecast.slope * i));
      }
      if (projectionSpots.isEmpty || projectionSpots.last.x != daysForward.toDouble()) {
        projectionSpots.add(FlSpot(
          daysForward.toDouble(),
          startValue + forecast.slope * daysForward,
        ));
      }
    }

    // Show warning banner if projected date is after the goal deadline
    final showDeadlineWarning = forecast?.projectedDate != null &&
        goal.deadline != null &&
        forecast!.projectedDate!.isAfter(goal.deadline!);

    final allValues = [
      ...historicalSpots.map((s) => s.y),
      ...projectionSpots.map((s) => s.y),
      goal.targetValue,
    ];
    final minY = allValues.reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.05;
    final minX = historicalSpots.isNotEmpty ? historicalSpots.first.x : -30.0;
    final maxX = projectionSpots.isNotEmpty
        ? projectionSpots.last.x
        : (forecast != null ? 90.0 : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDeadlineWarning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Projected to miss deadline',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (maxX - minX) / 4,
                    getTitlesWidget: (value, meta) {
                      final date = now.add(Duration(days: value.toInt()));
                      return Text(
                        '${date.day}/${date.month}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  // Target value — horizontal dashed red line
                  HorizontalLine(
                    y: goal.targetValue,
                    color: Colors.red.withValues(alpha: 0.6),
                    strokeWidth: 2,
                    dashArray: [8, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      labelResolver: (_) => 'Target: ${goal.targetValue}',
                    ),
                  ),
                ],
                verticalLines: [
                  // Today marker
                  VerticalLine(
                    x: 0,
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                      labelResolver: (_) => 'Today',
                    ),
                  ),
                  // Projected completion date — vertical dashed orange line
                  if (forecast?.projectedDate != null)
                    VerticalLine(
                      x: forecast!.projectedDate!
                          .difference(now)
                          .inDays
                          .toDouble(),
                      color: Colors.orange.withValues(alpha: 0.6),
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: VerticalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(
                          color: Colors.orange.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                        labelResolver: (_) => 'Projected',
                      ),
                    ),
                ],
              ),
              lineBarsData: [
                // Actual historical data — solid primary line with dots
                if (historicalSpots.isNotEmpty)
                  LineChartBarData(
                    spots: historicalSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: theme.colorScheme.primary,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                // Forecast projection — dashed green line
                if (projectionSpots.isNotEmpty)
                  LineChartBarData(
                    spots: projectionSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: Colors.green,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dashArray: [8, 4],
                    dotData: const FlDotData(show: false),
                  ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final date = now.add(Duration(days: spot.x.toInt()));
                      return LineTooltipItem(
                        '${date.day}/${date.month}\n${spot.y.toStringAsFixed(1)} ${goal.unit}',
                        TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
