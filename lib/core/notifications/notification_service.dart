import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Single shared instance. Overridden in `main()` with the instance that has
/// already been initialized, so the whole app reuses one plugin connection.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// All reminders share one id so scheduling a new time replaces the previous
  /// one instead of stacking duplicate daily notifications.
  static const int dailyReminderId = 0;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // White silhouette of the app's swirl logo; Android requires the status-bar
    // icon to be a transparent monochrome glyph, not the full launcher icon.
    const androidSettings =
        AndroidInitializationSettings('ic_stat_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  /// Requests permission to schedule exact alarms (Android 12+). Needed so a
  /// planned-session reminder fires at the precise minute rather than whenever
  /// the OS next batches alarms.
  Future<void> requestExactAlarmsPermission() async {
    try {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    } catch (e, st) {
      developer.log('Exact-alarm permission request failed',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  /// Whether the app is currently allowed to schedule exact-time alarms.
  /// Checked before ever prompting, so the (quite heavy — it navigates out
  /// to a system Settings screen) request only ever fires once, from an
  /// explicit in-context card, not silently on every Plan tab visit.
  Future<bool> canScheduleExactAlarms() async {
    try {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Null means "not applicable" (e.g. iOS, or an old Android that never
      // needed this permission) — treat that as already fine.
      return await android?.canScheduleExactNotifications() ?? true;
    } catch (e, st) {
      developer.log('Exact-alarm permission check failed',
          name: 'NotificationService', error: e, stackTrace: st);
      return true;
    }
  }

  /// Schedules a one-off reminder at [when]. Used for the "5 minutes before a
  /// planned session" notification. The [id] should be unique per plan.
  Future<void> scheduleOneTime({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!when.isAfter(DateTime.now())) return; // never schedule in the past
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'planned_session_channel_id',
            'Planned Sessions',
            channelDescription: 'Reminders before your planned breathing sessions.',
            importance: Importance.max,
            priority: Priority.high,
            autoCancel: true,
            icon: 'ic_stat_notification',
            largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      developer.log('Error scheduling planned reminder',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e, st) {
      developer.log('Error cancelling notification $id',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  /// Schedules (or reschedules) the recurring daily reminder at [hour]:[minute].
  Future<void> scheduleDailyReminder({
    required String title,
    required String body,
    int hour = 10,
    int minute = 0,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        dailyReminderId,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel_id',
            'Daily Reminder',
            channelDescription: 'This channel is used for daily reminders.',
            importance: Importance.max,
            priority: Priority.high,
            autoCancel: true,
            icon: 'ic_stat_notification',
            largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log('Daily reminder scheduled for '
          '$hour:${minute.toString().padLeft(2, '0')}');
    } catch (e, st) {
      developer.log('Error scheduling reminder',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _notificationsPlugin.cancel(dailyReminderId);
    } catch (e, st) {
      developer.log('Error cancelling reminder',
          name: 'NotificationService', error: e, stackTrace: st);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
