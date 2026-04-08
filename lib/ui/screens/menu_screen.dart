import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/ui/screens/instruction_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/history_screen.dart';
import 'package:okrutnik_breath/ui/screens/scheduler_screen.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            const Positioned.fill(child: ParticleBackground()),
            Positioned.fill(
              child: Container(
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
            ),
            SafeArea(
              child: isLandscape
                  ? _buildLandscapeLayout(context)
                  : _buildPortraitLayout(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Text(L10n.get(context, 'exit_dialog_title'), style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 18)),
        content: Text(L10n.get(context, 'exit_dialog_message'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L10n.get(context, 'exit_dialog_cancel'), style: const TextStyle(color: Colors.white30)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(L10n.get(context, 'exit_dialog_confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 700;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: isSmallScreen ? 30 : 50),
            Text(
              "${L10n.get(context, 'menu_title_1')}\n${L10n.get(context, 'menu_title_2')}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                color: AppTheme.textLight,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              L10n.get(context, 'menu_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: AppTheme.primary,
                letterSpacing: 2.0,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              L10n.get(context, 'menu_select_rhythm'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDim,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 25),
            
            
            _buildSectionLabel(context, 'menu_section_classic'),
            const SizedBox(height: 15),
            _buildZenButton(context, 'mild'),
            const SizedBox(height: 12),
            _buildZenButton(context, 'strong'),
            const SizedBox(height: 12),
            _buildZenButton(context, 'beast'),
            const SizedBox(height: 12),
            _buildZenButton(context, 'guru'),

            const SizedBox(height: 30),

            _buildSectionLabel(context, 'menu_section_special'),
            const SizedBox(height: 15),
            _buildZenButton(context, 'box'),
            const SizedBox(height: 12),
            _buildZenButton(context, 'relax'),
            const SizedBox(height: 12),
            _buildZenButton(context, 'fire'),

            const SizedBox(height: 40),

            
            _buildWideMenuButton(context, Icons.spa, 'menu_guide_button', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InstructionScreen()))),
            const SizedBox(height: 15),
            _buildWideMenuButton(context, Icons.history, 'menu_history_button', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()))),
            const SizedBox(height: 15),
            _buildWideMenuButton(context, Icons.schedule, 'menu_schedule_button', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchedulerScreen()))),

            const SizedBox(height: 40),

            Consumer(builder: (context, ref, child) {
              return Center(
                child: InkWell(
                  onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'pl') == 'pl' ? 'EN' : 'PL',
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${L10n.get(context, 'menu_title_1')}\n${L10n.get(context, 'menu_title_2')}",
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: AppTheme.textLight, letterSpacing: 4.0),
                  ),
                  const SizedBox(height: 8),
                  Text(L10n.get(context, 'menu_subtitle'), style: const TextStyle(fontSize: 10, color: AppTheme.primary, letterSpacing: 2.0)),
                  const SizedBox(height: 40),
                  
                  _buildLandscapeNavButton(context, Icons.spa, 'menu_guide_button', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InstructionScreen()))),
                  const SizedBox(height: 12),
                  _buildLandscapeNavButton(context, Icons.history, 'menu_history_button', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()))),
                  const SizedBox(height: 12),
                  _buildLandscapeNavButton(context, Icons.schedule, 'menu_schedule_button', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchedulerScreen()))),
                  
                  const SizedBox(height: 32),
                  Consumer(builder: (context, ref, child) {
                    return InkWell(
                      onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
                      child: Text(
                        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'pl') == 'pl' ? 'SWITCH TO ENGLISH' : 'ZMIEŃ NA POLSKI',
                        style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withAlpha(13)))),
            child: GridView.count(
              padding: const EdgeInsets.all(24),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildZenButton(context, 'mild'),
                _buildZenButton(context, 'strong'),
                _buildZenButton(context, 'beast'),
                _buildZenButton(context, 'guru'),
                _buildZenButton(context, 'box'),
                _buildZenButton(context, 'relax'),
                _buildZenButton(context, 'fire'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String key) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        L10n.get(context, key),
        style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
    );
  }

  Widget _buildWideMenuButton(BuildContext context, IconData icon, String key, VoidCallback onTap) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.textDim, size: 16),
              const SizedBox(width: 8),
              Text(L10n.get(context, key), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeNavButton(BuildContext context, IconData icon, String key, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withAlpha(13), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textDim, size: 16),
            const SizedBox(width: 12),
            Text(L10n.get(context, key), style: const TextStyle(color: AppTheme.textDim, fontSize: 11, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildZenButton(BuildContext context, String levelKey) {
    final level = LevelData.levels[levelKey]!;
    final title = L10n.get(context, level.title);
    
    final pace = level.type == ExerciseType.wimHof
        ? level.breathPace.inMilliseconds / 1000 == 3.0
        ? "3.0s"
        : "${level.breathPace.inMilliseconds / 1000}s"
        : L10n.get(context, level.subtitle);

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => IntroScreen(level: level))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withAlpha(13),
          border: Border.all(color: Colors.white.withAlpha(13)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 4, color: level.color),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: TextStyle(color: level.color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Text(pace, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
