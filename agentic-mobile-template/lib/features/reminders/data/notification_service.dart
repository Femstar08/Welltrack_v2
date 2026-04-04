import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../domain/reminder_entity.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service for managing push notifications and local notifications
class NotificationService {

  NotificationService(this._flutterLocalNotificationsPlugin);
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  bool _tzInitialized = false;

  /// Ensures timezone database is initialized AND tz.local is set to device timezone.
  /// Must be called (and awaited) before any scheduling.
  Future<void> _ensureTimezonesInitialized() async {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback: use UTC offset to find a matching timezone
      try {
        final offset = DateTime.now().timeZoneOffset;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset.inMilliseconds) {
            tz.setLocalLocation(loc);
            break;
          }
        }
      } catch (_) {
        // Last resort: tz.local stays at UTC
      }
    }
    _tzInitialized = true;
  }

  /// Initializes the notification service
  ///
  /// Sets up Android and iOS notification channels
  /// Configures notification tap handlers for deep linking
  Future<void> initialize({
    required Function(String?) onNotificationTap,
  }) async {
    // Initialize timezones eagerly at startup
    await _ensureTimezonesInitialized();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        onNotificationTap(details.payload);
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'welltrack_reminders',
      'WellTrack Reminders',
      description: 'Notifications for meals, supplements, workouts, and other reminders',
      importance: Importance.high,
      playSound: true,
    );

    final androidImpl = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(androidChannel);

    // Request exact alarm permission (required on Android 12+ / API 31+)
    if (androidImpl != null) {
      try {
        final canScheduleExact = await androidImpl.canScheduleExactNotifications();
        if (canScheduleExact != true) {
          await androidImpl.requestExactAlarmsPermission();
        }
      } catch (_) {
        // Non-fatal: inexact alarms will still work
      }
    }
  }

  /// Requests notification permissions
  ///
  /// Returns true if permissions are granted
  Future<bool> requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      if (granted != true) return false;
    }

    // iOS permissions
    final iosImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted != true) return false;
    }

    return true;
  }

  /// Shows a local notification immediately
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'welltrack_reminders',
      'WellTrack Reminders',
      channelDescription: 'Notifications for meals, supplements, workouts, and other reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Schedules a notification for a specific reminder
  Future<void> scheduleNotification(ReminderEntity reminder) async {
    await _ensureTimezonesInitialized();

    // Build the scheduled time from reminder's date/time components in local timezone.
    // This avoids UTC/local confusion from Supabase round-trip.
    final scheduledDate = tz.TZDateTime(
      tz.local,
      reminder.remindAt.year,
      reminder.remindAt.month,
      reminder.remindAt.day,
      reminder.remindAt.hour,
      reminder.remindAt.minute,
    );

    // If the reminder time is in the past, don't schedule
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'welltrack_reminders',
      'WellTrack Reminders',
      channelDescription: 'Notifications for meals, supplements, workouts, and other reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Create payload for deep linking
    final payload = '${reminder.module}:${reminder.id}';

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      reminder.id.hashCode, // Use reminder ID hash as notification ID
      reminder.title,
      reminder.body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedules a repeating notification
  Future<void> scheduleRepeatingNotification(ReminderEntity reminder) async {
    await _ensureTimezonesInitialized();
    if (reminder.repeatRule == null || reminder.repeatRule == 'once') {
      return scheduleNotification(reminder);
    }

    // If the reminder time is in the past, calculate next occurrence
    final nextDate = reminder.getNextReminderTime();
    if (nextDate == null) {
      return scheduleNotification(reminder);
    }

    // Build TZDateTime from components in local timezone
    final nextScheduledDate = tz.TZDateTime(
      tz.local,
      nextDate.year,
      nextDate.month,
      nextDate.day,
      nextDate.hour,
      nextDate.minute,
    );

    const androidDetails = AndroidNotificationDetails(
      'welltrack_reminders',
      'WellTrack Reminders',
      channelDescription: 'Notifications for meals, supplements, workouts, and other reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = '${reminder.module}:${reminder.id}';

    // Schedule based on repeat rule
    switch (reminder.repeatRule) {
      case 'daily':
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          reminder.id.hashCode,
          reminder.title,
          reminder.body,
          nextScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.time, // Repeat at same time daily
        );
        break;
      case 'weekly':
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          reminder.id.hashCode,
          reminder.title,
          reminder.body,
          nextScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        break;
      default:
        // For monthly or custom, schedule single notification
        // In production, you'd need a background job to reschedule
        await scheduleNotification(reminder);
    }
  }

  /// Cancels a scheduled notification
  Future<void> cancelNotification(String reminderId) async {
    await _flutterLocalNotificationsPlugin.cancel(reminderId.hashCode);
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Gets pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Handles deep linking when notification is tapped
  ///
  /// Payload format: "module:reminderId"
  /// Returns route path for navigation
  String? handleNotificationTap(String? payload) {
    if (payload == null) return null;

    final parts = payload.split(':');
    if (parts.length != 2) return null;

    final module = parts[0];

    // Map module to route
    switch (module) {
      case 'supplements':
        return '/supplements';
      case 'meals':
        return '/meals/log';
      case 'workouts':
        return '/workouts';
      case 'custom':
        return '/plan';
      default:
        return '/';
    }
  }
}

/// Single shared plugin instance — must be the same one used everywhere
/// (main.dart cold-launch check, app.dart initialization, and reminder scheduling).
final FlutterLocalNotificationsPlugin sharedNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Provider for notification service — uses the shared plugin singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(sharedNotificationsPlugin);
});

/// Holds the GoRouter route derived from a notification that cold-launched the
/// app (i.e. the user tapped a notification while the app was terminated).
///
/// Populated in main() via a ProviderScope override before runApp() so the
/// value is available synchronously when the router first renders.
/// Consumed once by WellTrackApp._initializeServices() and then cleared.
final notificationLaunchRouteProvider = StateProvider<String?>((ref) => null);
