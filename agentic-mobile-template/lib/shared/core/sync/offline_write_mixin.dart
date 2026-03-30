import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';

final _logger = AppLogger();

/// Wraps a Supabase write operation with offline-first behavior.
///
/// On success: returns normally.
/// On network error: queues the write to Hive for later sync.
/// On other errors: rethrows.
///
/// Usage in repositories:
/// ```dart
/// await offlineWrite(
///   table: 'wt_meals',
///   operation: 'insert',
///   data: mealData,
///   execute: () => _supabase.from('wt_meals').insert(mealData),
/// );
/// ```
Future<void> offlineWrite({
  required String table,
  required String operation,
  required Map<String, dynamic> data,
  required Future<void> Function() execute,
}) async {
  try {
    await execute();
  } on PostgrestException {
    // Supabase errors (constraint violations etc.) should propagate
    rethrow;
  } on AuthException {
    rethrow;
  } catch (e) {
    // Network errors, timeouts — queue for offline sync
    if (_isNetworkError(e)) {
      _logger.info(
          'Offline: queuing $operation on $table for later sync');
      await _queueWrite(table, operation, data);
    } else {
      rethrow;
    }
  }
}

bool _isNetworkError(dynamic error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('connection timed out') ||
      msg.contains('no internet') ||
      msg.contains('failed host lookup');
}

Future<void> _queueWrite(
  String table,
  String operation,
  Map<String, dynamic> data,
) async {
  try {
    final box = await Hive.openBox('offline_queue');
    final id = DateTime.now().microsecondsSinceEpoch;
    await box.put('pending_$id', {
      'id': id,
      'table': table,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'synced': false,
    });
  } catch (e) {
    _logger.error('Failed to queue offline write', e);
  }
}

/// Drains the offline queue and replays writes to Supabase.
/// Call this when connectivity is restored.
Future<int> drainOfflineQueue() async {
  try {
    final box = await Hive.openBox('offline_queue');
    final client = Supabase.instance.client;
    int synced = 0;

    final keys = box.keys.where((k) => k.toString().startsWith('pending_')).toList();

    for (final key in keys) {
      final entry = box.get(key) as Map<dynamic, dynamic>?;
      if (entry == null || entry['synced'] == true) continue;

      final table = entry['table'] as String;
      final operation = entry['operation'] as String;
      final data = jsonDecode(entry['data'] as String) as Map<String, dynamic>;

      try {
        if (operation == 'insert') {
          await client.from(table).insert(data);
        } else if (operation == 'upsert') {
          await client.from(table).upsert(data);
        } else if (operation == 'update') {
          final id = data.remove('id');
          if (id != null) {
            await client.from(table).update(data).eq('id', id);
          }
        }

        await box.delete(key);
        synced++;
        _logger.info('Synced offline write: $operation on $table');
      } catch (e) {
        _logger.warning('Failed to sync offline write: $e');
        // Leave in queue for next attempt
      }
    }

    return synced;
  } catch (e) {
    _logger.error('Failed to drain offline queue', e);
    return 0;
  }
}

/// Returns the count of pending offline writes.
Future<int> pendingOfflineWriteCount() async {
  try {
    final box = await Hive.openBox('offline_queue');
    return box.keys.where((k) => k.toString().startsWith('pending_')).length;
  } catch (_) {
    return 0;
  }
}
