import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/level_grid.dart';
import 'package:okrutnik_breath/ui/widgets/path_status_card.dart';
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
                      const PathStatusCard(),
                      const SizedBox(height: AppSpacing.lg),
                      // The single most actionable thing on this screen comes
                      // right after status — warnings below are contextual
                      // footnotes, not the primary reason to be here.
                      if (nextUp?.recommendedLevelKey != null) ...[
                        _NextUpCard(levelKey: nextUp!.recommendedLevelKey!),
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
                      // Below the ladder, not above it — for a brand-new
                      // user this is the second thing on the whole screen
                      // otherwise, ahead of ever having done a single
                      // breathing round.
                      const SizedBox(height: AppSpacing.lg),
                      const _ColdShowerCard(),
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
  const _NextUpCard({required this.levelKey});
  final String levelKey;

  @override
  Widget build(BuildContext context) {
    final level = LevelData.levels[levelKey]!;
    return PressableScale(
      onTap: () => Navigator.of(context)
          .push(fadeThroughRoute(IntroScreen(level: level))),
      child: GlassCard(
        gradient: AppTheme.cardGradient(level.color),
        child: Row(
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
      ),
    ).animate().fadeIn(duration: AppMotion.medium).slideY(begin: 0.08);
  }
}

/// A one-tap log for the cold-exposure pillar of the Wim Hof method — no
/// guided screen, since there's nothing to time or pace, just a plain "done"
/// tap available any time (not gated behind Twoja Ścieżka's weekly plan).
/// The inline duration stepper is purely optional context, not a gate: the
/// row itself still logs in one tap at whatever duration is currently shown
/// (defaulting to last time's), so progression is "log a bit longer when you
/// feel like it" rather than a forced ladder.
class _ColdShowerCard extends ConsumerStatefulWidget {
  const _ColdShowerCard();

  @override
  ConsumerState<_ColdShowerCard> createState() => _ColdShowerCardState();
}

class _ColdShowerCardState extends ConsumerState<_ColdShowerCard> {
  static const _minSec = 15;
  static const _maxSec = 600;
  static const _stepSec = 15;

  int? _durationSec;

  int _durationFor(WidgetRef ref) =>
      _durationSec ?? ref.read(lastColdShowerDurationSecProvider) ?? 60;

  void _adjust(int delta) {
    setState(() => _durationSec = (_durationFor(ref) + delta).clamp(_minSec, _maxSec));
  }

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await logColdShowerSession(ref, durationSec: _durationFor(ref));
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(L10n.get(context, 'coldshower_logged_toast')),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: L10n.get(context, 'common_undo'),
          onPressed: () => undoColdShowerSession(ref, result),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A compact row, not a full GlassCard — a daily habit tick shouldn't
    // visually compete with the actual recommendation/warning cards above it
    // or the level ladder below.
    const color = Color(0xFF80D8FF);
    // `_durationFor` itself uses `ref.read` (it's also called from callbacks,
    // where `watch` isn't legal) — without this explicit `watch` here, the
    // card never rebuilt when a shower logged from elsewhere (the scheduler,
    // Twoja Ścieżka) changed the "last used" default, since this tab's
    // State is never torn down/rebuilt on its own between tab switches.
    ref.watch(lastColdShowerDurationSecProvider);
    final duration = _durationFor(ref);
    return PressableScale(
      onTap: () => _log(context, ref),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          // A little more tint than a bare white-10 fill — it was reading
          // as under-discoverable sandwiched between much louder warning
          // cards above and a vivid level grid below.
          color: color.withAlpha(22),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          children: [
            const Icon(Icons.ac_unit_rounded, color: color, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                L10n.get(context, 'coldshower_title'),
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _DurationStepButton(icon: Icons.remove_rounded, color: color,
                onTap: () => _adjust(-_stepSec)),
            SizedBox(
              width: 34,
              child: Text(
                '${duration}s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _DurationStepButton(icon: Icons.add_rounded, color: color,
                onTap: () => _adjust(_stepSec)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}

/// A small +/- control nested inside [_ColdShowerCard]'s single big tap
/// target — its own `Material`/`InkWell` claims taps within its bounds
/// before they reach the row's own `onTap`, so adjusting duration never
/// accidentally logs the shower.
class _DurationStepButton extends StatelessWidget {
  const _DurationStepButton({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 14, color: color.withAlpha(200)),
        ),
      ),
    );
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
