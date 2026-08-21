import 'dart:developer' as developer;
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:okrutnik_breath/core/sync/sync_api_client.dart';

/// Short human-readable description of this device ("SM-A546B, Android
/// 14") — purely so the device-management list in Settings shows
/// something more useful than a bare registration date. Best-effort: any
/// failure here just means registration proceeds without a label.
Future<String?> _deviceLabel() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return '${info.model}, Android ${info.version.release}';
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return '${info.utsname.machine}, iOS ${info.systemVersion}';
    }
  } catch (e) {
    developer.log('Device label lookup failed',
        name: 'PushRegistration', error: e);
  }
  return null;
}

/// Requests notification permission, retrieves the FCM token, and registers
/// it with the backend. Call right after a successful login/register — a
/// token registered before the user is authenticated has no account to
/// attach to. Best-effort: push notifications are a nice-to-have, never a
/// blocker for login/sync, so any failure here is swallowed.
Future<void> registerPushToken(SyncApiClient apiClient) async {
  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await apiClient.registerDevice(token, label: await _deviceLabel());
    }
  } catch (e, st) {
    developer.log('Push token registration failed',
        name: 'PushRegistration', error: e, stackTrace: st);
  }
}
