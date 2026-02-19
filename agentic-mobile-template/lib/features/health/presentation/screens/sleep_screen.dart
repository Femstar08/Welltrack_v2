import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:welltrack/features/health/data/health_repository.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';
import 'package:welltrack/shared/core/theme/app_colors.dart';

class SleepScreen extends ConsumerStatefulWidget {
  final String profileId;

  const SleepScreen({super.key, required this.profileId});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  List<HealthMetricEntity> _metrics = [];
  bool _isLoading = true;
  String? _error;

  // Sleep stage colors
  static const _deepColor = Color(0xFF1A237E);
  static const _lightColor = Color(0xFF5C6BC0);
  static const _remColor = Color(0xFF7E57C2);
  static const _awakeColor = Color(0xFFFFCA28);

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
        MetricType.sleep,
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

  /// Group metrics by night, extract stage data from rawPayload
  List<_NightData> _getNightlyData() {
    final Map<String, _NightData> nights = {};

    for (final m in _metrics) {
      final key = DateFormat('yyyy-MM-dd').format(m.startTime);
      final totalMin = m.valueNum ?? 0;
      final stages = m.rawPayload?['stages'] as Map<String, dynamic>?;

      final existing = nights[key];
      if (existing != null && existing.totalMinutes >= totalMin) continue;

      nights[key] = _NightData(
        date: DateTime.parse(key),
        totalMinutes: totalMin,
        deepMinutes: (stages?['deep'] as num?)?.toDouble() ?? 0,
        lightMinutes: (stages?['light'] as num?)?.toDouble() ?? 0,
        remMinutes: (stages?['rem'] as num?)?.toDouble() ?? 0,
        awakeMinutes: (stages?['awake'] as num?)?.toDouble() ?? 0,
      );
    }

    final list = nights.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  String _formatMinutes(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return '${h}h ${m}m';
  }

  double get _nightlyAverage {
    final nights = _getNightlyData();
    if (nights.isEmpty) return 0;
    return nights.fold<double>(0, (s, n) => s + n.totalMinutes) / nights.length;
  }

  Map<String, double> get _stagePercentages {
    final nights = _getNightlyData();
    if (nights.isEmpty) return {};
    double deep = 0, light = 0, rem = 0, awake = 0, total = 0;
    for (final n in nights) {
      deep += n.deepMinutes;
      light += n.lightMinutes;
      rem += n.remMinutes;
      awake += n.awakeMinutes;
      total += n.totalMinutes;
    }
    if (total == 0) return {};
    return {
      'Deep': deep / total * 100,
      'Light': light / total * 100,
      'REM': rem / total * 100,
      'Awake': awake / total * 100,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Nightly average hero
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.bedtime_outlined, size: 40, color: AppColors.sleepTile),
                              const SizedBox(height: 8),
                              Text(
                                _formatMinutes(_nightlyAverage),
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sleepTile,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'nightly average',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stacked bar chart
                      _buildStackedChart(theme),
                      const SizedBox(height: 16),

                      // Stage breakdown
                      _buildStageBreakdown(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStackedChart(ThemeData theme) {
    final nights = _getNightlyData();
    if (nights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_outlined, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text(
                    'No data yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sync your health data to see sleep here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Convert minutes to hours for display
    final maxHours = nights
        .map((n) => n.totalMinutes / 60)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 Nights', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxHours * 1.15).ceilToDouble(),
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final night = nights[group.x.toInt()];
                        return BarTooltipItem(
                          _formatMinutes(night.totalMinutes),
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${value.toInt()}h',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= nights.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('E').format(nights[idx].date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: List.generate(nights.length, (i) {
                    final n = nights[i];
                    final deepH = n.deepMinutes / 60;
                    final lightH = n.lightMinutes / 60;
                    final remH = n.remMinutes / 60;
                    final awakeH = n.awakeMinutes / 60;
                    final hasStages = n.deepMinutes > 0 ||
                        n.lightMinutes > 0 ||
                        n.remMinutes > 0 ||
                        n.awakeMinutes > 0;

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: hasStages
                              ? deepH + lightH + remH + awakeH
                              : n.totalMinutes / 60,
                          width: nights.length <= 7 ? 24 : 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          rodStackItems: hasStages
                              ? [
                                  BarChartRodStackItem(0, deepH, _deepColor),
                                  BarChartRodStackItem(deepH, deepH + lightH, _lightColor),
                                  BarChartRodStackItem(
                                    deepH + lightH,
                                    deepH + lightH + remH,
                                    _remColor,
                                  ),
                                  BarChartRodStackItem(
                                    deepH + lightH + remH,
                                    deepH + lightH + remH + awakeH,
                                    _awakeColor,
                                  ),
                                ]
                              : null,
                          color: hasStages ? Colors.transparent : AppColors.sleepTile,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _legendDot('Deep', _deepColor, theme),
                _legendDot('Light', _lightColor, theme),
                _legendDot('REM', _remColor, theme),
                _legendDot('Awake', _awakeColor, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _buildStageBreakdown(ThemeData theme) {
    final pcts = _stagePercentages;
    if (pcts.isEmpty) return const SizedBox.shrink();

    final stageColors = {
      'Deep': _deepColor,
      'Light': _lightColor,
      'REM': _remColor,
      'Awake': _awakeColor,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stage Breakdown (Average)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...pcts.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(e.key, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: e.value / 100,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: stageColors[e.key] ?? AppColors.primary,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${e.value.toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NightData {
  final DateTime date;
  final double totalMinutes;
  final double deepMinutes;
  final double lightMinutes;
  final double remMinutes;
  final double awakeMinutes;

  const _NightData({
    required this.date,
    required this.totalMinutes,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
  });
}
