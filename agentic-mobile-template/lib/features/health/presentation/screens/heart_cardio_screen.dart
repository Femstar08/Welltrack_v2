import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/health_repository.dart';
import '../../domain/health_metric_entity.dart';
import '../widgets/metric_chart.dart';
import '../../../insights/domain/forecast_entity.dart';
import '../../../../shared/core/theme/app_colors.dart';

class HeartCardioScreen extends ConsumerStatefulWidget {

  const HeartCardioScreen({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<HeartCardioScreen> createState() => _HeartCardioScreenState();
}

class _HeartCardioScreenState extends ConsumerState<HeartCardioScreen> {
  List<HealthMetricEntity> _hrMetrics = [];
  HealthMetricEntity? _latestVo2max;
  HealthMetricEntity? _latestHrv;
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

      final results = await Future.wait([
        repo.getMetrics(
          widget.profileId,
          MetricType.hr,
          startDate: sevenDaysAgo,
          endDate: now,
        ),
        repo.getMetrics(widget.profileId, MetricType.vo2max),
        repo.getMetrics(widget.profileId, MetricType.hrv),
      ]);

      if (mounted) {
        setState(() {
          _hrMetrics = results[0];
          _latestVo2max = results[1].isNotEmpty ? results[1].first : null;
          _latestHrv = results[2].isNotEmpty ? results[2].first : null;
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

  List<DataPoint> _hrDataPoints() {
    // Take one reading per day (prefer lowest = resting HR)
    final Map<String, double> dailyRhr = {};
    for (final m in _hrMetrics) {
      final key = '${m.startTime.year}-${m.startTime.month.toString().padLeft(2, '0')}-${m.startTime.day.toString().padLeft(2, '0')}';
      final val = m.valueNum ?? 0;
      if (val <= 0) continue;
      if (!dailyRhr.containsKey(key) || val < dailyRhr[key]!) {
        dailyRhr[key] = val;
      }
    }

    return dailyRhr.entries.map((e) {
      return DataPoint(date: DateTime.parse(e.key), value: e.value);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Heart & Cardio')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Key metrics row
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard(
                            theme,
                            icon: Icons.favorite_outline,
                            label: 'Resting HR',
                            value: _latestRhr,
                            unit: 'bpm',
                            color: Colors.redAccent,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard(
                            theme,
                            icon: Icons.air_outlined,
                            label: 'VO\u2082 Max',
                            value: _latestVo2max?.valueNum != null
                                ? _latestVo2max!.valueNum!.toStringAsFixed(1)
                                : null,
                            unit: 'ml/kg/min',
                            color: AppColors.secondary,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // HRV card
                      if (_latestHrv != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.timeline, color: AppColors.primary),
                            title: const Text('Heart Rate Variability'),
                            subtitle: const Text('Latest reading'),
                            trailing: Text(
                              '${_latestHrv!.valueNum?.toStringAsFixed(0) ?? '--'} ms',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // RHR trend chart
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Resting HR Trend', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Last 7 days',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              MetricChart(
                                data: _hrDataPoints(),
                                label: 'resting heart rate',
                                color: Colors.redAccent,
                                mode: ChartMode.line,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // VO2 Max entry button
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/health/vo2max-entry'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Update VO\u2082 Max Reading'),
                      ),
                    ],
                  ),
                ),
    );
  }

  String? get _latestRhr {
    final points = _hrDataPoints();
    if (points.isEmpty) return null;
    return points.last.value.toStringAsFixed(0);
  }

  Widget _buildMetricCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String? value,
    required String unit,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value ?? '--',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(unit, style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            )),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}
