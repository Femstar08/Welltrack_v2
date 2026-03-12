import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'features/health/data/health_background_sync.dart';
import 'features/reminders/data/notification_service.dart';
import 'shared/core/constants/api_constants.dart';
import 'shared/core/logging/app_logger.dart';

/// Main entry point for WellTrack app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  final logger = AppLogger();
  logger.init();
  logger.info('WellTrack starting...');

  try {
    // Initialize Hive before runApp to avoid platform channel deadlock
    await Hive.initFlutter();
    await Hive.openBox('settings');
    logger.info('Hive initialized');

    // Initialize Supabase
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      anonKey: ApiConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    logger.info('Supabase initialized');

    // Initialize SharedPreferences (needed for HealthBackgroundSync)
    final prefs = await SharedPreferences.getInstance();
    logger.info('SharedPreferences initialized');

    // Initialize WorkManager and register periodic health sync
    final healthSync = HealthBackgroundSync(preferences: prefs);
    await healthSync.initialize();
    await healthSync.registerPeriodicSync();
    logger.info('Health background sync registered (every 6 hours)');

    // Detect if this cold-start was triggered by a notification tap.
    //
    // flutter_local_notifications requires getNotificationAppLaunchDetails()
    // to be called BEFORE runApp() — once the engine is running the launch
    // intent data is lost. We resolve the payload into a route string here
    // and pass it as a ProviderScope override so WellTrackApp can navigate
    // to the correct screen as soon as the router is ready.
    String? notificationLaunchRoute;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final launchDetails = await plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = launchDetails?.notificationResponse?.payload;
        // Re-use the same module→route mapping as NotificationService.handleNotificationTap()
        if (payload != null) {
          final parts = payload.split(':');
          if (parts.length == 2) {
            final module = parts[0];
            notificationLaunchRoute = switch (module) {
              'supplements' => '/supplements',
              'meals'       => '/meals/log',
              'workouts'    => '/workouts',
              'custom'      => '/daily-view',
              _             => '/',
            };
          }
        }
        logger.info(
          'App cold-launched from notification — route: $notificationLaunchRoute',
        );
      }
    } catch (e) {
      // Non-fatal: the app will open normally without deep-linking
      logger.warning('Could not read notification launch details: $e');
    }

    // Run app with ProviderScope and initialization
    runApp(
      ProviderScope(
        overrides: [
          healthBackgroundSyncOverrideProvider.overrideWith((ref) => healthSync),
          // Expose the cold-launch route (null when launched normally) so that
          // WellTrackApp._initializeServices() can navigate after the router
          // is live.
          notificationLaunchRouteProvider.overrideWith(
            (ref) => notificationLaunchRoute,
          ),
        ],
        child: const WellTrackApp(),
      ),
    );
  } catch (e, stackTrace) {
    logger.fatal('Failed to initialize app', e, stackTrace);

    // Show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to start WellTrack',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
