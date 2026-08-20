import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
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
