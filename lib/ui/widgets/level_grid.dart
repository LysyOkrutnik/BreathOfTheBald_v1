import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/custom_builder_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// A caption label with a trailing rule, used to introduce a section of
/// cards (e.g. "WŁASNE" above the custom-preset list).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Container(height: 1, color: Colors.white.withAlpha(18)),
        ),
      ],
    );
  }
}

/// A responsive grid (1 or 2 columns depending on device/orientation) of
/// [LevelCard]s for the given level keys.
class LevelGrid extends StatelessWidget {
  const LevelGrid({
    super.key,
    required this.keys,
    required this.columns,
    this.startIndex = 0,
  });

  final List<String> keys;
  final int columns;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            LevelCard(levelKey: keys[i], index: startIndex + i),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < keys.length; i++)
              SizedBox(
                width: cardWidth,
                child: LevelCard(levelKey: keys[i], index: startIndex + i),
              ),
          ],
        );
      },
    );
  }
}

class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.levelKey, this.index = 0});

  final String levelKey;
  final int index;

  String _paceLabel(BuildContext context, LevelData level) {
    if (level.type == ExerciseType.wimHof) {
      return '${(level.breathPace.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return L10n.get(context, level.subtitle);
  }

  String _description(BuildContext context, LevelData level) {
    switch (level.type) {
      case ExerciseType.wimHof:
        final roundsKey =
            level.totalRounds >= 5 ? 'desc_rounds_pl' : 'desc_rounds';
        return '${level.totalBreaths} ${L10n.get(context, 'desc_breaths')} • '
            '${level.totalRounds} ${L10n.get(context, roundsKey)}';
      case ExerciseType.boxBreathing:
        return '16 ${L10n.get(context, 'desc_cycles')} • '
            '${L10n.get(context, 'desc_steel_nerves')}';
      case ExerciseType.relax478:
        return '~10 min • ${L10n.get(context, 'desc_deep_sleep')}';
      case ExerciseType.fireBreathing:
        return '3 min • ${L10n.get(context, 'desc_pure_energy')}';
      case ExerciseType.custom:
      case ExerciseType.co2Table:
      case ExerciseType.o2Table:
        // Freediving tables never appear in this generic grid (they have
        // their own dedicated tab); custom presets show their own
        // description via PresetCard instead.
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = LevelData.levels[levelKey]!;

    final card = PressableScale(
      onTap: () => Navigator.of(context).push(
        fadeThroughRoute(IntroScreen(level: level)),
      ),
      child: Hero(
        tag: 'level_card_${level.key}',
        child: GlassCard(
          gradient: AppTheme.cardGradient(level.color),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: level.color,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glow(level.color, blur: 10),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            L10n.get(context, level.title),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textLight,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _paceLabel(context, level),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: level.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _description(context, level),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textDim.withAlpha(190),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  color: level.color.withAlpha(160), size: 22),
            ],
          ),
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: AppMotion.medium)
        .slideX(begin: 0.08, curve: AppMotion.emphasized);
  }
}

/// The "Własne" (custom presets) section: existing presets plus a
/// create-new-preset action.
class CustomSection extends ConsumerWidget {
  const CustomSection({super.key});

  void _start(BuildContext context, WidgetRef ref, CustomPreset p) {
    final level = LevelData.custom(
      name: p.name,
      inhaleSec: p.inhaleSec,
      holdInSec: p.holdInSec,
      exhaleSec: p.exhaleSec,
      holdOutSec: p.holdOutSec,
      cycles: p.cycles,
      rounds: p.rounds,
    );
    ref.read(sessionProvider.notifier).startSession(level);
    Navigator.of(context).push(fadeThroughRoute(const SessionScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(customPresetsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(L10n.get(context, 'menu_section_custom')),
        const SizedBox(height: AppSpacing.md),
        for (final p in presets) ...[
          PresetCard(
            preset: p,
            onTap: () => _start(context, ref, p),
            onDelete: () =>
                ref.read(customPresetRepositoryProvider).deletePreset(p.id),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PressableScale(
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const CustomBuilderScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.accent.withAlpha(120)),
              color: AppTheme.accent.withAlpha(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: AppTheme.accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  L10n.get(context, 'custom_create'),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.preset,
    required this.onTap,
    required this.onDelete,
  });

  final CustomPreset preset;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pattern =
        '${preset.inhaleSec}-${preset.holdInSec}-${preset.exhaleSec}-${preset.holdOutSec}';
    return PressableScale(
      onTap: onTap,
      child: GlassCard(
        gradient: AppTheme.cardGradient(AppTheme.accent),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$pattern • ${preset.cycles}×${preset.rounds}',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white38, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
