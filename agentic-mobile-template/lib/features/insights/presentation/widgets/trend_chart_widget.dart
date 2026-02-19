import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/forecast_entity.dart';

/// Trend Chart Widget
/// Reusable line chart with optional forecast projection
class TrendChartWidget extends StatelessWidget {

  const TrendChartWidget({
    super.key,
    required this.dataPoints,
    this.forecast,
    required this.yAxisLabel,
    this.color = Colors.blue,
    this.minY,
    this.maxY,
  });
  final List<DataPoint> dataPoints;
  final ForecastEntity? forecast;
  final String yAxisLabel;
  final Color color;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forecast != null) _buildForecastInfo(),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(_buildChartData()),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastInfo() {
    if (forecast == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.timeline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              forecast!.projectionMessage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (forecast!.confidence != ForecastConfidence.low)
            Chip(
              label: Text(
                forecast!.confidence.name.toUpperCase(),
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: _getConfidenceColor(forecast!.confidence),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData() {
    final spots = dataPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    // Calculate forecast spots if available
    final forecastSpots = <FlSpot>[];
    if (forecast != null && forecast!.isAchievable) {
      final lastDataIndex = spots.length - 1;

      // Add 30 days of forecast
      for (int i = 1; i <= 30; i++) {
        final x = lastDataIndex + i.toDouble();
        final y = forecast!.slope * (dataPoints.length + i) + forecast!.intercept;
        forecastSpots.add(FlSpot(x, y));
      }
    }

    // Calculate Y axis range
    final allValues = spots.map((s) => s.y).toList();
    if (forecastSpots.isNotEmpty) {
      allValues.addAll(forecastSpots.map((s) => s.y));
    }

    final minValue = minY ?? allValues.reduce((a, b) => a < b ? a : b);
    final maxValue = maxY ?? allValues.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final padding = range * 0.1;

    return LineChartData(
      minY: minValue - padding,
      maxY: maxValue + padding,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: range / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: Text(
            yAxisLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
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
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: (spots.length / 5).ceilToDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < dataPoints.length) {
                final date = dataPoints[index].date;
                return Text(
                  '${date.month}/${date.day}',
                  style: const TextStyle(fontSize: 10),
                );
              }
              return const Text('');
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      lineBarsData: [
        // Actual data line
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Forecast line (dashed)
        if (forecastSpots.isNotEmpty)
          LineChartBarData(
            spots: [spots.last, ...forecastSpots],
            isCurved: true,
            color: color.withValues(alpha: 0.5),
            barWidth: 2,
            isStrokeCapRound: true,
            dashArray: [8, 4],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final date = spot.spotIndex < dataPoints.length
                  ? dataPoints[spot.spotIndex].date
                  : null;
              final dateStr = date != null ? '${date.month}/${date.day}' : 'Forecast';
              return LineTooltipItem(
                '$dateStr\n${spot.y.toStringAsFixed(1)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Color _getConfidenceColor(ForecastConfidence confidence) {
    switch (confidence) {
      case ForecastConfidence.high:
        return Colors.green.shade100;
      case ForecastConfidence.medium:
        return Colors.amber.shade100;
      case ForecastConfidence.low:
        return Colors.red.shade100;
    }
  }
}
