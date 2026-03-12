import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/performance_engine.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Returns true if the overtraining warning should be shown today.
/// Dismissed state is stored in SharedPreferences keyed by calendar date.
final overtTrainingWarningVisibleProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final key =
      'overtraining_dismissed_${today.year}_${today.month}_${today.day}';
  return !(prefs.getBool(key) ?? false);
});

/// Computes the overtraining risk for [profileId] using the same
/// 4-week rolling window as the Insights screen.
final _overtrainingRiskProvider =
    FutureProvider.family<OvertrainingRisk, String>((ref, profileId) async {
  final repo = ref.watch(insightsRepositoryProvider);
  final now = DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final thisWeekStart =
      todayDate.subtract(Duration(days: todayDate.weekday - 1));
  final fourWeeksAgo = thisWeekStart.subtract(const Duration(days: 28));

  final fourWeekLoads = await repo.getTrainingLoads(
    profileId: profileId,
    startDate: fourWeeksAgo,
    endDate: todayDate.add(const Duration(days: 1)),
  );

  final weeklyLoadTotal = fourWeekLoads
      .where((l) => !l.loadDate.isBefore(thisWeekStart))
      .fold<double>(0, (sum, l) => sum + l.trainingLoad);

  final fourWeekTotal =
      fourWeekLoads.fold<double>(0, (sum, l) => sum + l.trainingLoad);
  final fourWeekAverage = fourWeekTotal / 4.0;

  return PerformanceEngine.checkOvertrainingRisk(
    weeklyLoadTotal,
    fourWeekAverage,
  );
});

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Dismissable amber warning card shown on the dashboard when the
/// insights engine detects a high training load relative to the user's
/// 4-week average.
///
/// The card is self-contained: it fetches its own overtraining flag and
/// manages per-day dismiss state via SharedPreferences.
class OvertTrainingWarningCard extends ConsumerStatefulWidget {
  const OvertTrainingWarningCard({
    required this.profileId,
    super.key,
  });

  final String profileId;

  @override
  ConsumerState<OvertTrainingWarningCard> createState() =>
      _OvertTrainingWarningCardState();
}

class _OvertTrainingWarningCardState
    extends ConsumerState<OvertTrainingWarningCard> {
  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key =
        'overtraining_dismissed_${today.year}_${today.month}_${today.day}';
    await prefs.setBool(key, true);
    // Invalidate so the FutureProvider re-evaluates to false.
    ref.invalidate(overtTrainingWarningVisibleProvider);
  }

  @override
  Widget build(BuildContext context) {
    final riskAsync =
        ref.watch(_overtrainingRiskProvider(widget.profileId));
    final visibleAsync = ref.watch(overtTrainingWarningVisibleProvider);

    // Only show when both futures have resolved and conditions are met.
    final isOvertraining = riskAsync.valueOrNull != null &&
        riskAsync.valueOrNull != OvertrainingRisk.none;
    final isVisible = visibleAsync.valueOrNull ?? false;

    if (!isOvertraining || !isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.orange.shade300,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your training load is higher than usual. '
                  'Consider a rest day.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              Semantics(
                label: 'Dismiss overtraining warning',
                button: true,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
