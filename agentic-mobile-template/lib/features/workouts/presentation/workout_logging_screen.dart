// lib/features/workouts/presentation/workout_logging_screen.dart
//
// JEFIT-style live workout logger. Single-page-per-exercise via a PageView,
// swipe-or-dot-tap to navigate, compact set table with auto-filled previous
// values, rest timer overlay, and PR celebration banner.
//
// Architecture notes:
// - liveSessionProvider owns all persisted state (sets, PRs).
// - restTimerProvider owns the countdown; this widget reacts to it.
// - The elapsed clock is driven by a local 1-second periodic Timer rather
//   than a StreamBuilder so it never misses a rebuild on a slow device.
// - TextEditingControllers for weight/reps are managed here because they are
//   purely ephemeral UI state — they are NOT part of the session provider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/workout_set_entity.dart';
import 'live_session_provider.dart';
import 'rest_timer_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutLoggingScreen extends ConsumerStatefulWidget {
  const WorkoutLoggingScreen({
    required this.profileId,
    required this.workoutId,
    this.planId,
    this.dayOfWeek,
    this.planName,
    super.key,
  });

  final String profileId;
  final String workoutId;

  /// If supplied, the screen loads exercises from this plan day on start.
  final String? planId;

  /// ISO day-of-week (1 = Monday … 7 = Sunday) for the plan exercises.
  final int? dayOfWeek;

  /// Display name for the plan (used as the workout session name).
  final String? planName;

  @override
  ConsumerState<WorkoutLoggingScreen> createState() =>
      _WorkoutLoggingScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutLoggingScreenState extends ConsumerState<WorkoutLoggingScreen>
    with TickerProviderStateMixin {
  // ── Elapsed clock ──────────────────────────────────────────────────────────
  late Timer _clockTimer;
  int _elapsedSeconds = 0;

  // ── Exercise PageView ──────────────────────────────────────────────────────
  late PageController _pageController;

  // ── Per-exercise set controllers ───────────────────────────────────────────
  // Outer list index = exercise index.
  // Inner list index = set row index (including any extra sets added by user).
  final List<List<_SetRowControllers>> _controllers = [];

  // ── PR banner animation ────────────────────────────────────────────────────
  AnimationController? _prBannerController;
  Animation<double>? _prBannerScale;
  bool _showPrBanner = false;
  Timer? _prBannerTimer;

  // ── Rest timer animation ───────────────────────────────────────────────────
  AnimationController? _restOverlayController;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // PR banner animation: scale 0 → 1.05 → 1.
    _prBannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _prBannerScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.05),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(
      parent: _prBannerController!,
      curve: Curves.easeOut,
    ));

    // Rest overlay fade-in animation.
    _restOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Start session load.
    Future.microtask(_startSession);

    // 1-second clock tick.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _prBannerTimer?.cancel();
    _prBannerController?.dispose();
    _restOverlayController?.dispose();
    _pageController.dispose();
    for (final exerciseControllers in _controllers) {
      for (final row in exerciseControllers) {
        row.dispose();
      }
    }
    super.dispose();
  }

  // ── Session initialisation ─────────────────────────────────────────────────

  Future<void> _startSession() async {
    final notifier = ref.read(liveSessionProvider.notifier);

    if (widget.planId != null && widget.dayOfWeek != null) {
      await notifier.startSession(
        profileId: widget.profileId,
        planId: widget.planId!,
        dayOfWeek: widget.dayOfWeek!,
        planName: widget.planName ?? 'Workout',
      );
    } else {
      await notifier.startAdHocSession(
        profileId: widget.profileId,
        name: widget.planName ?? 'Workout',
      );
    }

    // Build controller lists now that exercises are loaded.
    if (mounted) _rebuildControllers();
  }

  // ── Controller management ──────────────────────────────────────────────────

  /// Rebuilds the entire controller list from the current session state.
  /// Called once after session load. Subsequent extra-set additions use
  /// [_appendSetController].
  void _rebuildControllers() {
    final session = ref.read(liveSessionProvider);

    // Dispose old controllers.
    for (final exerciseControllers in _controllers) {
      for (final row in exerciseControllers) {
        row.dispose();
      }
    }
    _controllers.clear();

    for (final exercise in session.exercises) {
      final rows = <_SetRowControllers>[];
      for (final set in exercise.sets) {
        rows.add(_SetRowControllers.fromSet(set));
      }
      _controllers.add(rows);
    }

    setState(() {});
  }

  /// Appends one new set-row controller list for [exerciseIndex], pre-filled
  /// from the previous set's values where available.
  void _appendSetController(int exerciseIndex) {
    while (_controllers.length <= exerciseIndex) {
      _controllers.add([]);
    }

    final exerciseControllers = _controllers[exerciseIndex];
    final session = ref.read(liveSessionProvider);

    // Derive default values from the previous set in the current list.
    String weightDefault = '';
    String repsDefault = '';

    if (exerciseControllers.isNotEmpty) {
      final last = exerciseControllers.last;
      weightDefault = last.weight.text;
      repsDefault = last.reps.text;
    } else if (session.exercises.length > exerciseIndex) {
      final ex = session.exercises[exerciseIndex];
      if (ex.previousSets.isNotEmpty) {
        final prev = ex.previousSets.last;
        weightDefault =
            prev.weightKg != null ? _formatWeight(prev.weightKg!) : '';
        repsDefault = prev.reps?.toString() ?? '';
      }
    }

    exerciseControllers.add(
      _SetRowControllers(
        weight: TextEditingController(text: weightDefault),
        reps: TextEditingController(text: repsDefault),
      ),
    );

    setState(() {});
  }

  // ── PR banner ─────────────────────────────────────────────────────────────

  void _triggerPrBanner() {
    _prBannerTimer?.cancel();
    setState(() => _showPrBanner = true);
    _prBannerController?.forward(from: 0);
    HapticFeedback.heavyImpact();
    _prBannerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showPrBanner = false);
    });
  }

  // ── Set logging ───────────────────────────────────────────────────────────

  Future<void> _logSet(int exerciseIndex, int setIndex) async {
    final session = ref.read(liveSessionProvider);
    if (exerciseIndex >= session.exercises.length) return;
    if (exerciseIndex >= _controllers.length) return;
    if (setIndex >= _controllers[exerciseIndex].length) return;

    final controllers = _controllers[exerciseIndex][setIndex];
    final weightText = controllers.weight.text.trim();
    final repsText = controllers.reps.text.trim();

    final weightKg = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0) {
      _showInputError('Enter valid weight and reps before logging a set.');
      return;
    }

    final setNumber = setIndex + 1;
    final isNewPR = await ref.read(liveSessionProvider.notifier).logSet(
          exerciseIndex: exerciseIndex,
          setNumber: setNumber,
          weightKg: weightKg,
          reps: reps,
        );

    if (isNewPR) _triggerPrBanner();

    // Start rest timer.
    final exercise = session.exercises[exerciseIndex];
    ref.read(restTimerProvider.notifier).start(
          exercise.planExercise.restSeconds,
          exerciseName: exercise.displayName,
        );

    HapticFeedback.mediumImpact();
    setState(() {});
  }

  // ── Finish workflow ───────────────────────────────────────────────────────

  Future<void> _onFinishTapped() async {
    final session = ref.read(liveSessionProvider);
    final confirmed = await _showFinishDialog(
      context,
      setsCompleted: session.totalSetsCompleted,
      exercisesStarted: session.exercisesStarted,
    );
    if (!confirmed) return;

    try {
      final completed =
          await ref.read(liveSessionProvider.notifier).completeSession();
      ref.read(restTimerProvider.notifier).stop();
      if (mounted) {
        context.go('/workouts/summary/${completed.id}');
      }
    } catch (e) {
      if (mounted) {
        _showInputError('Failed to save workout: $e');
      }
    }
  }

  // ── Exit guard ────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final session = ref.read(liveSessionProvider);
    if (!session.hasAnyLogged) return true;
    return _showExitDialog(context);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatElapsed() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatWeight(double w) {
    if (w == w.truncateToDouble()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  void _showInputError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Page sync ─────────────────────────────────────────────────────────────

  void _syncPageToSession() {
    final session = ref.read(liveSessionProvider);
    final targetIndex = session.currentExerciseIndex;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(liveSessionProvider);
    final timerState = ref.watch(restTimerProvider);

    // Sync page controller when session index changes (e.g. from dot taps).
    ref.listen<LiveSessionState>(liveSessionProvider, (prev, next) {
      if (prev?.currentExerciseIndex != next.currentExerciseIndex) {
        _syncPageToSession();
      }
      // Rebuild controllers if exercises list grows (add exercise support).
      if (prev?.exercises.length != next.exercises.length) {
        _rebuildControllers();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !session.hasAnyLogged,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldExit = await _onWillPop();
          if (shouldExit && context.mounted) context.go('/workouts');
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: _buildAppBar(context, session, colorScheme),
        body: session.isLoading
            ? _buildLoadingState()
            : session.error != null
                ? _buildErrorState(session.error!)
                : _buildBody(context, session, timerState, colorScheme),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    LiveSessionState session,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () async {
          final shouldExit = await _onWillPop();
          if (shouldExit && context.mounted) context.go('/workouts');
        },
        tooltip: 'Exit workout',
      ),
      title: Text(
        widget.planName ?? 'Workout',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: false,
      actions: [
        // Elapsed timer badge.
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatElapsed(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Finish button.
        TextButton(
          onPressed: session.hasAnyLogged ? _onFinishTapped : null,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: const Text('Finish'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading / error
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading session…'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to start session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startSession,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main body
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    LiveSessionState session,
    RestTimerState timerState,
    ColorScheme colorScheme,
  ) {
    return Stack(
      children: [
        Column(
          children: [
            // ── PR banner ──────────────────────────────────────────────────
            _PrBanner(
              visible: _showPrBanner,
              scale: _prBannerScale,
              colorScheme: colorScheme,
            ),

            // ── Exercise PageView ──────────────────────────────────────────
            Expanded(
              child: session.exercises.isEmpty
                  ? _buildEmptyExercisesState(context, colorScheme)
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: session.exercises.length,
                      onPageChanged: (index) {
                        ref
                            .read(liveSessionProvider.notifier)
                            .goToExercise(index);
                      },
                      itemBuilder: (context, exerciseIndex) {
                        // Ensure controller list is large enough.
                        while (_controllers.length <= exerciseIndex) {
                          _controllers.add([]);
                        }
                        return _ExercisePage(
                          exerciseIndex: exerciseIndex,
                          exercise: session.exercises[exerciseIndex],
                          controllers: _controllers[exerciseIndex],
                          hasNewPR: session.newPRExerciseIds.contains(
                            session
                                .exercises[exerciseIndex].planExercise.exerciseId,
                          ),
                          onLogSet: (setIndex) =>
                              _logSet(exerciseIndex, setIndex),
                          onAddSet: () {
                            ref
                                .read(liveSessionProvider.notifier)
                                .addExtraSet(exerciseIndex);
                            _appendSetController(exerciseIndex);
                          },
                          onFillFromPrevious: (setIndex) {
                            _fillFromPrevious(exerciseIndex, setIndex);
                          },
                        );
                      },
                    ),
            ),

            // ── Exercise dot-nav ───────────────────────────────────────────
            if (session.exercises.isNotEmpty)
              _ExerciseDotNav(
                session: session,
                onDotTapped: (i) {
                  ref.read(liveSessionProvider.notifier).goToExercise(i);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),

        // ── Rest timer overlay ─────────────────────────────────────────────
        if (timerState.isRunning)
          _RestTimerOverlay(
            timerState: timerState,
            colorScheme: colorScheme,
            onSkip: () => ref.read(restTimerProvider.notifier).skip(),
            onExtend: () =>
                ref.read(restTimerProvider.notifier).extend(30),
          ),
      ],
    );
  }

  Widget _buildEmptyExercisesState(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 80,
            color: colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises in this plan day',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add exercises to your plan before logging.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _fillFromPrevious(int exerciseIndex, int setIndex) {
    final session = ref.read(liveSessionProvider);
    if (exerciseIndex >= session.exercises.length) return;
    final exercise = session.exercises[exerciseIndex];
    if (setIndex >= exercise.previousSets.length) return;

    final prev = exercise.previousSets[setIndex];
    if (exerciseIndex >= _controllers.length) return;
    if (setIndex >= _controllers[exerciseIndex].length) return;

    final controllers = _controllers[exerciseIndex][setIndex];
    if (prev.weightKg != null) {
      controllers.weight.text = _formatWeight(prev.weightKg!);
    }
    if (prev.reps != null) {
      controllers.reps.text = prev.reps.toString();
    }
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _showFinishDialog(
    BuildContext context, {
    required int setsCompleted,
    required int exercisesStarted,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Workout?'),
        content: Text(
          '$setsCompleted ${setsCompleted == 1 ? 'set' : 'sets'} across '
          '$exercisesStarted ${exercisesStarted == 1 ? 'exercise' : 'exercises'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Workout?'),
        content: const Text(
          'Your logged sets will not be saved. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SetRowControllers  — weight + reps TextEditingController pair per set row
// ─────────────────────────────────────────────────────────────────────────────

class _SetRowControllers {
  _SetRowControllers({
    required this.weight,
    required this.reps,
  });

  factory _SetRowControllers.fromSet(WorkoutSetEntity set) {
    String weightText = '';
    if (set.weightKg != null) {
      final w = set.weightKg!;
      weightText = (w == w.truncateToDouble())
          ? w.toInt().toString()
          : w.toStringAsFixed(1);
    }
    return _SetRowControllers(
      weight: TextEditingController(text: weightText),
      reps: TextEditingController(
        text: set.reps?.toString() ?? '',
      ),
    );
  }

  final TextEditingController weight;
  final TextEditingController reps;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExercisePage — full-height card rendered inside the PageView
// ─────────────────────────────────────────────────────────────────────────────

class _ExercisePage extends StatelessWidget {
  const _ExercisePage({
    required this.exerciseIndex,
    required this.exercise,
    required this.controllers,
    required this.hasNewPR,
    required this.onLogSet,
    required this.onAddSet,
    required this.onFillFromPrevious,
  });

  final int exerciseIndex;
  final LiveExerciseData exercise;
  final List<_SetRowControllers> controllers;
  final bool hasNewPR;
  final void Function(int setIndex) onLogSet;
  final VoidCallback onAddSet;
  final void Function(int setIndex) onFillFromPrevious;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ex = exercise.planExercise.exercise;
    final muscleGroups =
        ex?.muscleGroups.isNotEmpty == true ? ex!.muscleGroups : <String>[];
    final estimated1rm = exercise.bestEstimated1rm;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Exercise name ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  exercise.displayName,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              if (hasNewPR)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Muscle group chips ────────────────────────────────────────────
          if (muscleGroups.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: muscleGroups
                  .map((m) => _MuscleChip(label: m, colorScheme: colorScheme))
                  .toList(),
            ),

          // ── 1RM badge ─────────────────────────────────────────────────────
          if (estimated1rm != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Est. 1RM: ${estimated1rm.toStringAsFixed(1)} kg',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Set table ─────────────────────────────────────────────────────
          _SetTable(
            exerciseIndex: exerciseIndex,
            exercise: exercise,
            controllers: controllers,
            colorScheme: colorScheme,
            textTheme: textTheme,
            onLogSet: onLogSet,
            onAddSet: onAddSet,
            onFillFromPrevious: onFillFromPrevious,
          ),

          // ── Exercise notes ────────────────────────────────────────────────
          if (exercise.planExercise.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exercise.planExercise.notes!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bottom padding so content clears rest timer overlay on small phones.
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SetTable — the core logging UI
// ─────────────────────────────────────────────────────────────────────────────

class _SetTable extends StatelessWidget {
  const _SetTable({
    required this.exerciseIndex,
    required this.exercise,
    required this.controllers,
    required this.colorScheme,
    required this.textTheme,
    required this.onLogSet,
    required this.onAddSet,
    required this.onFillFromPrevious,
  });

  final int exerciseIndex;
  final LiveExerciseData exercise;
  final List<_SetRowControllers> controllers;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final void Function(int setIndex) onLogSet;
  final VoidCallback onAddSet;
  final void Function(int setIndex) onFillFromPrevious;

  @override
  Widget build(BuildContext context) {
    // Determine total number of rows: max(plan target sets, logged sets count,
    // controller count). Controllers may have extra sets added by the user.
    final rowCount = controllers.length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────────
          _SetHeaderRow(colorScheme: colorScheme, textTheme: textTheme),

          const Divider(height: 1, thickness: 0.5),

          // ── Set rows ───────────────────────────────────────────────────────
          ...List.generate(rowCount, (setIndex) {
            // Get the matching logged set from session state (may be null if
            // not yet completed).
            final loggedSet = setIndex < exercise.sets.length
                ? exercise.sets[setIndex]
                : null;

            // Get previous-session data for this set slot.
            final prevSet = setIndex < exercise.previousSets.length
                ? exercise.previousSets[setIndex]
                : null;

            final controllers_ = setIndex < controllers.length
                ? controllers[setIndex]
                : null;

            if (controllers_ == null) return const SizedBox.shrink();

            return _SetRow(
              setNumber: setIndex + 1,
              controllers: controllers_,
              loggedSet: loggedSet,
              prevSet: prevSet,
              colorScheme: colorScheme,
              textTheme: textTheme,
              onLog: () => onLogSet(setIndex),
              onFillFromPrevious: prevSet != null
                  ? () => onFillFromPrevious(setIndex)
                  : null,
            );
          }),

          // ── Add set row ────────────────────────────────────────────────────
          InkWell(
            onTap: onAddSet,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add Set',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SetHeaderRow
// ─────────────────────────────────────────────────────────────────────────────

class _SetHeaderRow extends StatelessWidget {
  const _SetHeaderRow({
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('SET', style: labelStyle, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('PREVIOUS', style: labelStyle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text('KG', style: labelStyle, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 54,
            child: Text('REPS', style: labelStyle, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 6),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SetRow — one row in the set table
// ─────────────────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.controllers,
    required this.colorScheme,
    required this.textTheme,
    required this.onLog,
    this.loggedSet,
    this.prevSet,
    this.onFillFromPrevious,
  });

  final int setNumber;
  final _SetRowControllers controllers;
  final WorkoutSetEntity? loggedSet;
  final WorkoutSetEntity? prevSet;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onLog;
  final VoidCallback? onFillFromPrevious;

  bool get _isCompleted => loggedSet?.completed == true;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: _isCompleted
          ? Colors.green.withValues(alpha: 0.09)
          : Colors.transparent,
      child: Column(
        children: [
          const Divider(height: 1, thickness: 0.3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Set number badge.
                SizedBox(
                  width: 28,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _isCompleted
                          ? Colors.green.shade600
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$setNumber',
                      textAlign: TextAlign.center,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _isCompleted
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Previous column — tappable to auto-fill.
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: onFillFromPrevious,
                    behavior: HitTestBehavior.opaque,
                    child: _PreviousCell(
                      prevSet: prevSet,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Weight field.
                SizedBox(
                  width: 64,
                  child: _CompactTextField(
                    controller: controllers.weight,
                    hint: '0',
                    colorScheme: colorScheme,
                    enabled: !_isCompleted,
                    isDecimal: true,
                  ),
                ),

                const SizedBox(width: 6),

                // Reps field.
                SizedBox(
                  width: 54,
                  child: _CompactTextField(
                    controller: controllers.reps,
                    hint: '0',
                    colorScheme: colorScheme,
                    enabled: !_isCompleted,
                    isDecimal: false,
                  ),
                ),

                const SizedBox(width: 6),

                // Complete tick button.
                SizedBox(
                  width: 36,
                  height: 36,
                  child: _isCompleted
                      ? Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 28,
                        )
                      : IconButton(
                          onPressed: onLog,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.check_circle_outline,
                            color: colorScheme.outline,
                            size: 28,
                          ),
                          tooltip: 'Log set',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PreviousCell — shows the previous session's weight × reps
// ─────────────────────────────────────────────────────────────────────────────

class _PreviousCell extends StatelessWidget {
  const _PreviousCell({
    required this.prevSet,
    required this.colorScheme,
    required this.textTheme,
  });

  final WorkoutSetEntity? prevSet;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (prevSet == null) {
      return Text(
        '—',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      );
    }

    final weight = prevSet!.weightKg;
    final reps = prevSet!.reps;

    if (weight == null && reps == null) {
      return Text(
        '—',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      );
    }

    final weightStr = weight != null
        ? (weight == weight.truncateToDouble()
            ? weight.toInt().toString()
            : weight.toStringAsFixed(1))
        : '?';
    final repsStr = reps?.toString() ?? '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$weightStr kg x $repsStr',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'tap to fill',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.primary.withValues(alpha: 0.7),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CompactTextField — gym-optimised number input
// ─────────────────────────────────────────────────────────────────────────────

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({
    required this.controller,
    required this.hint,
    required this.colorScheme,
    required this.enabled,
    required this.isDecimal,
  });

  final TextEditingController controller;
  final String hint;
  final ColorScheme colorScheme;
  final bool enabled;
  final bool isDecimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.4),
          ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.25),
          fontWeight: FontWeight.w400,
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        filled: true,
        fillColor: enabled
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MuscleChip
// ─────────────────────────────────────────────────────────────────────────────

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({
    required this.label,
    required this.colorScheme,
  });

  final String label;
  final ColorScheme colorScheme;

  Color _chipColor() {
    final l = label.toLowerCase();
    if (l.contains('chest')) return Colors.red.shade700;
    if (l.contains('back') || l.contains('lat')) return Colors.blue.shade700;
    if (l.contains('shoulder') || l.contains('delt')) {
      return Colors.purple.shade700;
    }
    if (l.contains('bicep') || l.contains('arm')) return Colors.orange.shade700;
    if (l.contains('tricep')) return Colors.deepOrange.shade700;
    if (l.contains('leg') ||
        l.contains('quad') ||
        l.contains('hamstring') ||
        l.contains('glut')) return Colors.green.shade700;
    if (l.contains('core') || l.contains('abs')) return Colors.teal.shade700;
    if (l.contains('calf')) return Colors.indigo.shade700;
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _chipColor().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _chipColor().withValues(alpha: 0.35),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _chipColor(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExerciseDotNav — progress dots at the bottom of the screen
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseDotNav extends StatelessWidget {
  const _ExerciseDotNav({
    required this.session,
    required this.onDotTapped,
  });

  final LiveSessionState session;
  final void Function(int) onDotTapped;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = session.exercises.length;
    final current = session.currentExerciseIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final isCompleted = session.exercises[i].sets
                .where((s) => s.completed)
                .length >=
                session.exercises[i].planExercise.targetSets;
            final isCurrent = i == current;

            Color dotColor;
            if (isCompleted) {
              dotColor = Colors.green.shade600;
            } else if (isCurrent) {
              dotColor = colorScheme.primary;
            } else {
              dotColor = colorScheme.outlineVariant;
            }

            return GestureDetector(
              onTap: () => onDotTapped(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PrBanner — animated golden PR celebration banner
// ─────────────────────────────────────────────────────────────────────────────

class _PrBanner extends StatelessWidget {
  const _PrBanner({
    required this.visible,
    required this.scale,
    required this.colorScheme,
  });

  final bool visible;
  final Animation<double>? scale;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return ScaleTransition(
      scale: scale ?? const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade700,
              Colors.amber.shade500,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Text(
              'New Personal Record!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.emoji_events, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RestTimerOverlay — circular countdown shown over the exercise card
// ─────────────────────────────────────────────────────────────────────────────

class _RestTimerOverlay extends StatelessWidget {
  const _RestTimerOverlay({
    required this.timerState,
    required this.colorScheme,
    required this.onSkip,
    required this.onExtend,
  });

  final RestTimerState timerState;
  final ColorScheme colorScheme;
  final VoidCallback onSkip;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label row.
            Row(
              children: [
                Icon(
                  Icons.hourglass_top,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  timerState.exerciseName != null
                      ? 'Rest — ${timerState.exerciseName}'
                      : 'Rest Period',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Circular countdown.
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: timerState.progress,
                      strokeWidth: 8,
                      backgroundColor:
                          colorScheme.outlineVariant.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        timerState.progress > 0.3
                            ? colorScheme.primary
                            : Colors.orange.shade600,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        timerState.formattedTime,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'rest',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Skip'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onExtend,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+30s'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
