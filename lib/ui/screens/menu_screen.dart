import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/ui/screens/custom_builder_screen.dart';
import 'package:okrutnik_breath/ui/screens/history_screen.dart';
import 'package:okrutnik_breath/ui/screens/instruction_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/scheduler_screen.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/screens/settings_screen.dart';
import 'package:okrutnik_breath/ui/screens/stats_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  static const _classic = ['mild', 'strong', 'beast', 'guru'];
  static const _special = ['box', 'relax', 'fire'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = (context.isTablet || context.isLandscape) ? 2 : 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showGlassConfirm(
          context,
          title: L10n.get(context, 'exit_app_title'),
          confirmLabel: L10n.get(context, 'exit_app_confirm'),
          cancelLabel: L10n.get(context, 'exit_app_stay'),
        );
        if (leave) SystemNavigator.pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.isTablet ? 900 : double.infinity,
                ),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        context.responsive(compact: AppSpacing.xl, expanded: AppSpacing.xxl),
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      sliver: SliverList.list(
                        children: [
                          const _Header(),
                          SizedBox(height: context.scaled(AppSpacing.xl)),
                          _SectionLabel(L10n.get(context, 'menu_section_classic')),
                          const SizedBox(height: AppSpacing.md),
                          _LevelGrid(keys: _classic, columns: columns, startIndex: 0),
                          const SizedBox(height: AppSpacing.xl),
                          _SectionLabel(L10n.get(context, 'menu_section_special')),
                          const SizedBox(height: AppSpacing.md),
                          _LevelGrid(keys: _special, columns: columns, startIndex: _classic.length),
                          const SizedBox(height: AppSpacing.xl),
                          const _CustomSection(),
                          SizedBox(height: context.scaled(AppSpacing.xl)),
                          const _ActionBar(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final titleSize = context.responsive<double>(compact: 40, medium: 52, expanded: 60);

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.textLight, AppTheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            "${L10n.get(context, 'menu_title_1')}\n${L10n.get(context, 'menu_title_2')}",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              height: 1.05,
              letterSpacing: 4.0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(context, 'menu_subtitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: AppTheme.primary,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          L10n.get(context, 'menu_select_rhythm'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textDim.withAlpha(200),
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: AppMotion.slow)
        .slideY(begin: 0.15, curve: AppMotion.emphasized);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
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

class _LevelGrid extends StatelessWidget {
  const _LevelGrid({
    required this.keys,
    required this.columns,
    required this.startIndex,
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
            _LevelCard(levelKey: keys[i], index: startIndex + i),
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
                child: _LevelCard(levelKey: keys[i], index: startIndex + i),
              ),
          ],
        );
      },
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.levelKey, required this.index});

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

class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode == 'pl' ? 'EN' : 'PL';

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _PillButton(
          label: lang,
          onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
        ),
        _PillButton(
          icon: Icons.spa_outlined,
          label: L10n.get(context, 'menu_guide_button'),
          highlighted: true,
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const InstructionScreen())),
        ),
        _PillButton(
          icon: Icons.insights_rounded,
          label: L10n.get(context, 'menu_stats_button'),
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const StatsScreen())),
        ),
        _PillButton(
          icon: Icons.history_rounded,
          label: L10n.get(context, 'menu_history_button'),
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const HistoryScreen())),
        ),
        _PillButton(
          icon: Icons.schedule_rounded,
          label: L10n.get(context, 'menu_scheduler_button'),
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const SchedulerScreen())),
        ),
        _PillButton(
          icon: Icons.settings_outlined,
          label: L10n.get(context, 'menu_settings_button'),
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const SettingsScreen())),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms, duration: AppMotion.slow);
  }
}

class _CustomSection extends ConsumerWidget {
  const _CustomSection();

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
        _SectionLabel(L10n.get(context, 'menu_section_custom')),
        const SizedBox(height: AppSpacing.md),
        for (final p in presets) ...[
          _PresetCard(
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

class _PresetCard extends StatelessWidget {
  const _PresetCard({
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

class _PillButton extends StatelessWidget {
  const _PillButton({
    this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppTheme.primary : AppTheme.textDim;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withAlpha(highlighted ? 90 : 40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
