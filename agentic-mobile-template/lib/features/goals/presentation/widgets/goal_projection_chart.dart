import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:welltrack/features/goals/domain/goal_entity.dart';

class GoalProjectionChart extends StatelessWidget {
  final GoalEntity goal;

  const GoalProjectionChart({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final forecast = goal.forecast;
    if (forecast == null) {
      return const Center(
        child: Text('Insufficient data for projection'),
      );
    }

    final theme = Theme.of(context);
    final now = DateTime.now();

    // Build historical data points (past 30 days using slope/intercept)
    final historicalSpots = <FlSpot>[];
    final daysBack = 30;
    for (int i = daysBack; i >= 0; i--) {
      final dayOffset = -i.toDouble();
      final value = forecast.slope * (forecast.dataPoints - i) + forecast.intercept;
      if (value > 0) {
        historicalSpots.add(FlSpot(dayOffset, value));
      }
    }

    // Build projection line (from today forward)
    final projectionSpots = <FlSpot>[];
    final daysForward = forecast.projectedDate != null
        ? forecast.projectedDate!.difference(now).inDays.clamp(1, 365)
        : 90;
    for (int i = 0; i <= daysForward; i += (daysForward > 90 ? 7 : 1)) {
      final dayOffset = i.toDouble();
      final value =
          forecast.slope * (forecast.dataPoints + i) + forecast.intercept;
      projectionSpots.add(FlSpot(dayOffset, value));
    }
    // Ensure we include the endpoint
    if (projectionSpots.isNotEmpty &&
        projectionSpots.last.x != daysForward.toDouble()) {
      projectionSpots.add(FlSpot(
        daysForward.toDouble(),
        forecast.slope * (forecast.dataPoints + daysForward) +
            forecast.intercept,
      ));
    }

    // Determine Y range
    final allValues = [
      ...historicalSpots.map((s) => s.y),
      ...projectionSpots.map((s) => s.y),
      goal.targetValue,
      forecast.currentValue,
    ];
    final minY = allValues.reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.05;
    final minX = historicalSpots.isNotEmpty ? historicalSpots.first.x : -30.0;
    final maxX = projectionSpots.isNotEmpty
        ? projectionSpots.last.x
        : daysForward.toDouble();

    return LineChart(
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
            color: theme.colorScheme.outline.withOpacity(0.2),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
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
            // Target line
            HorizontalLine(
              y: goal.targetValue,
              color: Colors.red.withOpacity(0.6),
              strokeWidth: 2,
              dashArray: [8, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: TextStyle(
                  color: Colors.red.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                labelResolver: (_) => 'Target: ${goal.targetValue}',
              ),
            ),
          ],
          verticalLines: [
            // Today line
            VerticalLine(
              x: 0,
              color: theme.colorScheme.outline.withOpacity(0.4),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 10,
                ),
                labelResolver: (_) => 'Today',
              ),
            ),
            // Projected date line
            if (forecast.projectedDate != null)
              VerticalLine(
                x: forecast.projectedDate!
                    .difference(now)
                    .inDays
                    .toDouble(),
                color: Colors.orange.withOpacity(0.6),
                strokeWidth: 2,
                dashArray: [6, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.8),
                    fontSize: 10,
                  ),
                  labelResolver: (_) => 'Projected',
                ),
              ),
          ],
        ),
        lineBarsData: [
          // Historical data (solid blue line)
          if (historicalSpots.isNotEmpty)
            LineChartBarData(
              spots: historicalSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withOpacity(0.08),
              ),
            ),
          // Projection line (dashed green)
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
    );
  }
}
