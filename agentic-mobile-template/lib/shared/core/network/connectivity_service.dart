import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';

/// Service for monitoring network connectivity status
class ConnectivityService {
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  static final ConnectivityService _instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final AppLogger _logger = AppLogger();
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize connectivity monitoring
  Future<void> init() async {
    // Check initial connectivity
    final initialResult = await checkConnectivity();
    _connectivityController.add(initialResult);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOnline = _isConnected(results);
      _logger.info('Connectivity changed: ${isOnline ? 'online' : 'offline'}');
      _connectivityController.add(isOnline);
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isConnected(results);
    } catch (e, stackTrace) {
      _logger.error('Error checking connectivity', e, stackTrace);
      return false;
    }
  }

  /// Determine if device is connected based on connectivity results
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }

  /// Dispose resources
  void dispose() {
    _connectivityController.close();
  }
}

/// Riverpod provider for ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Riverpod StreamProvider for online status
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectivityStream;
});
