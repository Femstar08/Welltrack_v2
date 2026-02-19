import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/auth/data/auth_repository.dart';
import 'package:welltrack/features/health/data/health_background_sync.dart';
import 'package:welltrack/features/profile/presentation/profile_provider.dart';
import 'package:welltrack/shared/core/health/health_service.dart';
import 'package:welltrack/shared/core/router/app_router.dart';
import 'package:welltrack/shared/core/theme/app_theme.dart';
import 'package:welltrack/shared/core/storage/local_storage_service.dart';
import 'package:welltrack/shared/core/network/connectivity_service.dart';
import 'package:welltrack/shared/core/sync/sync_engine.dart';
import 'package:welltrack/shared/core/logging/app_logger.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize core services before app starts
  Future<void> _initializeServices() async {
    try {
      _logger.info('Initializing core services...');

      // Initialize local storage (Hive boxes)
      final storageService = ref.read(localStorageServiceProvider);
      await storageService.init();
      _logger.info('Local storage initialized');

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

      // Restore auth session state if user is already logged in
      await _restoreSessionState();

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
                bgSyncInstance.syncNow(profileId).catchError((e) {
                  _logger.warning('Initial health sync failed: $e');
                });
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
    // Stop sync engine
    try {
      final syncEngine = ref.read(syncEngineProvider.notifier);
      syncEngine.stopSync();
    } catch (e) {
      _logger.error('Error stopping sync engine', e);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while initializing
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Initializing WellTrack...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show error screen if initialization failed
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
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
        ),
      );
    }

    // Build main app
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'WellTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
