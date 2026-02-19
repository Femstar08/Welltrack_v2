import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/app.dart';
import 'package:welltrack/shared/core/storage/local_storage_service.dart';
import 'package:welltrack/shared/core/network/connectivity_service.dart';
import 'package:welltrack/shared/core/health/health_service.dart';
import 'package:welltrack/shared/core/sync/sync_engine.dart';
import 'package:welltrack/features/auth/data/auth_repository.dart';
import 'package:welltrack/features/auth/domain/user_entity.dart';
import 'package:welltrack/shared/core/logging/app_logger.dart';

// Mocks
class MockLocalStorageService extends Fake implements LocalStorageService {
  @override
  Future<void> init() async {}
}

class MockConnectivityService extends Fake implements ConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<void> init() async {
     _controller.add(true);
  }
  
  @override
  Stream<bool> get connectivityStream => _controller.stream;
  
  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void dispose() {
    _controller.close();
  }
}

class MockHealthService extends Fake implements HealthService {
  @override
  Future<void> initialize() async {}
}

class MockSyncEngine extends StateNotifier<SyncState> implements SyncEngine {
  MockSyncEngine() : super(const SyncState());

  @override
  Future<void> startSync() async {}
  
  @override
  void stopSync() {}

  @override
  Future<void> syncNow() async {}

  @override
  SyncState getSyncStatus() => state;
}

class MockAuthRepository extends Fake implements AuthRepository {
  @override
  Stream<UserEntity?> onAuthStateChange() {
    return Stream.value(null);
  }

  @override
  UserEntity? getCurrentUser() {
    return null;
  }
}

void main() {
  setUpAll(() {
    // Initialize Logger
    AppLogger().init();

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
  
    // Initialize Supabase with dummy values
    try {
      Supabase.instance; 
    } catch (_) {
      Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'dummy',
        debug: false,
      );
    }
  });

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          connectivityServiceProvider.overrideWithValue(MockConnectivityService()),
          healthServiceProvider.overrideWithValue(MockHealthService()),
          syncEngineProvider.overrideWith((ref) => MockSyncEngine()),
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
        child: const WellTrackApp(),
      ),
    );

    // Verify app shows initialization loading
    expect(find.text('Initializing WellTrack...'), findsOneWidget);
    
    // Pump to allow async initialization to complete
    await tester.pump();
  });
}
