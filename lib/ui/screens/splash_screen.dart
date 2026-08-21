import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/core/sync/sync_api_client.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/sync_providers.dart';
import 'package:okrutnik_breath/ui/screens/auth_gate_screen.dart';
import 'package:okrutnik_breath/ui/screens/home_shell_screen.dart';
import 'package:okrutnik_breath/ui/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _onboardingDone = false;
  // Irrelevant until onboarding is done — checked below only in that case.
  bool _needsAuthGate = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Wait for both init to finish AND a minimum splash duration, so the
    // destination decision always reflects the real onboarding flag (no race
    // with a fixed timer on slow devices).
    await Future.wait([
      _initApp().catchError((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 3200)),
    ]);
    if (!mounted) return;
    final Widget next = !_onboardingDone
        ? const OnboardingScreen()
        : (_needsAuthGate ? const AuthGateScreen() : const HomeShellScreen());
    Navigator.of(context).pushReplacement(fadeThroughRoute(next));
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool(OnboardingScreen.prefsKey) ?? false;

    // One-time migration of any legacy SharedPreferences history into Drift.
    await ref.read(sessionRepositoryProvider).importLegacyData();

    // No anonymous/offline mode — every cold start needs a session. Only
    // relevant once onboarding is already done; a first run always lands on
    // AuthGateScreen via OnboardingScreen's own finish button.
    if (_onboardingDone) {
      _needsAuthGate = !await _hasValidSession();
    }

    // Note: the daily reminder is NOT (re)scheduled here. Once
    // notifications.scheduleDailyReminder() fires, the OS keeps the alarm
    // alive on its own (a boot receiver re-arms it after a reboot); the
    // Settings toggle (backed by settingsProvider) is the single place that
    // turns it on or off. Re-scheduling it here on every cold start was the
    // root cause of a past bug where the reminder kept firing with no way to
    // disable it.
  }

  /// A stored token isn't enough on its own — it could have been revoked
  /// (logout-all from another device), the account banned, or deleted,
  /// none of which this device would otherwise learn about until some other
  /// authenticated call happened to fail. Only a definite 401 is treated as
  /// "log this device out"; being offline or a transient server error must
  /// not lock the user out of their own cached local data.
  Future<bool> _hasValidSession() async {
    final authService = ref.read(authServiceProvider);
    if (!await authService.isLoggedIn) return false;
    try {
      await ref.read(syncApiClientProvider).getMe();
      return true;
    } on SyncApiException catch (e) {
      if (!e.isAuthError) return true;
      // Same cross-account data-leak concern as every other logout path —
      // clear the stale local session and its data before the gate lets
      // some other account log in on this device.
      await authService.logout();
      await ref.read(databaseProvider).wipeAllLocalData();
      await ref.read(syncServiceProvider).clearLastSyncedAt();
      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash.png',
            fit: BoxFit.cover,
          ),

          // Add a gradient overlay to enhance text visibility over the background image.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(77),
                  Colors.transparent,
                  Colors.black.withAlpha(153),
                ],
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  Text(
                    "BREATH\nOF THE\nBALD",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      color: AppTheme.textLight,
                      letterSpacing: 6.0,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(204),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "by ŁysyOkrutnik",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.primary,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(204),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}