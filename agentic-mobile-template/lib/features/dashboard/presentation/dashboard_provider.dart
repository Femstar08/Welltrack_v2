import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/core/modules/module_metadata.dart';
import '../../../shared/core/modules/module_registry.dart';
import '../../../shared/core/logging/app_logger.dart';

/// Dashboard state containing module tiles and recovery score
class DashboardState {

  const DashboardState({
    this.tiles = const [],
    this.recoveryScore,
    this.isCalibrating = true,
    this.errorMessage,
  });
  final List<ModuleConfig> tiles;
  final double? recoveryScore;
  final bool isCalibrating;
  final String? errorMessage;

  DashboardState copyWith({
    List<ModuleConfig>? tiles,
    double? recoveryScore,
    bool? isCalibrating,
    String? errorMessage,
  }) {
    return DashboardState(
      tiles: tiles ?? this.tiles,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Dashboard state notifier
class DashboardNotifier extends StateNotifier<DashboardState> {

  DashboardNotifier(this.ref) : super(const DashboardState());
  final Ref ref;
  final AppLogger _logger = AppLogger();

  /// Initialize dashboard with profile data
  Future<void> initialize(String profileId) async {
    try {
      _logger.info('Initializing dashboard for profile: $profileId');

      // Load module configs
      await ref.read(moduleConfigsProvider.notifier).loadForProfile(profileId);

      // Listen to enabled modules
      ref.listen(enabledModulesProvider, (previous, next) {
        state = state.copyWith(tiles: next);
      });

      // Load recovery score (placeholder for now)
      await _loadRecoveryScore(profileId);

      _logger.info('Dashboard initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Error initializing dashboard', e, stackTrace);
      state = state.copyWith(
        errorMessage: 'Failed to load dashboard. Please try again.',
      );
    }
  }

  /// Load recovery score from health metrics
  /// TODO: Implement actual recovery score calculation
  Future<void> _loadRecoveryScore(String profileId) async {
    try {
      _logger.info('Loading recovery score');

      // For now, set to calibrating
      // In future, this will:
      // 1. Fetch recent health metrics (stress, sleep, VO2 max)
      // 2. Calculate recovery score using algorithm
      // 3. Update state with score

      state = state.copyWith(
        isCalibrating: true,
        recoveryScore: null,
      );

      // Simulate async load - replace with actual implementation
      await Future.delayed(const Duration(milliseconds: 500));

      _logger.info('Recovery score loaded (calibrating)');
    } catch (e, stackTrace) {
      _logger.error('Error loading recovery score', e, stackTrace);
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
