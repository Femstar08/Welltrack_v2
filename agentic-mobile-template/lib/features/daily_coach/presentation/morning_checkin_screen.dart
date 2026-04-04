import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'morning_checkin_provider.dart';
import 'todays_plan_provider.dart';
import 'widgets/checkin_step_feeling.dart';
import 'widgets/checkin_step_sleep.dart';
import 'widgets/checkin_step_schedule.dart';
import 'widgets/checkin_step_vitality.dart';
import 'widgets/checkin_step_injuries.dart';

class MorningCheckInScreen extends ConsumerStatefulWidget {
  const MorningCheckInScreen({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<MorningCheckInScreen> createState() =>
      _MorningCheckInScreenState();
}

class _MorningCheckInScreenState extends ConsumerState<MorningCheckInScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(morningCheckInProvider(widget.profileId));
    final notifier = ref.read(morningCheckInProvider(widget.profileId).notifier);

    // Redirect immediately if today's check-in already exists
    if (state.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/daily-coach/plan');
      });
    }

    // Navigate to Today's Plan when submission completes
    ref.listen<MorningCheckInState>(
      morningCheckInProvider(widget.profileId),
      (previous, next) {
        if (previous != null && !previous.isComplete && next.isComplete) {
          // Invalidate plan provider so it reloads with the new prescription
          ref.invalidate(todaysPlanProvider(widget.profileId));
          context.go('/daily-coach/plan');
        }
        // Sync PageView to currentStep
        if (previous != null && previous.currentStep != next.currentStep) {
          _animateToStep(next.currentStep);
        }
      },
    );

    final theme = Theme.of(context);
    final progress = (state.currentStep + 1) / state.totalSteps;

    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${state.currentStep + 1} of ${state.totalSteps}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Dismiss',
          onPressed: () {
            if (state.currentStep == 0) {
              context.go('/');
            } else {
              notifier.previousStep();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Step 0 — How are you feeling?
          CheckInStepFeeling(
            selectedFeeling: state.feelingLevel,
            onFeelingSelected: (feeling) {
              notifier.setFeeling(feeling);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) notifier.nextStep();
              });
            },
          ),

          // Step 1 — Sleep quality
          CheckInStepSleep(
            autoSleepMinutes: state.autoSleepMinutes,
            sleepQualityOverride: state.sleepQualityOverride,
            overrideValue: state.sleepQuality,
            onOverride: notifier.overrideSleep,
            onUseAuto: notifier.useAutoSleep,
            onNext: notifier.nextStep,
          ),

          // Step 2 — Schedule today
          CheckInStepSchedule(
            selectedSchedule: state.scheduleType,
            onScheduleSelected: (schedule) {
              notifier.setSchedule(schedule);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) notifier.nextStep();
              });
            },
          ),

          // Step 3 — Vitality: morning erection Y/N (daily) + weekly quality slider (Sunday)
          CheckInStepVitality(
            morningErection: state.morningErection,
            erectionQualityWeekly: state.erectionQualityWeekly,
            isSunday: state.isSundayPrompt,
            showMorningErection: true,
            onMorningErection: notifier.setMorningErection,
            onErectionQuality: notifier.setErectionQuality,
            onNext: notifier.nextStep,
            onSkip: notifier.nextStep,
          ),

          // Step 4 — Injuries + Submit
          CheckInStepInjuries(
            injuriesNotes: state.injuriesNotes,
            isSubmitting: state.isSubmitting,
            error: state.error,
            onInjuriesChanged: notifier.setInjuries,
            onNoInjuries: () {
              notifier.setInjuries(null);
              notifier.submit();
            },
            onSubmit: notifier.submit,
          ),
        ],
      ),
    );
  }
}
