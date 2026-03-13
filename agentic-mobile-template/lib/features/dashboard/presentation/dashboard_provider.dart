import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/core/modules/module_metadata.dart';
import '../../../shared/core/modules/module_registry.dart';
import '../../../shared/core/logging/app_logger.dart';
import '../../insights/data/insights_repository.dart';
import '../../insights/data/performance_engine.dart';

/// Dashboard state containing module tiles and recovery score
class DashboardState {

  const DashboardState({
    this.tiles = const [],
    this.recoveryScore,
    this.isCalibrating = true,
    this.isOvertraining = false,
    this.errorMessage,
  });
  final List<ModuleConfig> tiles;
  final double? recoveryScore;
  final bool isCalibrating;

  /// True when the insights engine flags high training load relative to the
  /// user's 4-week average.  Drives the dismissable warning card.
  final bool isOvertraining;

  final String? errorMessage;

  DashboardState copyWith({
    List<ModuleConfig>? tiles,
    double? recoveryScore,
    bool? isCalibrating,
    bool? isOvertraining,
    String? errorMessage,
  }) {
    return DashboardState(
      tiles: tiles ?? this.tiles,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      isOvertraining: isOvertraining ?? this.isOvertraining,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Dashboard state notifier
class DashboardNotifier extends StateNotifier<DashboardState> {

  DashboardNotifier(this.ref) : super(const DashboardState());
  final Ref ref;
  final AppLogger _logger = AppLogger();
  bool _listenersSetUp = false;

  /// Initialize dashboard with profile data
  Future<void> initialize(String profileId) async {
    try {
      _logger.info('Initializing dashboard for profile: $profileId');

      // Load module configs
      await ref.read(moduleConfigsProvider.notifier).loadForProfile(profileId);

      // Listen to enabled modules (guard against multiple registrations)
      if (!_listenersSetUp) {
        _listenersSetUp = true;
        ref.listen(enabledModulesProvider, (previous, next) {
          state = state.copyWith(tiles: next);
        });
      }

      // Read current value (ref.listen only fires on changes, not initial value)
      final currentModules = ref.read(enabledModulesProvider);
      if (currentModules.isNotEmpty) {
        state = state.copyWith(tiles: currentModules);
      }

      // Load real recovery score via PerformanceEngine + InsightsRepository
      await _loadRecoveryScore(profileId);

      _logger.info('Dashboard initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Error initializing dashboard', e, stackTrace);
      state = state.copyWith(
        errorMessage: 'Failed to load dashboard. Please try again.',
      );
    }
  }

  /// Load recovery score from health metrics via PerformanceEngine.
  ///
  /// Calls [InsightsRepository.calculateAndSaveDailyRecovery] which:
  ///   1. Checks whether today's score already exists in wt_recovery_scores.
  ///   2. If not, fetches sleep / HR / training-load data from wt_health_metrics
  ///      (and Garmin rows when available) then runs the PRD Phase 10 formula.
  ///   3. Upserts the result and returns the entity.
  ///
  /// Returns null when no health data exists yet (user is still calibrating).
  /// In that case the dashboard stays in calibrating state — no score is shown.
  ///
  /// Overtraining flag is derived from the same weekly / 4-week load data
  /// already computed inside calculateAndSaveDailyRecovery, re-queried here
  /// with a lightweight training-load fetch so the dashboard card reacts
  /// without depending on the full InsightsNotifier being initialised.
  Future<void> _loadRecoveryScore(String profileId) async {
    // Start in calibrating state so widgets don't flash stale data.
    state = state.copyWith(
      isCalibrating: true,
      recoveryScore: null,
    );

    try {
      _logger.info('Loading recovery score for profile: $profileId');

      final repository = ref.read(insightsRepositoryProvider);

      // Calculate (or retrieve cached) today's recovery score.
      final scoreEntity = await repository.calculateAndSaveDailyRecovery(
        profileId: profileId,
      );

      if (scoreEntity == null || scoreEntity.componentsAvailable == 0) {
        // No health data yet — keep isCalibrating: true.
        _logger.info('Recovery score: no data — still calibrating');
        return;
      }

      // --- Overtraining detection (4-week rolling load) ---
      // Re-use the same load windows that InsightsRepository uses internally
      // so the formula stays consistent.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final fourWeeksAgo = thisWeekStart.subtract(const Duration(days: 28));

      final fourWeekLoads = await repository.getTrainingLoads(
        profileId: profileId,
        startDate: fourWeeksAgo,
        endDate: today.add(const Duration(days: 1)),
      );

      final weeklyLoad = fourWeekLoads
          .where((l) => !l.loadDate.isBefore(thisWeekStart))
          .fold<double>(0, (sum, l) => sum + l.trainingLoad);

      final fourWeekTotal =
          fourWeekLoads.fold<double>(0, (sum, l) => sum + l.trainingLoad);
      final fourWeekAvg = fourWeekTotal / 4.0;

      final overtrainingRisk = PerformanceEngine.checkOvertrainingRisk(
        weeklyLoad,
        fourWeekAvg,
      );

      state = state.copyWith(
        recoveryScore: scoreEntity.recoveryScore,
        isCalibrating: false,
        isOvertraining: overtrainingRisk != OvertrainingRisk.none,
      );

      _logger.info(
        'Recovery score loaded: ${scoreEntity.recoveryScore.toStringAsFixed(1)} '
        '(${scoreEntity.componentsAvailable} components, '
        'overtraining: ${overtrainingRisk.name})',
      );
    } catch (e, stackTrace) {
      _logger.error('Error loading recovery score', e, stackTrace);
      // Leave the state as calibrating so the UI shows a neutral card
      // rather than crashing or showing a stale value.
    }
  }

  /// Refresh dashboard data
  Future<void> refresh(String profileId) async {
    try {
      _logger.info('Refreshing dashboard');

      // Refresh modules
      await ref.read(moduleConfigsProvider.notifier).refresh();

      // Refresh recovery score
      await _loadRecoveryScore(profileId);

      _logger.info('Dashboard refreshed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error refreshing dashboard', e, stackTrace);
      state = state.copyWith(
        errorMessage: 'Failed to refresh. Please try again.',
      );
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for dashboard state
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(ref),
);

/// Provider for recovery score color
final recoveryScoreColorProvider = Provider<int>((ref) {
  final dashboard = ref.watch(dashboardProvider);

  if (dashboard.recoveryScore == null || dashboard.isCalibrating) {
    return 0xFF9E9E9E; // gray for calibrating
  }

  final score = dashboard.recoveryScore!;

  // Return color value based on score
  if (score >= 80) return 0xFF4CAF50; // excellent (green)
  if (score >= 60) return 0xFF8BC34A; // good (light green)
  if (score >= 40) return 0xFFFFCA28; // moderate (yellow)
  if (score >= 20) return 0xFFFF9800; // low (orange)
  return 0xFFF44336; // critical (red)
});
