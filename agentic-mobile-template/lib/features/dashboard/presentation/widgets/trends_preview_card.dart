import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:welltrack/features/dashboard/presentation/dashboard_home_provider.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';

/// Section 4: Mini sparkline chart with 7-day trend data.
class TrendsPreviewCard extends StatelessWidget {
  final List<DataPoint> trendData;
  final String trendLabel;
  final TrendDirection trendDirection;

  const TrendsPreviewCard({
    super.key,
    required this.trendData,
    required this.trendLabel,
    required this.trendDirection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trendLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _TrendChip(direction: trendDirection),
              ],
            ),
            const SizedBox(height: 16),

            // Chart or placeholder
            trendData.length >= 2
                ? SizedBox(
                    height: 120,
                    child: _buildChart(theme),
                  )
                : SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Not enough data yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(ThemeData theme) {
    final spots = trendData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    final primaryColor = theme.colorScheme.primary;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: primaryColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final TrendDirection direction;

  const _TrendChip({required this.direction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String label;
    final Color color;
    final IconData icon;

    switch (direction) {
      case TrendDirection.up:
        label = 'Up';
        color = const Color(0xFF4CAF50);
        icon = Icons.trending_up;
      case TrendDirection.down:
        label = 'Down';
        color = const Color(0xFFEF5350);
        icon = Icons.trending_down;
      case TrendDirection.stable:
        label = 'Stable';
        color = theme.colorScheme.onSurfaceVariant;
        icon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
