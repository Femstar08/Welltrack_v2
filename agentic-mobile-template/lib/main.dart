import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
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

    // Run app with ProviderScope and initialization
    runApp(
      const ProviderScope(
        child: WellTrackApp(),
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
