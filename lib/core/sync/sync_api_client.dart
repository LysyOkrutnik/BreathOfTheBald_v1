import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:okrutnik_breath/config/formatters.dart';
import 'package:okrutnik_breath/core/sync/auth_service.dart';
import 'package:okrutnik_breath/core/sync/sync_config.dart';

class SyncApiException implements Exception {
  SyncApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => 'SyncApiException($statusCode): $body';
}

/// Thin authenticated HTTP wrapper for every endpoint that needs a Bearer
/// token — sync/devices/challenges plus the authenticated auth endpoints
/// (refresh, change-password, logout-all, delete-account). Attaches the
/// stored JWT, decodes JSON, applies a request timeout, and turns a non-2xx
/// response into a typed exception (callers check `.isAuthError` to detect
/// an expired/revoked token) instead of a silently-wrong map.
class SyncApiClient {
  SyncApiClient(this._authService);
  final AuthService _authService;

  Future<Map<String, String>> _headers() async {
    final token = await _authService.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> pushSync(Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$syncApiBaseUrl/sync'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(syncRequestTimeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> pullSync({DateTime? since}) async {
    final uri = Uri.parse('$syncApiBaseUrl/sync').replace(
      // `toUtcIso` — a local-time DateTime's toIso8601String() has no
      // "Z"/offset suffix, which the server's `since` parsing (a plain
      // `Date.parse`) then reads back as if it already were UTC. Harmless
      // for a coarse cursor filter on this server (its container clock is
      // UTC anyway), but sending real UTC is the actually-correct fix
      // rather than relying on server-local time happening to match.
      queryParameters: since != null ? {'since': toUtcIso(since)} : null,
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(syncRequestTimeout);
    return _decodeObject(response);
  }

  Future<void> registerDevice(String fcmToken, {String? label}) async {
    final response = await http
        .post(
          Uri.parse('$syncApiBaseUrl/devices/register'),
          headers: await _headers(),
          body: jsonEncode(
              {'fcmToken': fcmToken, if (label != null) 'label': label}),
        )
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// Backs the "manage devices" list in Settings.
  Future<List<Map<String, dynamic>>> listDevices() async {
    final response = await http
        .get(Uri.parse('$syncApiBaseUrl/devices'), headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Only stops push to that device — not the same as logging it out (see
  /// devices.ts's own comment on why that isn't possible per-device today).
  Future<void> deleteDevice(String id) async {
    final response = await http
        .delete(Uri.parse('$syncApiBaseUrl/devices/$id'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// Best-effort call on logout — unregisters only this device's token so
  /// push stops targeting a session that just ended, without touching any
  /// other device registered on the same account.
  Future<void> unregisterDevice(String fcmToken) async {
    final response = await http
        .delete(
          Uri.parse('$syncApiBaseUrl/devices/register'),
          headers: await _headers(),
          body: jsonEncode({'fcmToken': fcmToken}),
        )
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// Sliding session: exchanges a still-valid token for a fresh 90-day one.
  /// Returns null ONLY on an explicit 401 (the token itself was rejected —
  /// caller treats that as "must re-login"). Anything else — a timeout, a
  /// dropped connection, a 500/429 from the server — is a transient failure,
  /// not proof the session is gone, so it's rethrown (a SyncApiException for
  /// a non-2xx response, or the raw exception otherwise) rather than
  /// swallowed to null. Previously ANY failure here — including the server
  /// briefly erroring — forced a full logout, turning a passing server hiccup
  /// into a "log in again" support ticket.
  Future<String?> refreshToken() async {
    final response = await http
        .post(Uri.parse('$syncApiBaseUrl/auth/refresh'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) {
      throw SyncApiException(response.statusCode, response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['token']
        as String?;
  }

  /// Re-checks account state that can change server-side with no way to
  /// notify this device on its own — chiefly email verification via the
  /// browser link. `{email, emailVerified}`.
  Future<Map<String, dynamic>> getMe() async {
    final response = await http
        .get(Uri.parse('$syncApiBaseUrl/auth/me'), headers: await _headers())
        .timeout(syncRequestTimeout);
    return _decodeObject(response);
  }

  Future<void> resendVerificationEmail() async {
    final response = await http
        .post(Uri.parse('$syncApiBaseUrl/auth/resend-verification'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// On success, updates the stored token to the fresh one the server
  /// issues (a password change bumps the server's tokenVersion, so the
  /// *old* token — including the one used to make this very request —
  /// would otherwise stop working immediately after).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required AuthService authService,
  }) async {
    final response = await http
        .post(
          Uri.parse('$syncApiBaseUrl/auth/change-password'),
          headers: await _headers(),
          body: jsonEncode(
              {'currentPassword': currentPassword, 'newPassword': newPassword}),
        )
        .timeout(syncRequestTimeout);
    _checkOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await authService.updateToken(data['token'] as String);
  }

  /// Unlike a password change, this doesn't re-issue a token — the server
  /// doesn't bump tokenVersion for an email change, so the current session
  /// stays valid. The new address starts unverified; caller should update
  /// the locally cached email/emailVerified accordingly.
  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
    required AuthService authService,
  }) async {
    final response = await http
        .post(
          Uri.parse('$syncApiBaseUrl/auth/change-email'),
          headers: await _headers(),
          body: jsonEncode(
              {'newEmail': newEmail, 'currentPassword': currentPassword}),
        )
        .timeout(syncRequestTimeout);
    _checkOk(response);
    await authService.updateEmailAfterChange(newEmail);
  }

  /// Invalidates every token issued for this account, including the one
  /// this call itself used — callers must follow up with
  /// `AuthService.logout()` to also clear local storage.
  Future<void> logoutAllDevices() async {
    final response = await http
        .post(Uri.parse('$syncApiBaseUrl/auth/logout-all'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  Future<void> deleteAccount() async {
    final response = await http
        .delete(Uri.parse('$syncApiBaseUrl/auth/me'), headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// Active challenges, each flagged `joined` for the calling user.
  Future<List<dynamic>> getChallenges() async {
    final response = await http
        .get(Uri.parse('$syncApiBaseUrl/challenges'), headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> joinChallenge(String id) async {
    final response = await http
        .post(Uri.parse('$syncApiBaseUrl/challenges/$id/join'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  Future<void> leaveChallenge(String id) async {
    final response = await http
        .delete(Uri.parse('$syncApiBaseUrl/challenges/$id/join'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// `{challengeId, metric, leaderboard: [{rank, userId, displayName, value}]}`.
  Future<Map<String, dynamic>> getLeaderboard(String id) async {
    final response = await http
        .get(Uri.parse('$syncApiBaseUrl/challenges/$id/leaderboard'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    return _decodeObject(response);
  }

  /// The only inbox for in-app "report a problem / feedback" — reviewed
  /// from the /admin panel, there's no other channel.
  Future<void> submitFeedback(
      {String? category, required String message}) async {
    final response = await http
        .post(
          Uri.parse('$syncApiBaseUrl/feedback'),
          headers: await _headers(),
          body: jsonEncode(
              {if (category != null) 'category': category, 'message': message}),
        )
        .timeout(syncRequestTimeout);
    _checkOk(response);
  }

  /// Self-service export of the account's training history as CSV — the raw
  /// response body, not JSON, so this bypasses `_decodeObject`.
  Future<String> exportData() async {
    final response = await http
        .get(Uri.parse('$syncApiBaseUrl/auth/me/export'),
            headers: await _headers())
        .timeout(syncRequestTimeout);
    _checkOk(response);
    return response.body;
  }

  void _checkOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(response.statusCode, response.body);
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    _checkOk(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
