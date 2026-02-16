import 'package:flutter/material.dart';
import 'package:welltrack/features/dashboard/presentation/dashboard_home_provider.dart';

/// Section 1: Greeting + Primary Metric hero card.
class TodaySummaryCard extends StatelessWidget {
  final String displayName;
  final PrimaryMetricData? primaryMetric;

  const TodaySummaryCard({
    super.key,
    required this.displayName,
    this.primaryMetric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time-based greeting
          Text(
            _getGreeting(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Primary metric card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: primaryMetric != null && primaryMetric!.value != '---'
                ? _buildMetricContent(theme)
                : _buildCalibratingContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricContent(ThemeData theme) {
    final metric = primaryMetric!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              metric.icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              metric.label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              metric.value,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (metric.unit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                metric.unit,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 8),
            _buildTrendIcon(theme, metric.trend),
          ],
        ),
      ],
    );
  }

  Widget _buildCalibratingContent(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              primaryMetric?.icon ?? Icons.favorite_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              primaryMetric?.label ?? 'Primary Metric',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Calibrating...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'We need a few days of data',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendIcon(ThemeData theme, TrendDirection trend) {
    final IconData icon;
    final Color color;
    switch (trend) {
      case TrendDirection.up:
        icon = Icons.trending_up;
        color = const Color(0xFF4CAF50);
      case TrendDirection.down:
        icon = Icons.trending_down;
        color = const Color(0xFFEF5350);
      case TrendDirection.stable:
        icon = Icons.trending_flat;
        color = theme.colorScheme.onSurfaceVariant;
    }
    return Icon(icon, size: 20, color: color);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}
