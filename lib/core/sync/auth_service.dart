import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:okrutnik_breath/core/sync/sync_config.dart';

/// Server-reported error codes from the unauthenticated auth endpoints —
/// surfaced as-is so the UI can map them to localized copy rather than
/// showing a raw string.
enum AuthErrorCode {
  invalidInput,
  emailTaken,
  invalidCredentials,
  tooManyAttempts,
  invalidOrExpiredToken,
  network,
  unknown,
}

class AuthResult {
  const AuthResult._({required this.success, this.errorCode});
  factory AuthResult.success() => const AuthResult._(success: true);
  factory AuthResult.failure(AuthErrorCode code) =>
      AuthResult._(success: false, errorCode: code);

  final bool success;
  final AuthErrorCode? errorCode;
}

AuthErrorCode _mapErrorCode(String? code) => switch (code) {
      'invalid_input' => AuthErrorCode.invalidInput,
      'email_taken' => AuthErrorCode.emailTaken,
      'invalid_credentials' => AuthErrorCode.invalidCredentials,
      'too_many_attempts' => AuthErrorCode.tooManyAttempts,
      'invalid_or_expired_token' => AuthErrorCode.invalidOrExpiredToken,
      _ => AuthErrorCode.unknown,
    };

/// Registration/login against the deployed backend and JWT storage —
/// secure storage rather than SharedPreferences since this token is a bearer
/// credential for every synced piece of the user's training history.
///
/// Deliberately holds only unauthenticated endpoints (register/login/
/// verify/forgot/reset) plus local token storage — everything that needs a
/// Bearer token (refresh, change-password, logout-all, delete-account)
/// lives on SyncApiClient instead, since that's already the place that
/// attaches the header and detects a 401.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'sync_jwt_token';
  static const _userIdKey = 'sync_user_id';
  static const _emailKey = 'sync_email';
  static const _emailVerifiedKey = 'sync_email_verified';

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<String?> get userId => _storage.read(key: _userIdKey);

  /// The email last used to register/log in — purely for display ("logged
  /// in as ..."), not sent with requests (the JWT alone authenticates).
  Future<String?> get email => _storage.read(key: _emailKey);

  Future<bool> get emailVerified async =>
      (await _storage.read(key: _emailVerifiedKey)) == 'true';

  Future<bool> get isLoggedIn async => (await token) != null;

  /// Called by SyncApiClient after a successful `/auth/refresh` — replaces
  /// only the token, leaving the rest of the stored identity untouched.
  Future<void> updateToken(String newToken) => _storage.write(key: _tokenKey, value: newToken);

  Future<void> markEmailVerified() => _storage.write(key: _emailVerifiedKey, value: 'true');

  Future<AuthResult> register({required String email, required String password}) =>
      _authRequest('/auth/register', email: email, password: password);

  Future<AuthResult> login({required String email, required String password}) =>
      _authRequest('/auth/login', email: email, password: password);

  Future<AuthResult> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$syncApiBaseUrl/auth/forgot-password'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(syncRequestTimeout);
      // Always 204 regardless of whether the email exists — nothing to
      // branch on beyond "the request itself succeeded".
      if (response.statusCode == 204) return AuthResult.success();
      return AuthResult.failure(_mapErrorCode(_tryDecodeError(response.body)));
    } catch (_) {
      return AuthResult.failure(AuthErrorCode.network);
    }
  }

  Future<AuthResult> verifyEmail(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$syncApiBaseUrl/auth/verify-email'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(syncRequestTimeout);
      if (response.statusCode == 204) {
        await markEmailVerified();
        return AuthResult.success();
      }
      return AuthResult.failure(_mapErrorCode(_tryDecodeError(response.body)));
    } catch (_) {
      return AuthResult.failure(AuthErrorCode.network);
    }
  }

  Future<AuthResult> resetPassword({required String token, required String newPassword}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$syncApiBaseUrl/auth/reset-password'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'newPassword': newPassword}),
          )
          .timeout(syncRequestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _storage.write(key: _tokenKey, value: data['token'] as String);
        await _storage.write(key: _userIdKey, value: data['userId'] as String);
        return AuthResult.success();
      }
      return AuthResult.failure(_mapErrorCode(_tryDecodeError(response.body)));
    } catch (_) {
      return AuthResult.failure(AuthErrorCode.network);
    }
  }

  /// Local-only — clears the stored identity. Doesn't call the server (a
  /// stored JWT just stops being used, it isn't individually revocable);
  /// use `logoutAllDevices` first if the goal is invalidating it too.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _emailVerifiedKey);
  }

  Future<AuthResult> _authRequest(
    String path, {
    required String email,
    required String password,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$syncApiBaseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(syncRequestTimeout);
    } catch (_) {
      return AuthResult.failure(AuthErrorCode.network);
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: _tokenKey, value: data['token'] as String);
      await _storage.write(key: _userIdKey, value: data['userId'] as String);
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(
          key: _emailVerifiedKey, value: (data['emailVerified'] == true).toString());
      return AuthResult.success();
    }

    if (response.statusCode == 429) return AuthResult.failure(AuthErrorCode.tooManyAttempts);
    return AuthResult.failure(_mapErrorCode(_tryDecodeError(response.body)));
  }

  String? _tryDecodeError(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error'] as String?;
    } catch (_) {
      // Non-JSON body (e.g. a proxy error page) — fall through to unknown.
      return null;
    }
  }
}
