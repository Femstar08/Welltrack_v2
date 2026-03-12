// lib/features/dashboard/presentation/widgets/recovery_score_dashboard_card.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../insights/data/insights_repository.dart';
import '../../../insights/domain/baseline_entity.dart';
import '../../../insights/domain/recovery_score_entity.dart';
import '../../../insights/presentation/baseline_provider.dart';

// ---------------------------------------------------------------------------
// Provider — fetches today's and yesterday's recovery score
// ---------------------------------------------------------------------------

typedef _ScorePair = ({RecoveryScoreEntity? today, RecoveryScoreEntity? yesterday});

final _recoveryScorePairProvider =
    FutureProvider.family<_ScorePair, String>((ref, profileId) async {
  final repo = ref.watch(insightsRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final scores = await repo.getRecoveryScores(
    profileId: profileId,
    startDate: yesterday,
    endDate: today,
  );

  RecoveryScoreEntity? todayScore;
  RecoveryScoreEntity? yesterdayScore;

  for (final s in scores) {
    final d = DateTime(s.scoreDate.year, s.scoreDate.month, s.scoreDate.day);
    if (d == today) todayScore = s;
    if (d == yesterday) yesterdayScore = s;
  }

  return (today: todayScore, yesterday: yesterdayScore);
});

// ---------------------------------------------------------------------------
// Provider — fetches last 7 days of recovery scores for the sparkline
// ---------------------------------------------------------------------------

final _recoverySparklineProvider =
    FutureProvider.family<List<RecoveryScoreEntity>, String>(
        (ref, profileId) async {
  final repo = ref.watch(insightsRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sevenDaysAgo = today.subtract(const Duration(days: 6));

  return repo.getRecoveryScores(
    profileId: profileId,
    startDate: sevenDaysAgo,
    endDate: today,
  );
});

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Compact recovery score card for the main dashboard.
/// Taps through to the full Insights screen.
class RecoveryScoreDashboardCard extends ConsumerStatefulWidget {
  const RecoveryScoreDashboardCard({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<RecoveryScoreDashboardCard> createState() =>
      _RecoveryScoreDashboardCardState();
}

class _RecoveryScoreDashboardCardState
    extends ConsumerState<RecoveryScoreDashboardCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load baseline status so we can show calibrating state if needed.
      unawaited(
        ref
            .read(baselineProvider(widget.profileId).notifier)
            .load(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scoreAsync =
        ref.watch(_recoveryScorePairProvider(widget.profileId));
    final baselineState = ref.watch(baselineProvider(widget.profileId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: () => context.push('/recovery-detail'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                scoreAsync.when(
                  loading: () => _buildLoading(),
                  error: (_, __) => _buildEmpty(context),
                  data: (pair) {
                    // Baseline takes precedence — show calibrating if active
                    if (!baselineState.isLoading &&
                        baselineState.isInBaselinePeriod) {
                      return _buildCalibrating(
                        context,
                        baselineState.progressPercentage,
                        baselineState.daysCompleted,
                      );
                    }
                    if (pair.today == null) {
                      return _buildEmpty(context);
                    }
                    final trend =
                        pair.today!.getTrendComparedTo(pair.yesterday);
                    return _buildScore(context, pair.today!, trend);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.favorite_outline,
            color: theme.colorScheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          'Recovery',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          size: 20,
        ),
      ],
    );
  }

  // ---------- Loading ----------

  Widget _buildLoading() {
    return const SizedBox(
      height: 40,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // ---------- Baseline calibrating ----------

  Widget _buildCalibrating(
    BuildContext context,
    double progress,
    int daysCompleted,
  ) {
    final theme = Theme.of(context);
    const total = BaselineEntity.calibrationDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Collecting your baseline — Day $daysCompleted of $total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Log sleep and workouts to calibrate your recovery score.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  // ---------- No data ----------

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No recovery data yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Log sleep and workouts to see your score.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  // ---------- Score ----------

  Widget _buildScore(
    BuildContext context,
    RecoveryScoreEntity score,
    RecoveryTrend trend,
  ) {
    final theme = Theme.of(context);
    final color = _scoreColor(score.recoveryScore);
    final sparklineAsync =
        ref.watch(_recoverySparklineProvider(widget.profileId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score circle + label/description row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Score circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border:
                    Border.all(color: color.withValues(alpha: 0.45), width: 2),
              ),
              child: Center(
                child: Text(
                  score.recoveryScore.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Label + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        score.interpretationLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildTrendArrow(trend),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    score.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.65),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // "Building your baseline" note — shown when fewer than 3 components
        if (score.componentsAvailable < 3) ...[
          const SizedBox(height: 6),
          Text(
            'Building your baseline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],

        // 7-day sparkline
        const SizedBox(height: 10),
        sparklineAsync.when(
          loading: () => const SizedBox(height: 32),
          error: (_, __) => const SizedBox.shrink(),
          data: (scores) => _buildSparkline(scores),
        ),
      ],
    );
  }

  // ---------- Sparkline ----------

  /// Draws a minimal polyline sparkline using CustomPaint.
  /// Each segment is coloured green / amber / red based on the score value
  /// at the start of that segment.
  Widget _buildSparkline(List<RecoveryScoreEntity> scores) {
    if (scores.length < 2) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: CustomPaint(
        painter: _SparklinePainter(scores: scores),
      ),
    );
  }

  Widget _buildTrendArrow(RecoveryTrend trend) {
    return switch (trend) {
      RecoveryTrend.up =>
        const Icon(Icons.trending_up, color: Colors.green, size: 18),
      RecoveryTrend.down =>
        const Icon(Icons.trending_down, color: Colors.red, size: 18),
      RecoveryTrend.flat =>
        const Icon(Icons.trending_flat, color: Colors.grey, size: 18),
    };
  }

  /// PRD-exact colour thresholds.
  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow.shade700;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}

// ---------------------------------------------------------------------------
// CustomPainter — minimal polyline sparkline
// ---------------------------------------------------------------------------

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.scores});

  final List<RecoveryScoreEntity> scores;

  /// Map a score value to a paint colour.
  Color _colorForScore(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow.shade700;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final minScore = scores.map((s) => s.recoveryScore).reduce(math.min);
    final maxScore = scores.map((s) => s.recoveryScore).reduce(math.max);
    final scoreRange = (maxScore - minScore).clamp(1.0, double.infinity);

    final n = scores.length;
    final xStep = size.width / (n - 1);

    // Pre-compute (x, y) for each data point.
    final points = List.generate(n, (i) {
      final x = xStep * i;
      // Normalise: high score → low y (top of canvas).
      final normalised = (scores[i].recoveryScore - minScore) / scoreRange;
      final y = size.height - (normalised * size.height);
      return Offset(x, y);
    });

    // Draw each segment with the colour of its starting point's score.
    for (int i = 0; i < n - 1; i++) {
      final paint = Paint()
        ..color = _colorForScore(scores[i].recoveryScore)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw small filled circles at each data point.
    for (int i = 0; i < n; i++) {
      final dotPaint = Paint()
        ..color = _colorForScore(scores[i].recoveryScore)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.scores != scores;
}
