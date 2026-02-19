import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reminder_entity.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for managing push notifications and local notifications
class NotificationService {

  NotificationService(this._flutterLocalNotificationsPlugin);
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  /// Initializes the notification service
  ///
  /// Sets up Android and iOS notification channels
  /// Configures notification tap handlers for deep linking
  Future<void> initialize({
    required Function(String?) onNotificationTap,
  }) async {
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

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
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
    // If the reminder time is in the past, don't schedule
    if (tz.TZDateTime.from(reminder.remindAt, tz.local)
        .isBefore(tz.TZDateTime.now(tz.local))) {
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
      tz.TZDateTime.from(reminder.remindAt, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedules a repeating notification
  Future<void> scheduleRepeatingNotification(ReminderEntity reminder) async {
    if (reminder.repeatRule == null || reminder.repeatRule == 'once') {
      return scheduleNotification(reminder);
    }

    // If the reminder time is in the past, calculate next occurrence
    final nextDate = reminder.getNextReminderTime();
    if (nextDate == null) {
      return scheduleNotification(reminder);
    }

    final nextScheduledDate = tz.TZDateTime.from(nextDate, tz.local);

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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
        return '/meals';
      case 'workouts':
        return '/workouts';
      case 'custom':
        return '/daily-view';
      default:
        return '/home';
    }
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  return NotificationService(plugin);
});
