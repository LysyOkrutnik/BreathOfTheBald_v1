import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/ui/screens/menu_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shown once on first launch: introduces the app, primes the safety notice,
/// and asks for notification permission in context.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const prefsKey = 'onboarding_completed';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Page> _pages(BuildContext context) => [
        _Page(
          icon: Icons.spa_rounded,
          color: AppTheme.primary,
          title: L10n.get(context, 'onboard_welcome_title'),
          body: L10n.get(context, 'onboard_welcome_body'),
        ),
        _Page(
          icon: Icons.touch_app_rounded,
          color: AppTheme.accent,
          title: L10n.get(context, 'onboard_how_title'),
          body: L10n.get(context, 'onboard_how_body'),
        ),
        _Page(
          icon: Icons.health_and_safety_outlined,
          color: AppTheme.danger,
          title: L10n.get(context, 'onboard_safety_title'),
          body: L10n.get(context, 'onboard_safety_body'),
        ),
        _Page(
          icon: Icons.notifications_active_outlined,
          color: AppTheme.primary,
          title: L10n.get(context, 'onboard_reminders_title'),
          body: L10n.get(context, 'onboard_reminders_body'),
          isLast: true,
        ),
      ];

  Future<void> _finish({required bool enableNotifications}) async {
    final reminderTitle = L10n.get(context, 'notif_reminder_title');
    final reminderBody = L10n.get(context, 'notif_reminder_body');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefsKey, true);

    if (enableNotifications) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        final notifications = ref.read(notificationServiceProvider);
        await notifications.init();
        await notifications.scheduleDailyReminder(
          title: reminderTitle,
          body: reminderBody,
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(fadeThroughRoute(const MenuScreen()));
    }
  }

  void _next() {
    _controller.nextPage(
        duration: AppMotion.medium, curve: AppMotion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 600 : 520),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _finish(enableNotifications: false),
                        child: Text(
                          L10n.get(context, 'onboard_skip'),
                          style: const TextStyle(
                              color: AppTheme.textDim, letterSpacing: 1.0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: pages.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) => pages[i],
                      ),
                    ),
                    _Dots(count: pages.length, active: _page),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _page == pages.length - 1
                          ? Column(
                              children: [
                                _Primary(
                                  label: L10n.get(context, 'onboard_enable'),
                                  onTap: () => _finish(enableNotifications: true),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextButton(
                                  onPressed: () =>
                                      _finish(enableNotifications: false),
                                  child: Text(
                                    L10n.get(context, 'onboard_later'),
                                    style:
                                        const TextStyle(color: AppTheme.textDim),
                                  ),
                                ),
                              ],
                            )
                          : _Primary(
                              label: L10n.get(context, 'onboard_next'),
                              onTap: _next,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlowHalo(
            color: color,
            diameter: 120,
            haloScale: 1.9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(24),
                border: Border.all(color: color.withAlpha(90)),
              ),
              child: Center(child: Icon(icon, size: 56, color: color)),
            ),
          ).animate().scale(duration: AppMotion.slow, curve: Curves.easeOutBack),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.responsive(compact: 26, expanded: 32),
              fontWeight: FontWeight.w300,
              color: AppTheme.textLight,
              letterSpacing: 3.0,
            ),
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textDim,
              fontSize: 15,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 280.ms),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? AppTheme.primary : Colors.white24,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppTheme.glow(AppTheme.primary, blur: 22),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
