import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:welltrack/features/insights/domain/training_load_entity.dart';

/// Training Load Chart
/// 7-day bar chart with recovery ratio overlay
class TrainingLoadChart extends StatelessWidget {
  final List<DailyLoadPoint> dailyLoads;
  final double? loadRatio;

  const TrainingLoadChart({
    super.key,
    required this.dailyLoads,
    this.loadRatio,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyLoads.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(_buildChartData()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Load',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                _getTotalLoad().toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (loadRatio != null) _buildLoadRatioIndicator(),
      ],
    );
  }

  Widget _buildLoadRatioIndicator() {
    final ratio = loadRatio!;
    final isWarning = ratio > 1.3;
    final isModerate = ratio > 1.15;

    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    if (isWarning) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
      icon = Icons.warning;
      label = 'Overreaching';
    } else if (isModerate) {
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      icon = Icons.info;
      label = 'Increased';
    } else {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
      icon = Icons.check_circle;
      label = 'Balanced';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(ratio * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No training data available',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _buildChartData() {
    final maxLoad = dailyLoads.isEmpty
        ? 100.0
        : dailyLoads.map((d) => d.load).reduce((a, b) => a > b ? a : b);
    final upperBound = maxLoad * 1.2;

    return BarChartData(
      maxY: upperBound,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final load = dailyLoads[group.x.toInt()];
            return BarTooltipItem(
              '${load.dateLabel}\n',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: 'Load: ${load.load.toStringAsFixed(0)}\n',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                if (load.workoutCount > 0)
                  TextSpan(
                    text: '${load.workoutCount} workout${load.workoutCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < dailyLoads.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dailyLoads[index].dateLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
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
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: upperBound / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      barGroups: dailyLoads.asMap().entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: entry.value.load,
              color: _getColorForLoad(entry.value),
              width: 24,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: upperBound,
                color: Colors.grey.shade100,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getColorForLoad(DailyLoadPoint load) {
    // Color intensity based on load and intensity
    if (load.load == 0) return Colors.grey.shade300;

    if (load.avgIntensity >= 1.5) {
      return Colors.red.shade400; // High intensity
    } else if (load.avgIntensity >= 1.0) {
      return Colors.orange.shade400; // Moderate intensity
    } else {
      return Colors.blue.shade400; // Light intensity
    }
  }

  double _getTotalLoad() {
    return dailyLoads.fold<double>(0, (sum, load) => sum + load.load);
  }
}
