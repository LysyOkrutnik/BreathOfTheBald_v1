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
          SystemNavigator.pop();
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
                  ? _buildLandscapeLayout(context, ref)
                  : _buildPortraitLayout(context, ref),
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

  Widget _buildPortraitLayout(BuildContext context, WidgetRef ref) {
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
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(L10n.get(context, 'menu_section_classic'), style: const TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
                ),
                _buildZenButton(context, ref, "mild"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "strong"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "beast"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "guru"),

                const SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(L10n.get(context, 'menu_section_special'), style: const TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
                ),
                _buildZenButton(context, ref, "box"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "relax"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "fire"),
              ],
            ),

            const SizedBox(height: 40),

            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'pl') == 'pl' ? 'EN' : 'PL',
                        style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const InstructionScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textDim.withAlpha(77)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.spa, color: AppTheme.textDim, size: 16),
                          const SizedBox(width: 8),
                          Text(L10n.get(context, 'menu_guide_button'), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Center(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HistoryScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, color: AppTheme.textDim, size: 16),
                      const SizedBox(width: 8),
                      Text(L10n.get(context, 'menu_history_button'), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.0)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            Center(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SchedulerScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, color: AppTheme.textDim, size: 16),
                      const SizedBox(width: 8),
                      Text(L10n.get(context, 'menu_schedule_button'), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.0)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${L10n.get(context, 'menu_title_1')}\n${L10n.get(context, 'menu_title_2')}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
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
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
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
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const InstructionScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textDim.withAlpha(77)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.spa, color: AppTheme.textDim, size: 16),
                          const SizedBox(width: 8),
                          Text(L10n.get(context, 'menu_guide_button'), style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Container(width: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(vertical: 20)),

        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(L10n.get(context, 'menu_section_classic'), style: const TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 5),
                _buildZenButton(context, ref, "mild"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "strong"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "beast"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "guru"),

                const SizedBox(height: 25),

                Text(L10n.get(context, 'menu_section_special'), style: const TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 5),
                _buildZenButton(context, ref, "box"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "relax"),
                const SizedBox(height: 10),
                _buildZenButton(context, ref, "fire"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZenButton(BuildContext context, WidgetRef ref, String levelKey) {
    final level = LevelData.levels[levelKey]!;
    final title = L10n.get(context, level.title);
    final pace = level.type == ExerciseType.wimHof
        ? level.breathPace.inMilliseconds / 1000 == 3.0
        ? "3.0s"
        : "${level.breathPace.inMilliseconds / 1000}s"
        : L10n.get(context, level.subtitle);

    String desc = "";
    if (level.type == ExerciseType.wimHof) {
      final roundsText = level.totalRounds >= 5 ? L10n.get(context, 'desc_rounds_pl') : L10n.get(context, 'desc_rounds');
      desc = "${level.totalBreaths} ${L10n.get(context, 'desc_breaths')} • ${level.totalRounds} $roundsText";
    } else if (level.type == ExerciseType.boxBreathing) {
      desc = "16 ${L10n.get(context, 'desc_cycles')} • ${L10n.get(context, 'desc_steel_nerves')}";
    } else if (level.type == ExerciseType.relax478) {
      desc = "~10 min • ${L10n.get(context, 'desc_deep_sleep')}";
    } else if (level.type == ExerciseType.fireBreathing) {
      desc = "3 min • ${L10n.get(context, 'desc_pure_energy')}";
    }

    return Hero(
      tag: 'level_card_${level.key}',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                level.color.withAlpha(38),
                Colors.transparent,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: level.color.withAlpha(77), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => IntroScreen(level: level)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: level.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: level.color, blurRadius: 6)]),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textLight,
                                      letterSpacing: 2.0
                                  )
                              ),
                              Text(
                                  pace,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: level.color
                                  )
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textDim.withAlpha(179),
                            ),
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
      ),
    );
  }
}
