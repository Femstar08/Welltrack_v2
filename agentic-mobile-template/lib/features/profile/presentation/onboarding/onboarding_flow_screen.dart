import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_repository.dart';
import 'onboarding_state.dart';
import 'screens/welcome_screen.dart';
import 'screens/goal_selection_screen.dart';
import 'screens/focus_intensity_screen.dart';
import 'screens/quick_profile_screen.dart';
import 'screens/connect_devices_screen.dart';
import 'screens/focus_introduction_screen.dart';
import 'screens/baseline_summary_screen.dart';
import 'widgets/onboarding_progress_dots.dart';
import '../profile_provider.dart';
import '../../../../shared/core/router/app_router.dart';
import '../../../../shared/core/logging/app_logger.dart';

final _logger = AppLogger();

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;
  String? _profileId;

  @override
  void initState() {
    super.initState();
    // Defer provider modification to avoid "modified during build" error
    Future.microtask(() => _loadProfileId());
  }

  Future<void> _loadProfileId() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      await ref.read(activeProfileProvider.notifier).loadActiveProfile();
      final profile = ref.read(activeProfileProvider).valueOrNull;
      if (mounted && profile != null) {
        setState(() => _profileId = profile.id);
      }
    } catch (e) {
      // Non-fatal: user may be creating their first profile
      _logger.warning('Onboarding: Could not load existing profile: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  Future<void> _complete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No authenticated user');
      _logger.info('Onboarding _complete: userId=$userId');

      final data = ref.read(onboardingDataProvider);
      // Use repository directly so exceptions propagate (the notifier
      // swallows errors internally and sets AsyncValue.error instead).
      final repository = ref.read(profileRepositoryProvider);

      // Build update fields from collected data
      final updateFields = <String, dynamic>{
        if (data.primaryGoal != null) 'primary_goal': data.primaryGoal,
        if (data.goalIntensity != null) 'goal_intensity': data.goalIntensity,
        if (data.heightCm != null) 'height_cm': data.heightCm,
        if (data.weightKg != null) 'weight_kg': data.weightKg,
        if (data.activityLevel != null) 'activity_level': data.activityLevel,
        if (data.estimatedDateOfBirth != null)
          'date_of_birth': data.estimatedDateOfBirth!
              .toIso8601String()
              .split('T')
              .first,
      };
      _logger.debug('Onboarding _complete: updateFields=$updateFields');

      // Ensure wt_users row exists before any profile operations
      final email = Supabase.instance.client.auth.currentUser?.email;
      final fallbackName = email?.split('@').first ?? 'User';
      await repository.ensureUserExists(userId, displayName: fallbackName);

      // Load existing profile (trigger should have created one on signup)
      _logger.info('Onboarding _complete: loading active profile...');
      final existingProfile = await repository.getActiveProfile();
      _logger.info('Onboarding _complete: existingProfile=${existingProfile?.id}');

      if (existingProfile != null) {
        _logger.info('Onboarding _complete: updating profile ${existingProfile.id}');
        await repository.updateProfile(existingProfile.id, updateFields);
        _logger.info('Onboarding _complete: profile updated');
      } else {
        // No profile exists — create one (use 'parent' to match DB enum)
        _logger.info('Onboarding _complete: creating new profile for $fallbackName');
        await repository.createProfile(
          userId: userId,
          profileType: 'parent',
          displayName: fallbackName,
          dateOfBirth: data.estimatedDateOfBirth,
          heightCm: data.heightCm,
          weightKg: data.weightKg,
          activityLevel: data.activityLevel,
          primaryGoal: data.primaryGoal,
          goalIntensity: data.goalIntensity,
          isPrimary: true,
        );
        _logger.info('Onboarding _complete: profile created');
      }

      _logger.info('Onboarding _complete: marking onboarding complete...');
      await repository.markOnboardingComplete(userId);
      _logger.info('Onboarding _complete: onboarding marked complete');

      if (!mounted) return;
      ref.read(onboardingCompleteProvider.notifier).state = true;

      // Reload the profile into the notifier for the rest of the app
      await ref.read(activeProfileProvider.notifier).loadActiveProfile();
      final updatedProfile = ref.read(activeProfileProvider).valueOrNull;
      if (updatedProfile != null) {
        ref.read(activeProfileIdProvider.notifier).state = updatedProfile.id;
        ref.read(activeDisplayNameProvider.notifier).state =
            updatedProfile.displayName;
      }

      if (mounted) context.go('/');
    } catch (e, stack) {
      _logger.error('Onboarding _complete ERROR: $e', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            duration: const Duration(seconds: 8),
          ),
        );
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set default intensity if not yet set
    final data = ref.watch(onboardingDataProvider);
    if (data.goalIntensity == null) {
      Future.microtask(() {
        ref.read(onboardingDataProvider.notifier).setGoalIntensity('moderate');
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    if (_currentPage > 0 && _currentPage < 7)
                      GestureDetector(
                        onTap: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                          setState(() => _currentPage--);
                        },
                        child: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    const Spacer(),
                  ],
                ),
              ),
            if (_currentPage > 0) const SizedBox(height: 8),
            if (_currentPage > 0)
              OnboardingProgressDots(currentPage: _currentPage),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  WelcomeScreen(onContinue: _nextPage),
                  GoalSelectionScreen(onContinue: _nextPage),
                  FocusIntensityScreen(onContinue: _nextPage),
                  QuickProfileScreen(onContinue: _nextPage),
                  ConnectDevicesScreen(
                    onContinue: _nextPage,
                    profileId: _profileId,
                  ),
                  FocusIntroductionScreen(onContinue: _nextPage),
                  BaselineSummaryScreen(onComplete: _complete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
