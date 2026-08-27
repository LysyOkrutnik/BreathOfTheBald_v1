import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/freediving/pb_readiness.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// A one-tap log for the cold-exposure pillar of the Wim Hof method — no
/// guided screen, since there's nothing to time or pace, just a plain "done"
/// tap available any time (not gated behind Twoja Ścieżka's weekly plan).
/// The inline duration stepper is purely optional context, not a gate: the
/// row itself still logs in one tap at whatever duration is currently shown
/// (defaulting to last time's), so progression is "log a bit longer when you
/// feel like it" rather than a forced ladder.
///
/// The single canonical instance of this control lives on the Dziś (Today)
/// tab — it previously also had a near-identical copy on the Wim Hof tab and
/// a simpler tap-only version inside Twoja Ścieżka's today card.
class ColdShowerCard extends ConsumerStatefulWidget {
  const ColdShowerCard({super.key});

  @override
  ConsumerState<ColdShowerCard> createState() => _ColdShowerCardState();
}

class _ColdShowerCardState extends ConsumerState<ColdShowerCard> {
  static const _minSec = 15;
  static const _maxSec = 600;
  static const _stepSec = 15;

  int? _durationSec;

  /// Guards `_log` against a fast double-tap logging two showers for one —
  /// the row has no other disabled/pressed visual state to communicate
  /// "already handling this", so the guard is purely in the handler.
  bool _logging = false;

  // A first-time default of 60s contradicted the app's own advice
  // (coldshower_warning3/guide_coldshower_warning1: "never start cold,
  // ease in gradually") — a brand-new user with no history yet now starts
  // much closer to the stepper's own floor instead.
  int _durationFor(WidgetRef ref) =>
      _durationSec ?? ref.read(lastColdShowerDurationSecProvider) ?? 30;

  void _adjust(int delta) {
    setState(() => _durationSec = (_durationFor(ref) + delta).clamp(_minSec, _maxSec));
  }

  /// A readiness-tier hint, purely informational — never changes
  /// [_durationFor]'s actual default, since cold exposure and breath-hold
  /// tolerance are different physiological adaptations and a high freediving
  /// PB is no basis for pushing a longer cold exposure on its own. Null when
  /// there's no active PB reading to hint from at all (the info dialog just
  /// omits this row, same as [monthCount] being 0).
  String? _readinessHintKey(WidgetRef ref) {
    final readiness = ref.read(freedivingReadinessProvider);
    if (readiness == null || !readiness.isActive) return null;
    return switch (readiness.tier) {
      PbReadinessTier.beginner => null,
      PbReadinessTier.intermediate => 'coldshower_readiness_hint_intermediate',
      PbReadinessTier.advanced => 'coldshower_readiness_hint_advanced',
    };
  }

  void _showInfo(BuildContext context, WidgetRef ref) {
    const color = Color(0xFF80D8FF);
    final monthCount = ref.read(coldShowerMonthCountProvider);
    final readinessHintKey = _readinessHintKey(ref);
    showGlassDialog<void>(
      context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(L10n.get(context, 'coldshower_title'),
              style: const TextStyle(
                  color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Text(L10n.get(context, 'coldshower_info_desc'),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 13, height: 1.4)),
          const SizedBox(height: AppSpacing.lg),
          for (final key in const [
            'coldshower_benefit1',
            'coldshower_benefit2',
            'coldshower_benefit3',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: color, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(L10n.get(context, key),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          for (final key in const [
            'coldshower_warning1',
            'coldshower_warning2',
            'coldshower_warning3',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.danger, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(L10n.get(context, key),
                        style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                  ),
                ],
              ),
            ),
          if (readinessHintKey != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: color, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    L10n.get(context, readinessHintKey),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
          if (monthCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: color, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  "$monthCount ${L10n.get(context, 'coldshower_stat_month_suffix')}",
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(L10n.get(context, 'common_ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    if (_logging) return;
    _logging = true;
    try {
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
    } finally {
      _logging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A compact row, not a full GlassCard — a daily habit tick shouldn't
    // visually compete with louder recommendation/warning cards around it.
    const color = Color(0xFF80D8FF);
    // `_durationFor` itself uses `ref.read` (it's also called from callbacks,
    // where `watch` isn't legal) — without this explicit `watch` here, the
    // card never rebuilt when a shower logged from elsewhere (the scheduler)
    // changed the "last used" default, since this tab's State is never torn
    // down/rebuilt on its own between tab switches.
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
          // A little more tint than a bare white-10 fill — under-discoverable
          // sandwiched between louder cards otherwise.
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
            _DurationStepButton(icon: Icons.info_outline_rounded, color: color,
                onTap: () => _showInfo(context, ref)),
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

/// A small +/- control nested inside [ColdShowerCard]'s single big tap
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
