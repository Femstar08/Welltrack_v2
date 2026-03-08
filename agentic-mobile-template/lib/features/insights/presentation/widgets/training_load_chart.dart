import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/training_load_entity.dart';

/// Training Load Chart
/// 7-day bar chart with 4-week average reference line and load ratio display
class TrainingLoadChart extends StatelessWidget {

  const TrainingLoadChart({
    super.key,
    required this.dailyLoads,
    this.loadRatio,
    this.weeklyLoadTotal,
    this.lastWeekLoadTotal,
    this.fourWeekAverage,
  });
  final List<DailyLoadPoint> dailyLoads;

  /// Ratio of current week load vs 4-week average (null if no history)
  final double? loadRatio;

  /// Current week total load
  final double? weeklyLoadTotal;

  /// Previous week total load
  final double? lastWeekLoadTotal;

  /// Average weekly load over past 4 weeks
  final double? fourWeekAverage;

  /// Daily average derived from 4-week average (used for reference line)
  double? get _fourWeekDailyAvg =>
      fourWeekAverage != null ? fourWeekAverage! / 7 : null;

  @override
  Widget build(BuildContext context) {
    if (dailyLoads.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
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
          SizedBox(
            height: 200,
            child: BarChart(_buildChartData()),
          ),
          if (loadRatio != null) ...[
            const SizedBox(height: 12),
            _buildLoadRatioRow(),
          ],
          if (weeklyLoadTotal != null ||
              lastWeekLoadTotal != null ||
              fourWeekAverage != null) ...[
            const SizedBox(height: 8),
            _buildWeeklySummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
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
      ],
    );
  }

  /// Prominent load ratio display below the chart with colour coding
  Widget _buildLoadRatioRow() {
    final ratio = loadRatio!;
    final Color ratioColor;
    final String ratioLabel;
    final IconData ratioIcon;

    if (ratio > 1.5) {
      ratioColor = Colors.red.shade700;
      ratioLabel = 'High';
      ratioIcon = Icons.warning_rounded;
    } else if (ratio > 1.3) {
      ratioColor = Colors.orange.shade700;
      ratioLabel = 'Moderate';
      ratioIcon = Icons.info_outline_rounded;
    } else {
      ratioColor = Colors.green.shade700;
      ratioLabel = 'Normal';
      ratioIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ratioColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ratioColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(ratioIcon, size: 18, color: ratioColor),
          const SizedBox(width: 8),
          Text(
            'Load ratio vs 4-wk avg:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            '${ratio.toStringAsFixed(2)}x',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ratioColor,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ratioColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ratioLabel,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Weekly summary row: This week | Last week | 4-wk avg
  Widget _buildWeeklySummary() {
    return Row(
      children: [
        _buildSummaryStat(
          label: 'This week',
          value: weeklyLoadTotal?.toStringAsFixed(0) ?? '—',
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 8),
        _buildSummaryStat(
          label: 'Last week',
          value: lastWeekLoadTotal?.toStringAsFixed(0) ?? '—',
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 8),
        _buildSummaryStat(
          label: '4-wk avg',
          value: fourWeekAverage?.toStringAsFixed(0) ?? '—',
          color: Colors.orange.shade700,
        ),
      ],
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
    final rawMax = dailyLoads.isEmpty
        ? 0.0
        : dailyLoads.map((d) => d.load).reduce((a, b) => a > b ? a : b);
    final maxLoad = rawMax < 1.0 ? 100.0 : rawMax;
    final upperBound = maxLoad * 1.2;
    final dailyAvg = _fourWeekDailyAvg;

    return BarChartData(
      maxY: upperBound,
      extraLinesData: dailyAvg != null && dailyAvg > 0
          ? ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: dailyAvg,
                  color: Colors.orange.shade600,
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    labelResolver: (_) => '4-wk avg',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : null,
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
