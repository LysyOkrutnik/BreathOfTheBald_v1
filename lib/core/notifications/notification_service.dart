import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
    // Without this, `tz.local` silently defaults to UTC — every "10:00"
    // daily reminder and every zonedSchedule call would fire at 10:00 UTC
    // (e.g. noon in Poland during CEST) instead of the device's actual wall
    // clock. Best-effort: a failure here just leaves tz.local at UTC, same
    // as before this fix existed, rather than crashing init().
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e, st) {
      developer.log('Could not resolve device timezone, defaulting to UTC',
          name: 'NotificationService', error: e, stackTrace: st);
    }
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
  ///
  /// Returns `true` when something was actually scheduled with the OS (exact
  /// or not), `false` when it wasn't (past `when`, or the plugin call
  /// itself failed) — used to be a `void` that swallowed every failure, so a
  /// planned reminder could silently never fire with the app reporting
  /// success regardless. Checking `canScheduleExactAlarms()` up front and
  /// falling back to an inexact alarm (rather than always requesting exact
  /// and letting the plugin throw when the permission isn't granted) means a
  /// user who never grants "Alarms & reminders" still gets a reminder, just
  /// a less precisely-timed one, instead of none at all.
  Future<bool> scheduleOneTime({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!when.isAfter(DateTime.now())) return false; // never schedule in the past
    try {
      final exactAllowed = await canScheduleExactAlarms();
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
        androidScheduleMode: exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (e, st) {
      developer.log('Error scheduling planned reminder',
          name: 'NotificationService', error: e, stackTrace: st);
      return false;
    }
  }

  /// Displays a notification immediately — used to bridge an incoming FCM
  /// push into a visible system notification while the app is in the
  /// foreground. Android auto-displays a "notification"-payload FCM message
  /// on its own only while the app is backgrounded/killed; in the
  /// foreground, FCM instead just delivers it to `FirebaseMessaging.onMessage`
  /// for the app to show manually, which is what this is for.
  Future<void> showNow({required String title, required String body}) async {
    try {
      await _notificationsPlugin.show(
        // A push doesn't carry a stable id of its own — a random-ish one
        // (current time mod a large range) is enough to avoid colliding
        // with `dailyReminderId`/plan ids and to let more than one push
        // stack instead of replacing each other.
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'push_channel_id',
            'Announcements',
            channelDescription: 'Messages sent from the app team.',
            importance: Importance.max,
            priority: Priority.high,
            autoCancel: true,
            icon: 'ic_stat_notification',
            largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e, st) {
      developer.log('Error showing push notification',
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
