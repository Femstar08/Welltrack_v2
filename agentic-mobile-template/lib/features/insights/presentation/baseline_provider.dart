import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/baseline_entity.dart';
import '../data/baseline_repository.dart';
import '../../reminders/data/notification_service.dart';

/// Baseline State
class BaselineState {

  const BaselineState({
    this.isInBaselinePeriod = false,
    this.daysCompleted = 0,
    this.daysRemaining = BaselineEntity.calibrationDays,
    this.baselineMetrics = const [],
    this.isLoading = true,
    this.error,
  });

  final bool isInBaselinePeriod;
  final int daysCompleted;
  final int daysRemaining;
  final List<BaselineEntity> baselineMetrics;
  final bool isLoading;
  final String? error;

  /// Overall calibration status derived from metric list
  String get calibrationStatus {
    if (baselineMetrics.isEmpty) return 'pending';
    if (baselineMetrics.every((b) => b.isComplete)) return 'complete';
    if (baselineMetrics.any((b) => b.captureStart != null)) return 'in_progress';
    return 'pending';
  }

  double get progressPercentage =>
      BaselineEntity.calibrationDays > 0
          ? daysCompleted / BaselineEntity.calibrationDays
          : 0.0;

  BaselineState copyWith({
    bool? isInBaselinePeriod,
    int? daysCompleted,
    int? daysRemaining,
    List<BaselineEntity>? baselineMetrics,
    bool? isLoading,
    String? error,
  }) {
    return BaselineState(
      isInBaselinePeriod: isInBaselinePeriod ?? this.isInBaselinePeriod,
      daysCompleted: daysCompleted ?? this.daysCompleted,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      baselineMetrics: baselineMetrics ?? this.baselineMetrics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Baseline Notifier
class BaselineNotifier extends StateNotifier<BaselineState> {

  BaselineNotifier(this._repository, this._profileId, this._notifications)
      : super(const BaselineState());

  final BaselineRepository _repository;
  final String _profileId;
  final NotificationService _notifications;

  /// Query wt_health_metrics for the count of distinct days that have data,
  /// persist it to wt_profiles, and mark baseline complete when count >= 14.
  /// Returns the distinct-day count.
  Future<int> updateBaselineDaysCount(String profileId) async {
    return _repository.updateBaselineDaysCount(profileId);
  }

  /// Load baselines and check if 14 days have passed — auto-complete if so.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch the DB-accurate distinct-day count and persist it to wt_profiles.
      // This is more accurate than inferring from capture_start alone because it
      // reflects real health metric data rather than just the start timestamp.
      final dbDaysCount = await updateBaselineDaysCount(_profileId);

      final baselines = await _repository.getBaselines(_profileId);

      if (baselines.isEmpty) {
        // No baselines yet — still in pending state, not in period
        state = state.copyWith(
          isLoading: false,
          isInBaselinePeriod: false,
          daysCompleted: dbDaysCount,
          daysRemaining: (BaselineEntity.calibrationDays - dbDaysCount)
              .clamp(0, BaselineEntity.calibrationDays),
          baselineMetrics: [],
        );
        return;
      }

      // Use the earliest capture_start as the period anchor
      final started = baselines.where((b) => b.captureStart != null).toList();

      if (started.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isInBaselinePeriod: false,
          daysCompleted: dbDaysCount,
          daysRemaining: (BaselineEntity.calibrationDays - dbDaysCount)
              .clamp(0, BaselineEntity.calibrationDays),
          baselineMetrics: baselines,
        );
        return;
      }

      final earliest = started
          .map((b) => b.captureStart!)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final now = DateTime.now();
      final elapsed = now.difference(earliest).inDays;

      // Prefer the DB-derived count (distinct days with actual data) when it is
      // higher than the time-elapsed figure — the DB count is ground truth.
      final daysCompleted =
          dbDaysCount > elapsed
              ? dbDaysCount.clamp(0, BaselineEntity.calibrationDays)
              : elapsed.clamp(0, BaselineEntity.calibrationDays);

      final daysRemaining =
          (BaselineEntity.calibrationDays - daysCompleted).clamp(0, BaselineEntity.calibrationDays);

      final allAlreadyComplete = baselines.every((b) => b.isComplete);

      // Auto-complete if 14 days have passed and not yet marked complete
      if (daysCompleted >= BaselineEntity.calibrationDays && !allAlreadyComplete) {
        await _repository.completeBaselines(_profileId);
        // One-time baseline ready notification
        unawaited(_notifications.showLocalNotification(
          id: 9001,
          title: 'Baseline complete!',
          body: 'Your 14-day baseline is ready. Advanced insights are now unlocked.',
          payload: '/insights',
        ).catchError((_) {}));
        final updated = await _repository.getBaselines(_profileId);
        state = state.copyWith(
          isLoading: false,
          isInBaselinePeriod: false,
          daysCompleted: BaselineEntity.calibrationDays,
          daysRemaining: 0,
          baselineMetrics: updated,
        );
        return;
      }

      final isInBaselinePeriod = !allAlreadyComplete && daysCompleted < BaselineEntity.calibrationDays;

      state = state.copyWith(
        isLoading: false,
        isInBaselinePeriod: isInBaselinePeriod,
        daysCompleted: daysCompleted,
        daysRemaining: daysRemaining,
        baselineMetrics: baselines,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load baseline: $e',
      );
    }
  }

  /// Initialize baselines if they haven't been created yet, then reload.
  Future<void> initializeIfNeeded() async {
    final baselines = await _repository.getBaselines(_profileId);
    if (baselines.isEmpty) {
      await _repository.initializeBaselines(_profileId);
    }
    await load();
  }
}

/// Provider family keyed by profileId
final baselineProvider =
    StateNotifierProvider.family<BaselineNotifier, BaselineState, String>(
  (ref, profileId) {
    final repository = ref.watch(baselineRepositoryProvider);
    final notifications = ref.watch(notificationServiceProvider);
    return BaselineNotifier(repository, profileId, notifications);
  },
);
