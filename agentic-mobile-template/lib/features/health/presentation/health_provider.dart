import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/health/data/health_data_source.dart';
import 'package:welltrack/features/health/data/health_repository.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';
import 'package:welltrack/features/health/domain/baseline_entity.dart';

/// Health connection state
class HealthConnectionState {
  final bool isConnected;
  final DateTime? lastSyncTime;
  final bool isSyncing;
  final String? error;

  const HealthConnectionState({
    this.isConnected = false,
    this.lastSyncTime,
    this.isSyncing = false,
    this.error,
  });

  HealthConnectionState copyWith({
    bool? isConnected,
    DateTime? lastSyncTime,
    bool? isSyncing,
    String? error,
  }) {
    return HealthConnectionState(
      isConnected: isConnected ?? this.isConnected,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
    );
  }
}

/// Notifier for managing health connection state
class HealthConnectionNotifier extends StateNotifier<HealthConnectionState> {
  final HealthDataSource _dataSource;
  final HealthRepository _repository;
  final String _profileId;

  HealthConnectionNotifier({
    required String profileId,
    HealthDataSource? dataSource,
    HealthRepository? repository,
  })  : _profileId = profileId,
        _dataSource = dataSource ?? HealthDataSource(),
        _repository = repository ?? HealthRepository(),
        super(const HealthConnectionState()) {
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    try {
      final hasPermissions = await _dataSource.hasPermissions();
      state = state.copyWith(isConnected: hasPermissions);
    } catch (e) {
      // Non-fatal — leave as disconnected
      print('Error checking initial health permissions: $e');
    }
  }

  /// Request health data permissions
  Future<bool> requestPermissions() async {
    try {
      state = state.copyWith(error: null, isSyncing: true);
      final granted = await _dataSource.requestPermissions();
      state = state.copyWith(isConnected: granted, isSyncing: false);

      if (!granted) {
        state = state.copyWith(
          error: 'Health Connect permissions were not granted. '
              'Please allow access when prompted.',
        );
      }

      return granted;
    } catch (e) {
      state = state.copyWith(
        error: 'Could not connect to Health Connect: ${e.toString()}',
        isSyncing: false,
      );
      return false;
    }
  }

  /// Sync health data (last 24h)
  Future<void> syncNow() async {
    if (!state.isConnected) {
      state = state.copyWith(error: 'Not connected to health data');
      return;
    }

    try {
      state = state.copyWith(isSyncing: true, error: null);

      await _repository.syncHealthData(_profileId);

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  /// Sync historical data
  Future<void> syncHistorical({int days = 14}) async {
    if (!state.isConnected) {
      state = state.copyWith(error: 'Not connected to health data');
      return;
    }

    try {
      state = state.copyWith(isSyncing: true, error: null);

      await _repository.syncHistoricalData(_profileId, days: days);

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider for health connection state
final healthConnectionProvider = StateNotifierProvider.family<
    HealthConnectionNotifier,
    HealthConnectionState,
    String>((ref, profileId) {
  final repository = ref.watch(healthRepositoryProvider);
  return HealthConnectionNotifier(
    profileId: profileId,
    repository: repository,
  );
});

/// Provider for baseline calibration status
final baselineStatusProvider = FutureProvider.family<
    Map<MetricType, BaselineEntity>,
    String>((ref, profileId) async {
  final repository = ref.watch(healthRepositoryProvider);
  return await repository.getBaselineStatus(profileId);
});

/// Provider for latest health metrics
final latestMetricsProvider = FutureProvider.family<
    Map<MetricType, HealthMetricEntity?>,
    String>((ref, profileId) async {
  final repository = ref.watch(healthRepositoryProvider);

  final metricsToFetch = [
    MetricType.sleep,
    MetricType.steps,
    MetricType.hr,
    MetricType.stress,
    MetricType.vo2max,
  ];

  final results = <MetricType, HealthMetricEntity?>{};

  for (final metricType in metricsToFetch) {
    final metrics = await repository.getMetrics(
      profileId,
      metricType,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    results[metricType] = metrics.isNotEmpty ? metrics.first : null;
  }

  return results;
});

/// Provider for calibration progress percentage
final calibrationProgressProvider = FutureProvider.family<
    Map<MetricType, double>,
    String>((ref, profileId) async {
  final baselines = await ref.watch(baselineStatusProvider(profileId).future);

  return {
    for (final entry in baselines.entries)
      entry.key: _calculateProgress(entry.value),
  };
});

double _calculateProgress(BaselineEntity baseline) {
  // Progress is based on days (out of 14) and data points (out of 10)
  final dayProgress = baseline.captureEnd != null
      ? (baseline.captureEnd!.difference(baseline.captureStart).inDays / 14.0)
          .clamp(0.0, 1.0)
      : 0.0;

  final dataPointProgress = (baseline.dataPointsCount / 10.0).clamp(0.0, 1.0);

  // Average both factors
  return ((dayProgress + dataPointProgress) / 2.0 * 100).clamp(0.0, 100.0);
}
