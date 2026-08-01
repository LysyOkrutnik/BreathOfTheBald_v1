import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/menu_screen.dart';
import 'package:okrutnik_breath/ui/screens/onboarding_screen.dart';
import 'package:permission_handler/permission_handler.dart';
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
    final Widget next =
        _onboardingDone ? const MenuScreen() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(fadeThroughRoute(next));
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool(OnboardingScreen.prefsKey) ?? false;

    // One-time migration of any legacy SharedPreferences history into Drift.
    await ref.read(sessionRepositoryProvider).importLegacyData();

    // Returning users: notification permission was handled during onboarding;
    // just refresh the default daily reminder if it's allowed and no custom
    // schedule has been set. New users get the priming flow in onboarding.
    if (!_onboardingDone) return;

    final granted = await Permission.notification.isGranted;
    final hasCustomSchedule = prefs.getBool('schedule_active') ?? false;
    if (!granted || hasCustomSchedule || !mounted) return;

    // Capture localized strings before further async gaps.
    final title = L10n.get(context, 'notif_reminder_title');
    final body = L10n.get(context, 'notif_reminder_body');
    final notifications = ref.read(notificationServiceProvider);
    await notifications.init();
    await notifications.scheduleDailyReminder(title: title, body: body);
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