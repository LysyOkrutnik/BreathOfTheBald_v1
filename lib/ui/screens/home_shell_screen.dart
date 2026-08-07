import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/screens/freediving/freediving_home_screen.dart';
import 'package:okrutnik_breath/ui/screens/more_screen.dart';
import 'package:okrutnik_breath/ui/screens/scheduler_screen.dart';
import 'package:okrutnik_breath/ui/screens/stats_screen.dart';
import 'package:okrutnik_breath/ui/screens/training_screen.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';

/// The app's persistent bottom-nav shell: Trening / Freediving / Plan /
/// Statystyki / Więcej. Replaces the old single-scroll MenuScreen as the
/// post-onboarding home.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _index = 0;

  // Tabs are built lazily on first visit (then kept alive by IndexedStack) —
  // eagerly constructing SchedulerScreen would fire its exact-alarm
  // permission request on app launch, before the user ever opens that tab.
  static const List<Widget Function()> _builders = [
    _buildTraining,
    _buildFreediving,
    _buildScheduler,
    _buildStats,
    _buildMore,
  ];

  static Widget _buildTraining() => const TrainingScreen();
  static Widget _buildFreediving() => const FreedivingHomeScreen(embedded: true);
  static Widget _buildScheduler() => const SchedulerScreen(embedded: true);
  static Widget _buildStats() => const StatsScreen(embedded: true);
  static Widget _buildMore() => const MoreScreen();

  final List<Widget?> _tabs = List<Widget?>.filled(_builders.length, null);

  @override
  void initState() {
    super.initState();
    _tabs[0] = _builders[0]();
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
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _tabs.length; i++) _tabs[i] ?? const SizedBox.shrink(),
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
              label: L10n.get(context, 'nav_training'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.water_outlined),
              selectedIcon: const Icon(Icons.water_rounded, color: AppTheme.danger),
              label: L10n.get(context, 'nav_freediving'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.schedule_outlined),
              selectedIcon: const Icon(Icons.schedule_rounded, color: AppTheme.accent),
              label: L10n.get(context, 'nav_plan'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights_rounded, color: AppTheme.accent),
              label: L10n.get(context, 'nav_stats'),
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
