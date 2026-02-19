import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:welltrack/features/health/data/health_repository.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';
import 'package:welltrack/features/health/presentation/widgets/metric_chart.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';
import 'package:welltrack/shared/core/theme/app_colors.dart';

class WeightBodyScreen extends ConsumerStatefulWidget {
  final String profileId;

  const WeightBodyScreen({super.key, required this.profileId});

  @override
  ConsumerState<WeightBodyScreen> createState() => _WeightBodyScreenState();
}

class _WeightBodyScreenState extends ConsumerState<WeightBodyScreen> {
  List<HealthMetricEntity> _weightMetrics = [];
  HealthMetricEntity? _latestBodyFat;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(healthRepositoryProvider);
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final results = await Future.wait([
        repo.getMetrics(
          widget.profileId,
          MetricType.weight,
          startDate: thirtyDaysAgo,
          endDate: now,
        ),
        repo.getMetrics(widget.profileId, MetricType.body_fat),
      ]);

      if (mounted) {
        setState(() {
          _weightMetrics = results[0];
          _latestBodyFat = results[1].isNotEmpty ? results[1].first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<DataPoint> _weightDataPoints() {
    // One reading per day (latest value for the day)
    final Map<String, double> daily = {};
    for (final m in _weightMetrics) {
      final key = DateFormat('yyyy-MM-dd').format(m.startTime);
      final val = m.valueNum;
      if (val == null || val <= 0) continue;
      daily[key] = val; // last wins (metrics are sorted descending)
    }

    return daily.entries.map((e) {
      return DataPoint(date: DateTime.parse(e.key), value: e.value);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  _TrendDirection get _trend {
    final points = _weightDataPoints();
    if (points.length < 2) return _TrendDirection.stable;

    // Compare first third average to last third average
    final third = (points.length / 3).ceil().clamp(1, points.length);
    final firstAvg = points.take(third).fold<double>(0, (s, p) => s + p.value) / third;
    final lastAvg = points.skip(points.length - third).fold<double>(0, (s, p) => s + p.value) / third;
    final diff = lastAvg - firstAvg;

    if (diff.abs() < 0.3) return _TrendDirection.stable;
    return diff > 0 ? _TrendDirection.up : _TrendDirection.down;
  }

  double? get _currentWeight {
    final points = _weightDataPoints();
    return points.isNotEmpty ? points.last.value : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Weight & Body')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Current weight hero
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.monitor_weight_outlined,
                                size: 40,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currentWeight?.toStringAsFixed(1) ?? '--',
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'kg',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildTrendBadge(theme),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weight trend chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last 30 Days', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 16),
                              MetricChart(
                                data: _weightDataPoints(),
                                label: 'weight',
                                color: AppColors.secondary,
                                mode: ChartMode.line,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Body fat card
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.percent,
                            color: AppColors.mealsTile,
                          ),
                          title: const Text('Body Fat'),
                          subtitle: _latestBodyFat != null
                              ? Text(
                                  'Last updated ${DateFormat('d MMM').format(_latestBodyFat!.startTime)}',
                                )
                              : const Text('No data recorded'),
                          trailing: Text(
                            _latestBodyFat?.valueNum != null
                                ? '${_latestBodyFat!.valueNum!.toStringAsFixed(1)}%'
                                : '--%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTrendBadge(ThemeData theme) {
    final IconData icon;
    final String text;
    final Color badgeColor;

    switch (_trend) {
      case _TrendDirection.up:
        icon = Icons.trending_up;
        text = 'Trending up';
        badgeColor = AppColors.warning;
      case _TrendDirection.down:
        icon = Icons.trending_down;
        text = 'Trending down';
        badgeColor = AppColors.success;
      case _TrendDirection.stable:
        icon = Icons.trending_flat;
        text = 'Stable';
        badgeColor = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: badgeColor),
          ),
        ],
      ),
    );
  }
}

enum _TrendDirection { up, down, stable }
