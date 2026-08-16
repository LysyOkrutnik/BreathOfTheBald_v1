import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/freediving/freediving_home_screen.dart';
import 'package:okrutnik_breath/ui/screens/more_screen.dart';
import 'package:okrutnik_breath/ui/screens/scheduler_screen.dart';
import 'package:okrutnik_breath/ui/screens/special_screen.dart';
import 'package:okrutnik_breath/ui/screens/wim_hof_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';

/// The app's persistent bottom-nav shell: Wim Hof / Ćwiczenia specjalne /
/// Freediving / Plan / Więcej. Replaces the old single-scroll MenuScreen as
/// the post-onboarding home.
///
/// The atmospheric background lives here, once, behind the [IndexedStack] —
/// each tab used to carry its own copy, so switching tabs tore down and
/// restarted the particle animation. A single shared instance persists
/// across tab switches; only its [AppBackground.sectionAccent] changes to
/// reflect the active tab's identity colour.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;

  // Tabs are built lazily on first visit (then kept alive by IndexedStack) —
  // eagerly constructing SchedulerScreen would fire its exact-alarm
  // permission request on app launch, before the user ever opens that tab.
  static const List<Widget Function()> _builders = [
    _buildWimHof,
    _buildSpecial,
    _buildFreediving,
    _buildScheduler,
    _buildMore,
  ];

  static Widget _buildWimHof() => const WimHofScreen();
  static Widget _buildSpecial() => const SpecialScreen();
  static Widget _buildFreediving() => const FreedivingHomeScreen();
  static Widget _buildScheduler() => const SchedulerScreen();
  static Widget _buildMore() => const MoreScreen();

  // Each tab's secondary identity colour, layered as a quiet accent on top
  // of the app-wide ocean cyan (null = no secondary tint, just the ocean).
  static const List<Color?> _sectionAccents = [
    AppTheme.primary, // Wim Hof
    AppTheme.accent, // Ćwiczenia specjalne
    AppTheme.danger, // Freediving
    AppTheme.lure, // Plan
    null, // Więcej
  ];

  final List<Widget?> _tabs = List<Widget?>.filled(_builders.length, null);

  @override
  void initState() {
    super.initState();
    _tabs[0] = _builders[0]();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowReminderMigrationNotice());
  }

  /// One-time notice for users affected by the reminder migration in
  /// SettingsNotifier — without this, their daily reminder just silently
  /// stopped, with nothing in the UI explaining why.
  void _maybeShowReminderMigrationNotice() {
    if (!ref.read(settingsProvider.notifier).consumeReminderMigrationNotice()) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10n.get(context, 'settings_reminder_migration_notice')),
      duration: const Duration(seconds: 6),
    ));
  }

  void _selectTab(int i) {
    setState(() {
      _index = i;
      _tabs[i] ??= _builders[i]();
    });
  }

  Future<void> _confirmExit() async {
    final leave = await showGlassConfirm(
      context,
      title: L10n.get(context, 'exit_app_title'),
      confirmLabel: L10n.get(context, 'exit_app_confirm'),
      cancelLabel: L10n.get(context, 'exit_app_stay'),
    );
    if (leave) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        await _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: AppBackground(sectionAccent: _sectionAccents[_index])),
            Positioned.fill(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _tabs.length; i++) _tabs[i] ?? const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          backgroundColor: AppTheme.background,
          indicatorColor: AppTheme.primary.withAlpha(40),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.self_improvement_outlined),
              selectedIcon: const Icon(Icons.self_improvement_rounded, color: AppTheme.primary),
              label: L10n.get(context, 'nav_wimhof'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bolt_outlined),
              selectedIcon: const Icon(Icons.bolt_rounded, color: AppTheme.accent),
              label: L10n.get(context, 'nav_special'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.water_outlined),
              selectedIcon: const Icon(Icons.water_rounded, color: AppTheme.danger),
              label: L10n.get(context, 'nav_freediving'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.schedule_outlined),
              selectedIcon: const Icon(Icons.schedule_rounded, color: AppTheme.lure),
              label: L10n.get(context, 'nav_plan'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_rounded),
              selectedIcon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textLight),
              label: L10n.get(context, 'nav_more'),
            ),
          ],
        ),
      ),
    );
  }
}
