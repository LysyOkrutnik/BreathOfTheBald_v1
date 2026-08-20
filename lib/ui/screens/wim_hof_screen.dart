import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/level_grid.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Wim Hof" bottom-nav tab: the classic ladder (Nowicjusz → Okrutnik),
/// plus a "Next Up" progression recommendation and safety notices. Only ever
/// shown as a shell tab root — the shared background lives in
/// HomeShellScreen so it isn't torn down and rebuilt (with its animation
/// restarting) every time the tab is switched.
class WimHofScreen extends ConsumerWidget {
  const WimHofScreen({super.key});

  static const _classic = ['mild', 'strong', 'beast', 'guru'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = (context.isTablet || context.isLandscape) ? 2 : 1;
    final nextUp = ref.watch(wimHofNextUpProvider).value;
    final weeklyHardCount = ref.watch(weeklyHardSessionCountProvider);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isTablet ? 900 : double.infinity,
          ),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'menu_section_classic'),
                showBackButton: false,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  L10n.get(context, 'menu_select_rhythm'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDim.withAlpha(200),
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(duration: AppMotion.slow),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The single most actionable thing on this screen comes
                      // first — warnings below are contextual footnotes, not
                      // the primary reason to be here. Path status/today's
                      // plan now lives on the Dziś tab, not duplicated here.
                      if (nextUp?.recommendedLevelKey != null) ...[
                        _NextUpCard(
                          levelKey: nextUp!.recommendedLevelKey!,
                          pbCautionAdvised: nextUp.pbCautionAdvised,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (nextUp?.justRolledBackFrom != null) ...[
                        _RollbackNotice(levelKey: nextUp!.currentLevelKey),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (weeklyHardCount >= kWeeklyHardSessionCap) ...[
                        const _WeeklyCapWarning(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      LevelGrid(keys: _classic, columns: columns),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.levelKey, this.pbCautionAdvised = false});
  final String levelKey;

  /// Advisory only (see WimHofNextUp.pbCautionAdvised) — never hides or
  /// disables the card itself, just adds a note underneath it.
  final bool pbCautionAdvised;

  @override
  Widget build(BuildContext context) {
    final level = LevelData.levels[levelKey]!;
    return PressableScale(
      onTap: () => Navigator.of(context)
          .push(fadeThroughRoute(IntroScreen(level: level))),
      child: GlassCard(
        gradient: AppTheme.cardGradient(level.color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: level.color, size: 26),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10n.get(context, 'wimhof_next_up_title'),
                        style: TextStyle(
                          color: level.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${L10n.get(context, 'wimhof_next_up_body')} ${L10n.get(context, level.title)}",
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    L10n.get(context, 'wimhof_next_up_cta'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: level.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            if (pbCautionAdvised) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.lure, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      L10n.get(context, 'wimhof_pb_caution_note'),
                      style: const TextStyle(color: AppTheme.lure, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppMotion.medium).slideY(begin: 0.08);
  }
}

class _RollbackNotice extends StatelessWidget {
  const _RollbackNotice({required this.levelKey});
  final String levelKey;

  @override
  Widget build(BuildContext context) {
    final level = LevelData.levels[levelKey]!;
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.spa_outlined, color: AppTheme.accent, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${L10n.get(context, 'wimhof_rollback_title')} ${L10n.get(context, level.title)}",
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10n.get(context, 'wimhof_rollback_body'),
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}

class _WeeklyCapWarning extends StatelessWidget {
  const _WeeklyCapWarning();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppTheme.cardGradient(AppTheme.danger),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              L10n.get(context, 'wimhof_weekly_cap_warning'),
              style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}
