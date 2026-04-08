import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    
    
    
    try {
      final String currentTimeZone = DateTime.now().timeZoneName;
      
      
      debugPrint('🌎 System TimeZone detected: $currentTimeZone');
    } catch (e) {
      debugPrint('⚠️ Error detecting timezone: $e');
    }

    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      onDidReceiveLocalNotification: (id, title, body, payload) async {},
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        
      },
    );

    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('✅ Notification Service Fully Initialized');
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    const AndroidNotificationChannel workoutChannel = AndroidNotificationChannel(
      'scheduled_workout_channel_id',
      'Scheduled Workouts',
      description: 'Alerts for your planned breathing sessions.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
      'daily_reminder_channel_id',
      'Daily Reminders',
      description: 'Daily motivation to breathe.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(workoutChannel);
    await androidPlugin.createNotificationChannel(dailyChannel);
  }

  Future<bool> requestPermissions() async {
    
    final notificationStatus = await Permission.notification.request();
    
    
    
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? canSchedule = await androidPlugin.canScheduleExactNotifications();
      if (canSchedule == false) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    
    return notificationStatus.isGranted;
  }

  Future<void> scheduleReminderAtDateTime(DateTime dateTime, String title, String body, int id) async {
    try {
      if (!_isInitialized) await init();
      
      final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

      final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500]);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_workout_channel_id',
            'Scheduled Workouts',
            channelDescription: 'Alerts for your planned breathing sessions.',
            importance: Importance.max,
            priority: Priority.max,
            autoCancel: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            vibrationPattern: vibrationPattern,
            enableLights: true,
            color: Color(0xFF4DB6AC),
            ledColor: Color(0xFF4DB6AC),
            ledOnMs: 1000,
            ledOffMs: 500,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('❌ Error scheduling: $e');
    }
  }

  Future<void> scheduleDailyReminder() async {
    try {
      if (!_isInitialized) await init();
      await _notificationsPlugin.zonedSchedule(
        0,
        'The void is calling.',
        'Breathe, Beast.',
        _nextInstanceOfTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel_id',
            'Daily Reminders',
            channelDescription: 'Daily motivation to breathe.',
            importance: Importance.high,
            priority: Priority.high,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));
    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> showWelcomeNotification() async {
    try {
      if (!_isInitialized) await init();
      const androidDetails = AndroidNotificationDetails(
        'scheduled_workout_channel_id',
        'System Initialization',
        channelDescription: 'Used to initialize notification system.',
        importance: Importance.max,
        priority: Priority.max,
      );
      await _notificationsPlugin.show(999, 'Breath of the Bald', 'System powiadomień aktywny. Powodzenia Okrutniku!', const NotificationDetails(android: androidDetails));
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }
}
