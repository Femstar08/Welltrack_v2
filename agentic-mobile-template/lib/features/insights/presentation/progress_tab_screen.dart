import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/auth/session_manager.dart';
import 'insights_provider.dart';
import '../domain/recovery_score_entity.dart';
import '../domain/training_load_entity.dart';
import '../domain/forecast_entity.dart';
import '../data/performance_engine.dart';
import '../../../shared/core/widgets/medical_disclaimer.dart';

/// Progress tab — recovery trends, VO2 max, training load, sleep, AI insights.
class ProgressTabScreen extends ConsumerStatefulWidget {
  const ProgressTabScreen({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<ProgressTabScreen> createState() => _ProgressTabScreenState();
}

class _ProgressTabScreenState extends ConsumerState<ProgressTabScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserIdProvider) ?? '';
      if (userId.isNotEmpty) {
        unawaited(ref
            .read(insightsProvider(
                    (profileId: widget.profileId, userId: userId))
                .notifier)
            .initialize());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(
        insightsProvider((profileId: widget.profileId, userId: userId)));

    return Scaffold(
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(insightsProvider(
                          (profileId: widget.profileId, userId: userId))
                      .notifier)
                  .loadData(),
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: MediaQuery.paddingOf(context).top + 16,
                        bottom: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryDark,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your health trends over time',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recovery Trend
                  SliverToBoxAdapter(
                    child: _RecoveryTrendCard(
                      scores: state.recoveryScores,
                      latest: state.latestRecoveryScore,
                    ),
                  ),

                  // VO2 Max
                  SliverToBoxAdapter(
                    child: _Vo2MaxCard(
                      dataPoints: state.metricTrends['vo2max'] ?? [],
                      slope: state.vo2Slope,
                    ),
                  ),

                  // Training Load
                  SliverToBoxAdapter(
                    child: _TrainingLoadCard(
                      weeklyLoad: state.weeklyLoadTotal,
                      lastWeekLoad: state.lastWeekLoadTotal,
                      loadTrendPercent: state.loadTrendPercent,
                      dailyPoints: state.fourWeekDailyLoadPoints,
                      risk: state.overtrainingRisk,
                    ),
                  ),

                  // Sleep Quality
                  SliverToBoxAdapter(
                    child: _SleepQualityCard(
                      avg7Day: state.sleepAvg7Day,
                      avg14Day: state.sleepAvg14Day,
                      trend: state.stressTrend,
                    ),
                  ),

                  // AI Narrative
                  if (state.insights.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _AiNarrativeCard(
                        narrative: state.insights.first.summaryText,
                      ),
                    ),

                  const SliverToBoxAdapter(child: MedicalDisclaimer()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

// ── Recovery Trend ──────────────────────────────────────────────

class _RecoveryTrendCard extends StatelessWidget {
  const _RecoveryTrendCard({required this.scores, this.latest});
  final List<RecoveryScoreEntity> scores;
  final RecoveryScoreEntity? latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = latest?.recoveryScore;
    final color = score != null
        ? AppColors.getRecoveryColor(score)
        : AppColors.textSecondaryDark;
    final label = score != null
        ? (score >= 80
            ? 'Excellent'
            : score >= 60
                ? 'Good'
                : score >= 40
                    ? 'Moderate'
                    : 'Low')
        : 'No data';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECOVERY TREND',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            if (score != null) ...[
              Row(
                children: [
                  Text('${score.toInt()}',
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(width: 8),
                  Text('▲ $label',
                      style: theme.textTheme.bodySmall?.copyWith(color: color)),
                ],
              ),
              const SizedBox(height: 12),
              // 7-day sparkline
              SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: scores.take(7).map((s) {
                    final h = (s.recoveryScore / 100 * 40).clamp(4.0, 40.0);
                    final c = AppColors.getRecoveryColor(s.recoveryScore);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else
              Text('Log sleep and workouts to see your recovery trend',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondaryDark)),
          ],
        ),
      ),
    );
  }
}

// ── VO2 Max ─────────────────────────────────────────────────────

class _Vo2MaxCard extends StatelessWidget {
  const _Vo2MaxCard({required this.dataPoints, this.slope});
  final List<DataPoint> dataPoints;
  final double? slope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVo2 = dataPoints.isNotEmpty ? dataPoints.last.value : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VO₂ MAX',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            if (currentVo2 != null) ...[
              Row(
                children: [
                  Text(currentVo2.toStringAsFixed(1),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('ml/kg/min',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondaryDark)),
                  const Spacer(),
                  if (slope != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (slope! > 0
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFEF5350))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        slope! > 0 ? '↑ Improving' : '↓ Declining',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: slope! > 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFEF5350),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dataPoints.map((dp) {
                    final minV = dataPoints
                        .map((d) => d.value)
                        .reduce((a, b) => a < b ? a : b);
                    final maxV = dataPoints
                        .map((d) => d.value)
                        .reduce((a, b) => a > b ? a : b);
                    final range = maxV - minV;
                    final h = range > 0
                        ? ((dp.value - minV) / range * 50 + 10)
                        : 30.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Keep training — more data needed',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondaryDark)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Training Load ───────────────────────────────────────────────

class _TrainingLoadCard extends StatelessWidget {
  const _TrainingLoadCard({
    required this.weeklyLoad,
    required this.lastWeekLoad,
    this.loadTrendPercent,
    required this.dailyPoints,
    required this.risk,
  });
  final double weeklyLoad;
  final double lastWeekLoad;
  final double? loadTrendPercent;
  final List<DailyLoadPoint> dailyPoints;
  final OvertrainingRisk risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendColor = (loadTrendPercent ?? 0) > 20
        ? const Color(0xFFFF9800)
        : AppColors.textSecondaryDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRAINING LOAD',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${weeklyLoad.toInt()}',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('AU this week',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondaryDark)),
                const Spacer(),
                if (loadTrendPercent != null)
                  Text(
                    '${loadTrendPercent! > 0 ? '+' : ''}${loadTrendPercent!.toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: trendColor, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            if (risk == OvertrainingRisk.high) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text('High load — consider a rest day',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.warning)),
                  ],
                ),
              ),
            ],
            if (dailyPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dailyPoints.map((dp) {
                    final maxLoad = dailyPoints
                        .map((d) => d.load)
                        .reduce((a, b) => a > b ? a : b);
                    final h =
                        maxLoad > 0 ? (dp.load / maxLoad * 45 + 5) : 5.0;
                    final isThisWeek = dp.date
                        .isAfter(DateTime.now().subtract(const Duration(days: 7)));
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isThisWeek
                                ? AppColors.primary.withValues(alpha: 0.7)
                                : AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sleep Quality ───────────────────────────────────────────────

class _SleepQualityCard extends StatelessWidget {
  const _SleepQualityCard({this.avg7Day, this.avg14Day, required this.trend});
  final double? avg7Day;
  final double? avg14Day;
  final TrendDirection trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendLabel = trend == TrendDirection.improving
        ? '▲ Improving'
        : trend == TrendDirection.worsening
            ? '▼ Declining'
            : '— Stable';
    final trendColor = trend == TrendDirection.improving
        ? const Color(0xFF4CAF50)
        : trend == TrendDirection.worsening
            ? const Color(0xFFEF5350)
            : AppColors.textSecondaryDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SLEEP QUALITY',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                _SleepStat(
                    label: '7-day avg',
                    value: avg7Day != null
                        ? '${avg7Day!.toStringAsFixed(1)}h'
                        : '--'),
                const SizedBox(width: 24),
                _SleepStat(
                    label: '14-day avg',
                    value: avg14Day != null
                        ? '${avg14Day!.toStringAsFixed(1)}h'
                        : '--'),
                const Spacer(),
                Text(trendLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: trendColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStat extends StatelessWidget {
  const _SleepStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondaryDark)),
      ],
    );
  }
}

// ── AI Narrative ────────────────────────────────────────────────

class _AiNarrativeCard extends StatelessWidget {
  const _AiNarrativeCard({required this.narrative});
  final String narrative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.primary.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('WellTrack Insight',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(narrative,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}
