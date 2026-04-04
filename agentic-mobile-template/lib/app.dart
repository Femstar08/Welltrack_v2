import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/health/data/health_background_sync.dart';
import 'features/health/presentation/health_connections_provider.dart';
import 'features/profile/presentation/profile_provider.dart';
import 'features/reminders/data/notification_service.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'shared/core/health/health_service.dart';
import 'shared/core/router/app_router.dart';
import 'shared/core/theme/app_theme.dart';
import 'shared/core/storage/local_storage_service.dart';
import 'shared/core/network/connectivity_service.dart';
import 'shared/core/sync/sync_engine.dart';
import 'shared/core/logging/app_logger.dart';
import 'features/settings/presentation/rest_timer_settings.dart';
import 'features/workouts/presentation/rest_timer_provider.dart';

/// Root application widget for WellTrack
class WellTrackApp extends ConsumerStatefulWidget {
  const WellTrackApp({super.key});

  @override
  ConsumerState<WellTrackApp> createState() => _WellTrackAppState();
}

class _WellTrackAppState extends ConsumerState<WellTrackApp> {
  bool _isInitialized = false;
  String? _initError;
  final AppLogger _logger = AppLogger();
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initDeepLinkListener();
  }

  /// Listens for incoming deep links while the app is already running (resumed
  /// from background) and routes OAuth callbacks to the correct provider.
  void _initDeepLinkListener() {
    if (kIsWeb) return;
    try {
      final appLinks = AppLinks();
      _deepLinkSub = appLinks.uriLinkStream.listen(
        _handleOAuthDeepLink,
        onError: (Object err) {
          _logger.warning('Deep link stream error: $err');
        },
      );
    } catch (e) {
      _logger.warning('Could not set up deep link listener: $e');
    }
  }

  /// Dispatches an OAuth callback URI to the appropriate provider.
  ///
  /// Supported paths:
  ///   - `welltrack://oauth/garmin/callback?oauth_token=X&oauth_verifier=Y`
  ///   - `welltrack://oauth/strava/callback?code=X`
  Future<void> _handleOAuthDeepLink(Uri uri) async {
    _logger.info('Deep link received: $uri');
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || profileId.isEmpty) {
      _logger.warning('OAuth callback received but no active profile — ignoring');
      return;
    }

    if (uri.scheme != 'welltrack' || uri.host != 'oauth') return;

    // CSRF protection: verify state parameter matches what we sent (SEC-003)
    final returnedState = uri.queryParameters['state'];
    final expectedState = ref.read(pendingOAuthStateProvider);
    if (expectedState != null && returnedState != expectedState) {
      _logger.warning('OAuth state mismatch — possible CSRF attack. '
          'Expected: $expectedState, got: $returnedState');
      return;
    }
    // Clear pending state after validation
    ref.read(pendingOAuthStateProvider.notifier).state = null;

    if (uri.path == '/garmin/callback') {
      // Garmin OAuth 2.0 returns an authorization code.
      // Also check oauth_verifier for backwards compatibility.
      final code = uri.queryParameters['code'] ??
          uri.queryParameters['oauth_verifier'];
      if (code != null && code.isNotEmpty) {
        _logger.info('Garmin OAuth code received, completing connection…');
        await ref
            .read(healthConnectionsProvider(profileId).notifier)
            .connectGarmin(code, garminOAuthRedirectUri);
      }
    } else if (uri.path == '/strava/callback') {
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        _logger.info('Strava OAuth code received, completing connection…');
        await ref
            .read(healthConnectionsProvider(profileId).notifier)
            .connectStrava(code);
      }
    }
  }

  /// Initialize core services before app starts
  Future<void> _initializeServices() async {
    try {
      _logger.info('Initializing core services...');

      // Initialize local storage (Hive boxes)
      final storageService = ref.read(localStorageServiceProvider);
      await storageService.init();
      _logger.info('Local storage initialized');

      // Load persisted rest timer settings
      final savedAlertMode = await loadRestTimerAlertMode();
      ref.read(restTimerAlertModeProvider.notifier).state = savedAlertMode;
      final savedDuration = await loadDefaultRestTimerDuration();
      ref.read(defaultRestTimerSecondsProvider.notifier).state = savedDuration;

      // Initialize connectivity service
      final connectivityService = ref.read(connectivityServiceProvider);
      await connectivityService.init();
      _logger.info('Connectivity service initialized');

      // Initialize health service (configures Health Connect / HealthKit)
      final healthService = ref.read(healthServiceProvider);
      await healthService.initialize();
      _logger.info('Health service initialized');

      // Initialize SharedPreferences and wire background sync provider
      final prefs = await SharedPreferences.getInstance();
      final bgSync = HealthBackgroundSync(preferences: prefs);
      ref.read(healthBackgroundSyncOverrideProvider.notifier).state = bgSync;
      _logger.info('Health background sync provider configured');

      // Start sync engine
      final syncEngine = ref.read(syncEngineProvider.notifier);
      await syncEngine.startSync();
      _logger.info('Sync engine started');

      // Initialize notification service (non-fatal if it fails)
      if (!kIsWeb) {
        try {
          final notificationService = ref.read(notificationServiceProvider);
          await notificationService.initialize(
            onNotificationTap: (payload) {
              final route = notificationService.handleNotificationTap(payload);
              if (route != null) {
                try {
                  final router = ref.read(goRouterProvider);
                  router.go(route);
                } catch (_) {}
              }
            },
          );
          await notificationService.requestPermissions();
          _logger.info('Notification service initialized');
        } catch (e) {
          _logger.warning('Notification service init failed (non-fatal): $e');
        }
      }

      // Restore auth session state if user is already logged in
      await _restoreSessionState();

      // Re-schedule all active reminders on app launch.
      // Notifications are lost if the app is force-stopped or the OS kills it,
      // so we re-register them every launch to guarantee they fire.
      if (!kIsWeb) {
        try {
          final profileId = ref.read(activeProfileIdProvider);
          if (profileId != null && profileId.isNotEmpty) {
            final reminderRepo = ref.read(reminderRepositoryProvider);
            final notifService = ref.read(notificationServiceProvider);
            final activeReminders =
                await reminderRepo.getActiveReminders(profileId);
            for (final reminder in activeReminders) {
              await notifService.scheduleRepeatingNotification(reminder);
            }
            _logger.info(
              'Re-scheduled ${activeReminders.length} active reminders',
            );
          }
        } catch (e) {
          _logger.warning('Reminder re-scheduling failed (non-fatal): $e');
        }
      }

      // Register background health sync (after session restore so profile is available)
      // Workmanager is not supported on web — skip entirely
      if (!kIsWeb) {
        try {
          final bgSyncInstance = ref.read(healthBackgroundSyncOverrideProvider);
          if (bgSyncInstance != null) {
            await bgSyncInstance.initialize();
            await bgSyncInstance.registerPeriodicSync();
            _logger.info('Health background sync registered');

            // Trigger initial sync if user is authenticated with a profile
            final profileId = ref.read(activeProfileIdProvider);
            if (profileId != null && profileId.isNotEmpty) {
              final isDue = await bgSyncInstance.isSyncDue();
              if (isDue) {
                unawaited(bgSyncInstance.syncNow(profileId).catchError((e) {
                  _logger.warning('Initial health sync failed: $e');
                }));
                _logger.info('Initial health sync triggered');
              }
            }
          }
        } catch (e) {
          _logger.warning('Health background sync setup failed (non-fatal): $e');
        }
      } else {
        _logger.info('Skipping background sync on web platform');
      }

      setState(() {
        _isInitialized = true;
      });

      _logger.info('All core services initialized successfully');

      // If the app was cold-launched by a notification tap, navigate to the
      // target route now that the router and auth state are both live.
      // We use a post-frame callback so the router widget tree is fully built
      // before we attempt to navigate.
      final coldLaunchRoute = ref.read(notificationLaunchRouteProvider);
      if (coldLaunchRoute != null) {
        // Clear the provider so a subsequent hot-restart doesn't re-navigate.
        ref.read(notificationLaunchRouteProvider.notifier).state = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            ref.read(goRouterProvider).go(coldLaunchRoute);
            _logger.info(
              'Navigated to notification cold-launch route: $coldLaunchRoute',
            );
          } catch (e) {
            _logger.warning('Cold-launch navigation failed (non-fatal): $e');
          }
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize core services', e, stackTrace);
      setState(() {
        _initError = e.toString();
        _isInitialized = true; // Mark as initialized even on error to show error screen
      });
    }
  }

  /// Restore onboarding and profile state from the database
  /// when the app starts with an existing Supabase session.
  Future<void> _restoreSessionState() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _logger.info('No existing session, skipping state restore');
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      _logger.info('Restoring session state for user $userId');

      // Fetch onboarding status from wt_users
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.fetchUserProfile(userId);

      ref.read(onboardingCompleteProvider.notifier).state =
          user.onboardingCompleted;
      _logger.info(
          'Onboarding complete: ${user.onboardingCompleted}');

      if (user.onboardingCompleted) {
        // Load active profile for dashboard
        await ref
            .read(activeProfileProvider.notifier)
            .loadActiveProfile();
        final profile = ref.read(activeProfileProvider).valueOrNull;
        if (profile != null) {
          ref.read(activeProfileIdProvider.notifier).state = profile.id;
          ref.read(activeDisplayNameProvider.notifier).state =
              profile.displayName;
          _logger.info('Restored active profile: ${profile.id}');
        } else {
          _logger.warning(
              'No active profile found for user $userId — '
              'wt_profiles may not have is_primary=true');
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Error restoring session state', e, stackTrace);
      // Non-fatal: app will redirect to login or onboarding as needed
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    // Stop sync engine — guarded because ref may be dead during test teardown
    try {
      if (mounted) {
        final syncEngine = ref.read(syncEngineProvider.notifier);
        syncEngine.stopSync();
      }
    } catch (_) {
      // Non-fatal: sync engine cleanup is best-effort
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always use a single MaterialApp.router to avoid InheritedWidget
    // deactivation assertions when switching between widget trees.
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'WellTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Show loading overlay while initializing
        if (!_isInitialized) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'Initializing WellTrack...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Show error overlay if initialization failed
        if (_initError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Initialization Failed',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _initError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isInitialized = false;
                          _initError = null;
                        });
                        _initializeServices();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return child ?? const SizedBox.shrink();
      },
    );
  }
}
