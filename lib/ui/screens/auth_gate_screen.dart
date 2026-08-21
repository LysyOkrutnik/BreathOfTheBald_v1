import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/core/sync/auth_service.dart';
import 'package:okrutnik_breath/core/sync/push_registration.dart';
import 'package:okrutnik_breath/logic/providers/sync_providers.dart';
import 'package:okrutnik_breath/ui/screens/home_shell_screen.dart';
import 'package:okrutnik_breath/ui/screens/privacy_screen.dart';
import 'package:okrutnik_breath/ui/screens/terms_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// The mandatory entry point between onboarding and the main app — there is
/// no anonymous/offline mode, so every cold start without a valid session
/// (see SplashScreen) lands here instead of on [HomeShellScreen]. This is
/// the same register/login form that used to live inline in the Settings
/// screen's account section; it's now the only place that form appears.
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // A deliberately simple format check — good enough to catch typos before
  // a round trip to the server, not a full RFC 5322 validator.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _minPasswordLength = 8;

  bool _loading = false;
  bool _registering = false;
  String? _errorKey;

  // Only enforced for registration — login doesn't need a fresh consent
  // (the account already carries a `termsAcceptedAt` from when it was
  // created), so the checkbox has no bearing on the login button.
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _errorKeyFor(AuthErrorCode code) => switch (code) {
        AuthErrorCode.invalidInput => 'account_error_invalid_input',
        AuthErrorCode.emailTaken => 'account_error_email_taken',
        AuthErrorCode.invalidCredentials => 'account_error_invalid_credentials',
        AuthErrorCode.tooManyAttempts => 'account_error_too_many_attempts',
        AuthErrorCode.invalidOrExpiredToken =>
          'account_error_invalid_or_expired_token',
        AuthErrorCode.network => 'account_error_network',
        AuthErrorCode.unknown => 'account_error_unknown',
      };

  String? _validationErrorKey() {
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      return 'account_error_invalid_email_format';
    }
    if (_passwordController.text.length < _minPasswordLength) {
      return 'account_error_password_too_short';
    }
    return null;
  }

  Future<void> _submit({required bool isRegister}) async {
    final validationError = _validationErrorKey();
    if (validationError != null) {
      setState(() => _errorKey = validationError);
      return;
    }
    // Defensive — the register button is already disabled while this is
    // false, but _submit shouldn't rely on the UI alone to enforce it.
    if (isRegister && !_acceptedTerms) {
      setState(() => _errorKey = 'auth_gate_terms_required');
      return;
    }

    setState(() {
      _loading = true;
      _registering = isRegister;
      _errorKey = null;
    });
    final auth = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final result = isRegister
        ? await auth.register(
            email: email, password: password, acceptedTerms: true)
        : await auth.login(email: email, password: password);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loading = false;
        _errorKey = _errorKeyFor(result.errorCode!);
      });
      return;
    }

    // Best-effort, neither blocks entering the app — the first real sync
    // still happens from Settings or the next automatic trigger either way.
    unawaited(registerPushToken(ref.read(syncApiClientProvider)));
    unawaited(ref.read(syncServiceProvider).syncNow());

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        fadeThroughRoute(const HomeShellScreen()), (route) => false);
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    final email = await showGlassDialog<String>(
      context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(L10n.get(context, 'account_forgot_password_title'),
              style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Text(L10n.get(context, 'account_forgot_password_body'),
              style: const TextStyle(
                  color: AppTheme.textDim, fontSize: 12, height: 1.4)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.textLight),
            cursorColor: AppTheme.primary,
            decoration: InputDecoration(
              hintText: L10n.get(context, 'account_email_hint'),
              hintStyle: const TextStyle(color: AppTheme.textDim),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(L10n.get(context, 'common_cancel'),
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child:
                      Text(L10n.get(context, 'account_forgot_password_submit')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    await ref.read(authServiceProvider).forgotPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.get(context, 'account_forgot_password_sent'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'BREATH OF THE BALD',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.textLight,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Why an account is required, made its own visually
                      // distinct block (icon + larger, brighter text) instead
                      // of blending in as just the first dim line inside the
                      // form card below — this gate is a surprise for anyone
                      // arriving straight from onboarding, so the reason for
                      // it needs to actually catch the eye, not just be
                      // technically present somewhere on the screen.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cloud_sync_outlined,
                              color: AppTheme.primary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              L10n.get(context, 'auth_gate_intro'),
                              style: const TextStyle(
                                  color: AppTheme.textLight,
                                  fontSize: 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppTheme.textLight),
                              cursorColor: AppTheme.primary,
                              decoration: InputDecoration(
                                hintText:
                                    L10n.get(context, 'account_email_hint'),
                                hintStyle:
                                    const TextStyle(color: AppTheme.textDim),
                                enabledBorder: const UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white24)),
                                focusedBorder: const UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: AppTheme.primary)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: AppTheme.textLight),
                              cursorColor: AppTheme.primary,
                              decoration: InputDecoration(
                                hintText:
                                    L10n.get(context, 'account_password_hint'),
                                hintStyle:
                                    const TextStyle(color: AppTheme.textDim),
                                enabledBorder: const UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white24)),
                                focusedBorder: const UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: AppTheme.primary)),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _loading ? null : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero),
                                child: Text(
                                    L10n.get(
                                        context, 'account_forgot_password'),
                                    style: const TextStyle(
                                        color: AppTheme.textDim, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _acceptedTerms,
                                    onChanged: _loading
                                        ? null
                                        : (v) => setState(
                                            () => _acceptedTerms = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _loading
                                        ? null
                                        : () => setState(() =>
                                            _acceptedTerms = !_acceptedTerms),
                                    child: Text(
                                      L10n.get(
                                          context, 'auth_gate_terms_checkbox'),
                                      style: const TextStyle(
                                          color: AppTheme.textDim,
                                          fontSize: 12,
                                          height: 1.3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Row(
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                        fadeThroughRoute(
                                            const PrivacyScreen())),
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero),
                                    child: Text(
                                        L10n.get(context, 'settings_privacy'),
                                        style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.underline)),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                        fadeThroughRoute(const TermsScreen())),
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero),
                                    child: Text(
                                        L10n.get(context, 'settings_terms'),
                                        style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.underline)),
                                  ),
                                ],
                              ),
                            ),
                            if (_errorKey != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                L10n.get(context, _errorKey!),
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: _loading || !_acceptedTerms
                                        ? null
                                        : () => _submit(isRegister: true),
                                    child: _loading && _registering
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white70),
                                          )
                                        : Text(
                                            L10n.get(
                                                context, 'account_register'),
                                            style: const TextStyle(
                                                color: Colors.white70)),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _loading
                                        ? null
                                        : () => _submit(isRegister: false),
                                    child: _loading && !_registering
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black),
                                          )
                                        : Text(
                                            L10n.get(context, 'account_login')),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              L10n.get(context, 'account_sync_disclosure'),
                              style: TextStyle(
                                  color: AppTheme.textDim.withAlpha(160),
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
