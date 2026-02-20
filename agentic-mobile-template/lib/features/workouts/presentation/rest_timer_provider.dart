// lib/features/workouts/presentation/rest_timer_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Alert mode preference
// ---------------------------------------------------------------------------

/// Controls how the app notifies the user when a rest timer expires.
///
/// This value is stored in state only (not persisted between sessions in this
/// file). Wire it to Hive / shared-prefs in the Settings screen if persistence
/// across app launches is required.
enum RestTimerAlertMode { vibrateOnly, soundOnly, both, silent }

final restTimerAlertModeProvider = StateProvider<RestTimerAlertMode>(
  (ref) => RestTimerAlertMode.vibrateOnly,
);

// ---------------------------------------------------------------------------
// RestTimerState
// ---------------------------------------------------------------------------

class RestTimerState {
  const RestTimerState({
    this.isRunning = false,
    this.totalSeconds = 90,
    this.remainingSeconds = 0,
    this.exerciseName,
  });

  /// Whether the countdown is actively ticking.
  final bool isRunning;

  /// The duration the timer was started with (used for [progress]).
  final int totalSeconds;

  /// Seconds remaining in the current countdown.
  final int remainingSeconds;

  /// Optional label shown in the timer UI.
  final String? exerciseName;

  RestTimerState copyWith({
    bool? isRunning,
    int? totalSeconds,
    int? remainingSeconds,
    String? exerciseName,
  }) {
    return RestTimerState(
      isRunning: isRunning ?? this.isRunning,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      exerciseName: exerciseName ?? this.exerciseName,
    );
  }

  // ── Derived getters ───────────────────────────────────────────────────────

  /// 1.0 when just started; 0.0 when complete. Suitable for a circular
  /// progress indicator.
  double get progress =>
      totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

  /// True once the timer has been started and has reached zero. The notifier
  /// calls [stop] immediately after, so callers should listen for this state
  /// to trigger vibration / sound through a [ProviderListener].
  bool get isComplete => isRunning && remainingSeconds <= 0;

  /// Formatted mm:ss string for display.
  String get formattedTime {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// RestTimerNotifier
// ---------------------------------------------------------------------------

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  RestTimerNotifier() : super(const RestTimerState());

  Timer? _timer;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Starts (or restarts) the timer for [seconds].
  ///
  /// Any previously running timer is cancelled first.
  void start(int seconds, {String? exerciseName}) {
    _timer?.cancel();
    state = RestTimerState(
      isRunning: true,
      totalSeconds: seconds,
      remainingSeconds: seconds,
      exerciseName: exerciseName ?? state.exerciseName,
    );
    _tick();
  }

  /// Pauses the countdown without resetting remaining time.
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  /// Resumes a paused timer. No-op if remaining time is already zero.
  void resume() {
    if (state.remainingSeconds <= 0) return;
    state = state.copyWith(isRunning: true);
    _tick();
  }

  /// Skips the rest period and resets the timer.
  void skip() => stop();

  /// Adds [extraSeconds] to both the total and remaining durations.
  ///
  /// Useful for extending a rest period mid-countdown.
  void extend(int extraSeconds) {
    state = state.copyWith(
      totalSeconds: state.totalSeconds + extraSeconds,
      remainingSeconds: state.remainingSeconds + extraSeconds,
    );
  }

  /// Stops the timer and resets all state.
  void stop() {
    _timer?.cancel();
    state = const RestTimerState();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _tick() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        // Timer is complete. Emit the isComplete state (remainingSeconds == 0,
        // isRunning == true) for one tick so listeners can react (vibrate /
        // play sound), then immediately stop.
        stop();
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Single global rest timer — there is never more than one active rest period
/// at a time during a workout session.
final restTimerProvider =
    StateNotifierProvider<RestTimerNotifier, RestTimerState>(
  (ref) => RestTimerNotifier(),
);
