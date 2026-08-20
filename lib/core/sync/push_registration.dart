import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:okrutnik_breath/core/sync/sync_api_client.dart';

/// Requests notification permission, retrieves the FCM token, and registers
/// it with the backend. Call right after a successful login/register — a
/// token registered before the user is authenticated has no account to
/// attach to. Best-effort: push notifications are a nice-to-have, never a
/// blocker for login/sync, so any failure here is swallowed.
Future<void> registerPushToken(SyncApiClient apiClient) async {
  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await apiClient.registerDevice(token);
  } catch (e, st) {
    developer.log('Push token registration failed', name: 'PushRegistration', error: e, stackTrace: st);
  }
}
