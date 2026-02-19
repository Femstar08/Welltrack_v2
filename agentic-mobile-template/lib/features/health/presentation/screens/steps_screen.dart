import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:welltrack/features/health/data/health_repository.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';
import 'package:welltrack/features/health/presentation/widgets/metric_chart.dart';
import 'package:welltrack/features/insights/domain/forecast_entity.dart';
import 'package:welltrack/shared/core/theme/app_colors.dart';

class StepsScreen extends ConsumerStatefulWidget {
  final String profileId;

  const StepsScreen({super.key, required this.profileId});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  List<HealthMetricEntity> _metrics = [];
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
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final metrics = await repo.getMetrics(
        widget.profileId,
        MetricType.steps,
        startDate: sevenDaysAgo,
        endDate: now,
      );

      if (mounted) {
        setState(() {
          _metrics = metrics;
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

  List<DataPoint> _toDataPoints() {
    final Map<String, double> dailyTotals = {};
    for (final m in _metrics) {
      final key = DateFormat('yyyy-MM-dd').format(m.startTime);
      dailyTotals[key] = (dailyTotals[key] ?? 0) + (m.valueNum ?? 0);
    }

    final points = dailyTotals.entries.map((e) {
      return DataPoint(date: DateTime.parse(e.key), value: e.value);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return points;
  }

  double get _todaySteps {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    double total = 0;
    for (final m in _metrics) {
      if (DateFormat('yyyy-MM-dd').format(m.startTime) == today) {
        total += m.valueNum ?? 0;
      }
    }
    return total;
  }

  double get _weeklyAverage {
    final points = _toDataPoints();
    if (points.isEmpty) return 0;
    final total = points.fold<double>(0, (sum, p) => sum + p.value);
    return total / points.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Steps')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Today's steps hero card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_walk,
                                size: 40,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                NumberFormat('#,###').format(_todaySteps.toInt()),
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'steps today',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: (_todaySteps / 10000).clamp(0.0, 1.0),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                color: _todaySteps >= 10000
                                    ? AppColors.success
                                    : AppColors.primary,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${((_todaySteps / 10000) * 100).toInt().clamp(0, 100)}% of 10,000 goal',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weekly chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last 7 Days', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 16),
                              MetricChart(
                                data: _toDataPoints(),
                                label: 'steps',
                                color: AppColors.primary,
                                mode: ChartMode.bar,
                                goalValue: 10000,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weekly average card
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.show_chart, color: AppColors.secondary),
                          title: const Text('Weekly Average'),
                          trailing: Text(
                            NumberFormat('#,###').format(_weeklyAverage.toInt()),
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
}
