// lib/features/habits/presentation/kegel_timer_provider.dart
//
// Riverpod state management for the Kegel guided-timer (US-003).
//
// Follows the same StateNotifier + Timer.periodic pattern used by
// rest_timer_provider.dart in the workouts feature.
//
// Phase transitions (within a set):
//   squeeze → relax
//   relax   → squeeze (next rep)  OR  rest (last rep in set)
//   rest    → squeeze (next set)  OR  complete (last set)
//
// On completion the kegels habit is auto-logged via habitRepositoryProvider.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../data/habit_repository.dart';
import '../domain/kegel_protocol.dart';
import '../../profile/data/profile_repository.dart'
    show profileRepositoryProvider;

// ---------------------------------------------------------------------------
// Phase enum
// ---------------------------------------------------------------------------

/// The current sub-phase of the timer session.
enum KegelPhase {
  /// No protocol selected / timer has not been started.
  idle,

  /// Pelvic floor contraction (or push-out for Reverse Kegels).
  squeeze,

  /// Muscle release / relaxation phase.
  relax,

  /// Rest interval between sets.
  rest,

  /// All sets completed.
  complete,
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class KegelTimerState {
  const KegelTimerState({
    this.selectedProtocol,
    this.currentPhase = KegelPhase.idle,
    this.currentSet = 0,
    this.currentRep = 0,
    this.remainingSeconds = 0,
    this.isRunning = false,
    this.totalElapsedSeconds = 0,
  });

  /// The protocol chosen by the user. Null until selectProtocol() is called.
  final KegelProtocol? selectedProtocol;

  /// Which sub-phase the timer is currently in.
  final KegelPhase currentPhase;

  /// 1-based current set number (0 = not yet started).
  final int currentSet;

  /// 1-based current rep within the current set (0 = not yet started).
  final int currentRep;

  /// Seconds remaining in the current phase.
  final int remainingSeconds;

  /// Whether the 1-second tick is actively running.
  final bool isRunning;

  /// Cumulative seconds elapsed across all phases since start().
  final int totalElapsedSeconds;

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Duration of the current phase (used to calculate circular progress).
  int get currentPhaseTotalSeconds {
    final p = selectedProtocol;
    if (p == null) return 1;
    switch (currentPhase) {
      case KegelPhase.squeeze:
        return p.squeezeSeconds;
      case KegelPhase.relax:
        return p.relaxSeconds;
      case KegelPhase.rest:
        return p.restBetweenSetsSeconds;
      case KegelPhase.idle:
      case KegelPhase.complete:
        return 1;
    }
  }

  /// 0.0 (phase just ended) → 1.0 (phase just started).
  double get phaseProgress {
    final total = currentPhaseTotalSeconds;
    if (total <= 0) return 0.0;
    return remainingSeconds / total;
  }

  /// Human-readable set/rep counter, e.g. "Set 2/3 • Rep 4/5".
  String get setRepLabel {
    final p = selectedProtocol;
    if (p == null || currentPhase == KegelPhase.idle) return '';
    if (currentPhase == KegelPhase.complete) return 'Complete';
    if (currentPhase == KegelPhase.rest) {
      return 'Set $currentSet/${p.sets} • Rest';
    }
    return 'Set $currentSet/${p.sets} • Rep $currentRep/${p.repsPerSet}';
  }

  /// Total elapsed formatted as mm:ss.
  String get formattedElapsed {
    final m = totalElapsedSeconds ~/ 60;
    final s = totalElapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  KegelTimerState copyWith({
    KegelProtocol? selectedProtocol,
    KegelPhase? currentPhase,
    int? currentSet,
    int? currentRep,
    int? remainingSeconds,
    bool? isRunning,
    int? totalElapsedSeconds,
  }) {
    return KegelTimerState(
      selectedProtocol: selectedProtocol ?? this.selectedProtocol,
      currentPhase: currentPhase ?? this.currentPhase,
      currentSet: currentSet ?? this.currentSet,
      currentRep: currentRep ?? this.currentRep,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      totalElapsedSeconds: totalElapsedSeconds ?? this.totalElapsedSeconds,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class KegelTimerNotifier extends StateNotifier<KegelTimerState> {
  KegelTimerNotifier(this._ref) : super(const KegelTimerState());

  final Ref _ref;
  Timer? _timer;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Selects [protocol] and resets to idle. Does NOT start the timer.
  void selectProtocol(KegelProtocol protocol) {
    _timer?.cancel();
    state = KegelTimerState(selectedProtocol: protocol);
  }

  /// Starts the session for the currently selected protocol.
  /// No-op if no protocol is selected.
  void start() {
    final p = state.selectedProtocol;
    if (p == null) return;
    _timer?.cancel();
    state = state.copyWith(
      currentPhase: KegelPhase.squeeze,
      currentSet: 1,
      currentRep: 1,
      remainingSeconds: p.squeezeSeconds,
      isRunning: true,
      totalElapsedSeconds: 0,
    );
    _tick();
  }

  /// Pauses the countdown without resetting position.
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  /// Resumes a paused timer.
  void resume() {
    if (!state.isRunning && state.currentPhase != KegelPhase.idle &&
        state.currentPhase != KegelPhase.complete) {
      state = state.copyWith(isRunning: true);
      _tick();
    }
  }

  /// Cancels the session and returns to idle for the same protocol.
  void cancel() {
    _timer?.cancel();
    state = KegelTimerState(selectedProtocol: state.selectedProtocol);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Private tick ────────────────────────────────────────────────────────

  void _tick() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      final newElapsed = state.totalElapsedSeconds + 1;

      if (state.remainingSeconds > 1) {
        // Still counting down within this phase.
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          totalElapsedSeconds: newElapsed,
        );
        return;
      }

      // This phase has expired — advance to the next phase.
      _timer?.cancel();
      _advancePhase(newElapsed);
    });
  }

  void _advancePhase(int elapsed) {
    final p = state.selectedProtocol;
    if (p == null) return;

    _vibrate();

    switch (state.currentPhase) {
      case KegelPhase.squeeze:
        // squeeze → relax
        state = state.copyWith(
          currentPhase: KegelPhase.relax,
          remainingSeconds: p.relaxSeconds,
          isRunning: true,
          totalElapsedSeconds: elapsed,
        );
        _tick();

      case KegelPhase.relax:
        final isLastRep = state.currentRep >= p.repsPerSet;
        final isLastSet = state.currentSet >= p.sets;

        if (!isLastRep) {
          // relax → squeeze (next rep in same set)
          state = state.copyWith(
            currentPhase: KegelPhase.squeeze,
            currentRep: state.currentRep + 1,
            remainingSeconds: p.squeezeSeconds,
            isRunning: true,
            totalElapsedSeconds: elapsed,
          );
          _tick();
        } else if (!isLastSet) {
          // relax → rest (between sets)
          state = state.copyWith(
            currentPhase: KegelPhase.rest,
            remainingSeconds: p.restBetweenSetsSeconds,
            isRunning: true,
            totalElapsedSeconds: elapsed,
          );
          _tick();
        } else {
          // Last rep of last set — session complete.
          _completeSession(elapsed);
        }

      case KegelPhase.rest:
        // rest → squeeze (start next set)
        state = state.copyWith(
          currentPhase: KegelPhase.squeeze,
          currentSet: state.currentSet + 1,
          currentRep: 1,
          remainingSeconds: p.squeezeSeconds,
          isRunning: true,
          totalElapsedSeconds: elapsed,
        );
        _tick();

      case KegelPhase.idle:
      case KegelPhase.complete:
        break;
    }
  }

  void _completeSession(int elapsed) {
    state = state.copyWith(
      currentPhase: KegelPhase.complete,
      remainingSeconds: 0,
      isRunning: false,
      totalElapsedSeconds: elapsed,
    );
    _autoLogKegels();
  }

  // ── Side effects ────────────────────────────────────────────────────────

  void _vibrate() {
    Vibration.vibrate(duration: 200);
  }

  /// Auto-logs today's kegels habit once the session is complete.
  /// Uses the profile repository to resolve the active profile via the
  /// currently authenticated Supabase session — no user argument needed.
  Future<void> _autoLogKegels() async {
    try {
      final profileRepo = _ref.read(profileRepositoryProvider);
      final profile = await profileRepo.getActiveProfile();
      if (profile == null) return;

      final habitRepo = _ref.read(habitRepositoryProvider);
      await habitRepo.logHabitDay(
        profile.id,
        HabitType.kegels,
        DateTime.now(),
        true,
      );
    } catch (_) {
      // Auto-log is best-effort — do not surface errors to the timer UI.
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Single global kegel timer — only one session runs at a time.
final kegelTimerProvider =
    StateNotifierProvider<KegelTimerNotifier, KegelTimerState>(
  (ref) => KegelTimerNotifier(ref),
);
