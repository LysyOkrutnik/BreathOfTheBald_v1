import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/profile_screen.dart';
import 'package:okrutnik_breath/ui/screens/today_screen.dart';
import 'package:okrutnik_breath/ui/screens/training_library_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';

/// The app's persistent bottom-nav shell: Dziś / Trening / Ty. Replaces the
/// old 5-tab shell (Wim Hof / Ćwiczenia specjalne / Freediving / Plan /
/// Więcej) — Trening now hosts what used to be 3 separate tabs as segments
/// of one, and Ty merges Więcej/Statystyki/Historia into one profile tab
/// with the new Wyzwania (Challenges) leaderboard alongside them.
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
  // eagerly constructing TrainingLibraryScreen would fire the Scheduler
  // section's exact-alarm permission request on app launch, before the user
  // ever opens that tab.
  static const List<Widget Function()> _builders = [
    _buildToday,
    _buildTraining,
    _buildProfile,
  ];

  static Widget _buildToday() => const TodayScreen();
  static Widget _buildTraining() => const TrainingLibraryScreen();
  static Widget _buildProfile() => const ProfileScreen();

  // Each tab's secondary identity colour, layered as a quiet accent on top
  // of the app-wide ocean cyan (null = no secondary tint, just the ocean).
  static const List<Color?> _sectionAccents = [
    AppTheme.primary, // Dziś
    AppTheme.accent, // Trening
    null, // Ty
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
        extendBody: true,
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
        bottomNavigationBar: _GlassNavBar(
          index: _index,
          onSelect: _selectTab,
          destinations: [
            _NavDestination(
              icon: Icons.wb_sunny_outlined,
              selectedIcon: Icons.wb_sunny_rounded,
              color: AppTheme.primary,
              label: L10n.get(context, 'nav_today'),
            ),
            _NavDestination(
              icon: Icons.fitness_center_outlined,
              selectedIcon: Icons.fitness_center_rounded,
              color: AppTheme.accent,
              label: L10n.get(context, 'nav_training'),
            ),
            _NavDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              color: AppTheme.lure,
              label: L10n.get(context, 'nav_profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
  final String label;
}

/// A floating, blurred glass bar — consistent with the rest of the app's
/// GlassCard language, replacing the old flat/solid Material [NavigationBar]
/// which was the one piece of chrome that didn't match anything else.
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.index,
    required this.onSelect,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<_NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppTheme.glassBorder.withAlpha(40)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _NavItem(
                      destination: destinations[i],
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? destination.color : AppTheme.textDim;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? destination.selectedIcon : destination.icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
