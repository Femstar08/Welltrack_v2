import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';

/// Service for secure storage operations using flutter_secure_storage
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final AppLogger _logger = AppLogger();

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  /// Write a value to secure storage
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
      _logger.debug('Secure storage write: $key');
    } catch (e, stackTrace) {
      _logger.error('Error writing to secure storage: $key', e, stackTrace);
      rethrow;
    }
  }

  /// Read a value from secure storage
  Future<String?> read({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      _logger.debug('Secure storage read: $key');
      return value;
    } catch (e, stackTrace) {
      _logger.error('Error reading from secure storage: $key', e, stackTrace);
      return null;
    }
  }

  /// Delete a value from secure storage
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
      _logger.debug('Secure storage delete: $key');
    } catch (e, stackTrace) {
      _logger.error('Error deleting from secure storage: $key', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all values from secure storage
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
      _logger.info('Secure storage cleared');
    } catch (e, stackTrace) {
      _logger.error('Error clearing secure storage', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> containsKey({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking key in secure storage: $key', e, stackTrace);
      return false;
    }
  }

  /// Read all values from secure storage
  Future<Map<String, String>> readAll() async {
    try {
      final all = await _storage.readAll();
      _logger.debug('Secure storage read all: ${all.length} items');
      return all;
    } catch (e, stackTrace) {
      _logger.error('Error reading all from secure storage', e, stackTrace);
      return {};
    }
  }
}

/// Riverpod provider for SecureStorageService
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
