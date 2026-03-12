import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/insights_repository.dart';
import '../domain/recovery_score_entity.dart';
import 'insights_provider.dart';
import '../../../shared/core/auth/session_manager.dart';
import '../../health/presentation/health_connections_provider.dart';
import '../../health/presentation/widgets/garmin_attribution_widget.dart';
import '../../health/presentation/widgets/strava_attribution_widget.dart';

/// Detailed recovery score screen — component breakdown + 7-day sparkline.
class RecoveryDetailScreen extends ConsumerStatefulWidget {
  const RecoveryDetailScreen({
    super.key,
    required this.profileId,
  });

  final String profileId;

  @override
  ConsumerState<RecoveryDetailScreen> createState() =>
      _RecoveryDetailScreenState();
}

class _RecoveryDetailScreenState extends ConsumerState<RecoveryDetailScreen> {
  ({String profileId, String userId}) get _params => (
        profileId: widget.profileId,
        userId: ref.read(currentUserIdProvider) ?? '',
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(insightsProvider(_params).notifier).initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider(_params));
    final score = state.latestRecoveryScore;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Recovery Score'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.read(insightsProvider(_params).notifier).initialize(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (score != null) ...[
                      _buildScoreHero(context, score),
                      const SizedBox(height: 28),
                      _buildComponentBreakdown(context, score),
                      const SizedBox(height: 28),
                    ] else ...[
                      _buildNoData(context),
                      const SizedBox(height: 28),
                    ],
                    _buildSparklineSection(context),
                    _buildDataSourceAttribution(context),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Hero score circle ──────────────────────────────────────────────────────

  Widget _buildScoreHero(BuildContext context, RecoveryScoreEntity score) {
    final color = _scoreColor(score.recoveryScore);
    final label = score.interpretationLabel;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Large colour-coded circle
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                score.recoveryScore.round().toString(),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 14,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score.description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
        if (score.componentsAvailable < 3) ...[
          const SizedBox(height: 12),
          const Text(
            'Building your baseline — score accuracy improves with more data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ],
    );
  }

  // ── Component breakdown bars ───────────────────────────────────────────────

  Widget _buildComponentBreakdown(
      BuildContext context, RecoveryScoreEntity score) {
    // Extract source attribution map written by PerformanceEngine into rawData.
    // Keys: 'sleep_duration', 'sleep_quality', 'hr_stress', 'training_load'
    // Values: 'garmin' | 'healthconnect' | 'internal'
    final sources =
        (score.rawData?['sources'] as Map<Object?, Object?>?)
            ?.cast<String, String>() ??
        <String, String>{};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Component Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComponentRow(
              context,
              label: 'Sleep Duration',
              icon: Icons.bedtime_outlined,
              value: score.sleepComponent,
              weight: '30%',
              sourceKey: sources['sleep_duration'],
            ),
            const SizedBox(height: 12),
            _buildComponentRow(
              context,
              // Label reflects that Garmin body battery may substitute REM/deep ratio
              label: sources['sleep_quality'] == 'garmin'
                  ? 'Body Battery'
                  : 'Sleep Quality',
              icon: Icons.nights_stay_outlined,
              // stressComponent slot repurposed for sleep quality in the engine
              value: score.stressComponent,
              weight: '20%',
              sourceKey: sources['sleep_quality'],
            ),
            const SizedBox(height: 12),
            _buildComponentRow(
              context,
              // Label reflects that Garmin stress score may substitute RHR
              label: sources['hr_stress'] == 'garmin'
                  ? 'Stress Score'
                  : 'Resting Heart Rate',
              icon: Icons.favorite_outline,
              value: score.hrComponent,
              weight: '25%',
              sourceKey: sources['hr_stress'],
            ),
            const SizedBox(height: 12),
            _buildComponentRow(
              context,
              label: 'Training Load',
              icon: Icons.fitness_center_outlined,
              value: score.loadComponent,
              weight: '25%',
              sourceKey: sources['training_load'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required double? value,
    required String weight,
    String? sourceKey, // 'garmin' | 'healthconnect' | 'internal' | null
  }) {
    final theme = Theme.of(context);
    final displayValue = value ?? 0.0;
    final barColor = _scoreColor(displayValue);

    // Attribution text — only shown when value is present and source is meaningful
    final attributionText = value != null ? _sourceLabel(sourceKey) : null;

    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  Text(
                    value == null
                        ? 'No data'
                        : '${displayValue.round()} / 100',
                    style: TextStyle(
                      fontSize: 12,
                      color: value == null ? Colors.grey : barColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value == null ? 0 : (displayValue / 100).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    value == null ? Colors.grey.shade300 : barColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Weight: $weight',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  if (attributionText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      attributionText,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Converts a source key from rawData['sources'] into a human-readable
  /// attribution string shown below the metric bar.
  /// Returns null for 'internal' or unknown keys to keep UI clean.
  String? _sourceLabel(String? sourceKey) {
    switch (sourceKey) {
      case 'garmin':
        return 'via Garmin';
      case 'healthconnect':
        return 'via Health Connect';
      case null:
      case 'internal':
      default:
        return null;
    }
  }

  // ── 7-day sparkline ───────────────────────────────────────────────────────

  Widget _buildSparklineSection(BuildContext context) {
    final sparklineAsync =
        ref.watch(_recoveryDetailSparklineProvider(widget.profileId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7-Day Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            sparklineAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const SizedBox(
                height: 60,
                child: Center(
                    child:
                        Text('No data', style: TextStyle(color: Colors.grey))),
              ),
              data: (scores) {
                if (scores.length < 2) {
                  return const SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'Keep logging — more data needed',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 80,
                  child: CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _SparklinePainter(scores),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Data source attribution ───────────────────────────────────────────────

  /// Renders brand attribution for whichever health provider(s) are connected.
  /// Returns [SizedBox.shrink] when neither Garmin nor Strava is connected.
  Widget _buildDataSourceAttribution(BuildContext context) {
    final connectionsState =
        ref.watch(healthConnectionsProvider(widget.profileId));

    final garminOn = connectionsState.garminConnected;
    final stravaOn = connectionsState.stravaConnected;

    if (!garminOn && !stravaOn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          GarminAttributionWidget(visible: garminOn),
          if (garminOn && stravaOn) const SizedBox(width: 12),
          StravaAttributionWidget(visible: stravaOn),
        ],
      ),
    );
  }

  Widget _buildNoData(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.monitor_heart_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No recovery score yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep logging your health data. Your first score will appear once enough data is available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow.shade700;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}

// ── Sparkline provider ────────────────────────────────────────────────────────

final _recoveryDetailSparklineProvider =
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

// ── Sparkline painter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.scores);

  final List<RecoveryScoreEntity> scores;

  Color _colorFor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow.shade700;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final maxScore = scores.map((s) => s.recoveryScore).reduce(math.max);
    final minScore = scores.map((s) => s.recoveryScore).reduce(math.min);
    final range = (maxScore - minScore).clamp(10.0, double.infinity);

    double xFor(int i) =>
        scores.length == 1 ? size.width / 2 : i * (size.width / (scores.length - 1));
    double yFor(double v) =>
        size.height - ((v - minScore) / range) * size.height * 0.85 - size.height * 0.05;

    // Draw segments
    for (int i = 0; i < scores.length - 1; i++) {
      final paint = Paint()
        ..color = _colorFor(scores[i].recoveryScore)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(xFor(i), yFor(scores[i].recoveryScore)),
        Offset(xFor(i + 1), yFor(scores[i + 1].recoveryScore)),
        paint,
      );
    }

    // Draw dots
    for (int i = 0; i < scores.length; i++) {
      final dot = Paint()
        ..color = _colorFor(scores[i].recoveryScore)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(xFor(i), yFor(scores[i].recoveryScore)), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.scores != scores;
}
