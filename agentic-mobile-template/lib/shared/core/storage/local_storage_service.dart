import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';
import '../network/offline_queue.dart';

/// Service for managing Hive local database
class LocalStorageService {
  Box? _offlineQueueBox;
  final AppLogger _logger = AppLogger();
  bool _initialized = false;

  /// Check if storage is initialized
  bool get isInitialized => _initialized;

  /// Get the offline queue box
  Box get offlineQueueBox {
    if (_offlineQueueBox == null || !_initialized) {
      throw StateError(
          'LocalStorageService not initialized. Call init() first.');
    }
    return _offlineQueueBox!;
  }

  /// Initialize Hive database
  /// Note: Hive.initFlutter() must be called in main() before runApp()
  Future<void> init() async {
    try {
      if (_initialized) {
        _logger.info('LocalStorageService already initialized');
        return;
      }

      // Open boxes (Hive.initFlutter() already called in main())
      _offlineQueueBox = await Hive.openBox(OfflineQueue.boxName);

      _initialized = true;
      _logger.info('LocalStorageService initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Error initializing LocalStorageService', e, stackTrace);
      rethrow;
    }
  }

  /// Close all Hive boxes
  Future<void> close() async {
    if (_initialized) {
      await Hive.close();
      _offlineQueueBox = null;
      _initialized = false;
      _logger.info('LocalStorageService closed');
    }
  }

  /// Clear all data from Hive
  Future<void> clearAll() async {
    if (!_initialized) return;

    try {
      await _offlineQueueBox?.clear();
      _logger.info('Local storage cleared');
    } catch (e, stackTrace) {
      _logger.error('Error clearing local storage', e, stackTrace);
      rethrow;
    }
  }
}

/// Riverpod provider for LocalStorageService
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Riverpod provider for OfflineQueue
final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  if (!storageService.isInitialized) {
    throw StateError(
        'LocalStorageService must be initialized before creating OfflineQueue');
  }
  return OfflineQueue(storageService.offlineQueueBox);
});
