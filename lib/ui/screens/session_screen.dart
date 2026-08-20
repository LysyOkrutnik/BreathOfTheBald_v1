import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/states/session_state.dart';
import 'package:okrutnik_breath/ui/screens/home_shell_screen.dart';
import 'package:okrutnik_breath/ui/screens/summary_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/ferrofluid_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);

    ref.listen(sessionProvider, (prev, next) {
      if (next.phase == const SessionPhase.finished()) {
        // If a dialog is open when the session finishes on its own (e.g. the
        // last round completes while the exit-confirm dialog is still up),
        // dismiss it first — otherwise it lingers as an orphaned overlay on
        // top of the screen `pushReplacement` navigates to next.
        if (_sessionDialogOpen) {
          Navigator.of(context).pop();
          _sessionDialogOpen = false;
        }
        Navigator.of(context).pushReplacement(fadeThroughRoute(const SummaryScreen()));
      }
    });

    ref.listen(sessionProvider.select((s) => s.awaitingRoundDecision), (prev, next) {
      if (next) _showRoundIncompleteDialog(context, notifier);
    });

    final visuals = _Visuals.from(state);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog(context, notifier);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(child: AppBackground(intensity: 0.45)),
            SafeArea(
              // A double-tap toggling Ghost Mode used to swap layouts with no
              // transition at all — combined with how subtle the dimmed
              // layout is, it wasn't obvious the tap had done anything.
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                child: state.isGhostMode
                    ? _GhostLayout(
                        key: const ValueKey('ghost'),
                        notifier: notifier,
                        visuals: visuals,
                      )
                    : KeyedSubtree(
                        key: const ValueKey('normal'),
                        child: context.isLandscape
                            ? _LandscapeLayout(state: state, notifier: notifier, visuals: visuals)
                            : _PortraitLayout(state: state, notifier: notifier, visuals: visuals),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resolved animation inputs for the current phase.
class _Visuals {
  const _Visuals({required this.isBig, required this.duration});
  final bool isBig;
  final Duration duration;

  factory _Visuals.from(SessionState state) {
    var isBig = false;
    var duration = const Duration(seconds: 2);
    if (state.customIsBig != null) {
      isBig = state.customIsBig!;
      state.phase.maybeWhen(
        breathing: (_, __, d) => duration = d,
        orElse: () {},
      );
    } else {
      state.phase.maybeWhen(
        breathing: (_, isInhaling, d) {
          isBig = isInhaling;
          duration = d;
        },
        recovery: (remaining) => isBig = remaining.inSeconds > 2,
        // Without this, the blob froze deflated for the entire hold (which
        // can run minutes) — it now breathes slowly in place so the screen
        // reads as "alive and waiting", not stalled.
        retention: (elapsed) {
          isBig = (elapsed.inSeconds ~/ 4).isEven;
          duration = const Duration(seconds: 4);
        },
        orElse: () {},
      );
    }
    return _Visuals(isBig: isBig, duration: duration);
  }
}

double _blobSize(BuildContext context, BoxConstraints c) {
  final limit = c.biggest.shortestSide * (context.isTablet ? 0.7 : 0.82);
  return limit.clamp(200.0, 520.0);
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({required this.state, required this.notifier, required this.visuals});
  final SessionState state;
  final SessionNotifier notifier;
  final _Visuals visuals;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: notifier.toggleGhostMode,
            onTap: () => state.phase.maybeWhen<void>(
                retention: (_) => notifier.finishRetention(), orElse: () {}),
            onLongPress: () => _showExitDialog(context, notifier),
            child: LayoutBuilder(
              builder: (context, c) => FerrofluidWidget(
                size: _blobSize(context, c),
                isInhaling: visuals.isBig,
                duration: visuals.duration,
              ),
            ),
          ),
        ),
        Column(
          children: [
            _TopBar(state: state, notifier: notifier),
            const SizedBox(height: AppSpacing.xl),
            _PhaseText(state: state, notifier: notifier),
            const Spacer(),
            _ProgressBar(state: state),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ],
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({required this.state, required this.notifier, required this.visuals});
  final SessionState state;
  final SessionNotifier notifier;
  final _Visuals visuals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: notifier.toggleGhostMode,
            onTap: () => state.phase.maybeWhen<void>(
                retention: (_) => notifier.finishRetention(), orElse: () {}),
            onLongPress: () => _showExitDialog(context, notifier),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, c) => Center(
                  child: FerrofluidWidget(
                    size: _blobSize(context, c),
                    isInhaling: visuals.isBig,
                    duration: visuals.duration,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _TopBar(state: state, notifier: notifier),
              // The phase text scrolls/centres in the middle so a short
              // landscape phone never overflows during the (taller) retention
              // phase.
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _PhaseText(state: state, notifier: notifier),
                  ),
                ),
              ),
              _ProgressBar(state: state),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

class _GhostLayout extends StatelessWidget {
  const _GhostLayout({super.key, required this.notifier, required this.visuals});
  final SessionNotifier notifier;
  final _Visuals visuals;

  @override
  Widget build(BuildContext context) {
    final ringSize =
        (context.shortestSide * (context.isTablet ? 0.5 : 0.66)).clamp(180.0, 420.0);
    return GestureDetector(
      onDoubleTap: notifier.toggleGhostMode,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Center(
            child: AnimatedScale(
              scale: visuals.isBig ? 1.0 : 0.6,
              duration: visuals.duration ~/ 2,
              curve: Curves.easeInOut,
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Was alpha 14 (~5% opacity) — at the intended viewing
                  // distance (phone down, eyes half-closed) that read as
                  // "nothing on screen", not "dimmed". Still far below the
                  // normal session's contrast, just no longer invisible.
                  border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              "${L10n.get(context, 'session_ghost_mode_title')}\n"
              "${L10n.get(context, 'session_ghost_mode_subtitle')}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.notifier});
  final SessionState state;
  final SessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 26),
            onPressed: () => _showExitDialog(context, notifier),
          ),
          if (state.totalRounds > 1)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                "${L10n.get(context, 'session_round')} ${state.currentRound}/${state.totalRounds}",
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11, letterSpacing: 1.5),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _PhaseText extends StatelessWidget {
  const _PhaseText({required this.state, required this.notifier});
  final SessionState state;
  final SessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    var mainText = '';
    var subText = '';
    var hintText = '';
    var color = Colors.white;

    // Whether to show the "tap to end early" hint depends only on the
    // underlying phase (a breath-hold), never on whether customLabel is
    // overriding the displayed text — otherwise a labeled hold (freediving
    // tables) would silently hide this safety-relevant, always-available
    // early-abort control. It must never be shown for anything other than an
    // actual hold — freediving's inhale/exhale/rest/warm-up/cool-down phases
    // are deliberately `breathing`/`recovery`, not `retention`, specifically
    // so a tap during those moments does nothing instead of ending the table.
    final showTapHint =
        state.phase.maybeMap(retention: (_) => true, orElse: () => false);
    final isFreedivingHold = state.customLabel == 'freediving_hold_label';

    // The warm-up and cool-down pauses expose an explicit "skip" control
    // instead of the tap-to-abort gesture.
    final showSkip = state.customLabel == 'freediving_warmup_label' ||
        state.customLabel == 'freediving_cooldown_label';

    if (state.customLabel != null) {
      mainText = L10n.get(context, state.customLabel!);
      hintText = state.customDescription != null
          ? L10n.get(context, state.customDescription!)
          : '';
      final label = state.customLabel!;
      if (label.contains('inhale')) {
        color = AppTheme.breathInhale;
      } else if (label.contains('exhale')) {
        color = AppTheme.breathExhale;
      } else if (label.contains('fire')) {
        color = AppTheme.danger;
      } else {
        color = AppTheme.primary;
      }

      // customLabel only overrides the *heading*; the live countdown (hold
      // elapsed, or a rest/warm-up/cool-down countdown) still needs to be the
      // prominent subText, with any instructional copy demoted to hintText.
      state.phase.maybeWhen(
        retention: (elapsed) {
          subText =
              "${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}";
        },
        recovery: (remaining) {
          subText = "${remaining.inSeconds}";
        },
        orElse: () {},
      );
    } else {
      state.phase.when(
        idle: () {},
        breathing: (index, isInhaling, _) {
          mainText = isInhaling
              ? L10n.get(context, 'session_inhale')
              : L10n.get(context, 'session_exhale');
          subText = "$index / ${state.totalBreathsInRound}";
          color = isInhaling ? AppTheme.breathInhale : AppTheme.breathExhale;
        },
        retention: (elapsed) {
          mainText = L10n.get(context, 'session_hold');
          subText =
              "${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}";
          color = AppTheme.textDim;
        },
        recovery: (remaining) {
          mainText = L10n.get(context, 'session_recovery');
          subText = "${remaining.inSeconds}";
          color = AppTheme.accent;
        },
        finished: () => mainText = L10n.get(context, 'session_finished'),
      );
    }

    return Column(
      children: [
        AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          style: TextStyle(
            fontSize: context.responsive(compact: 34, expanded: 44),
            fontWeight: FontWeight.w200,
            color: color,
            letterSpacing: 6.0,
            shadows: [Shadow(color: color.withAlpha(120), blurRadius: 24)],
          ),
          child: Text(mainText, textAlign: TextAlign.center),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subText,
          textAlign: TextAlign.center,
          // Was white30 — this is the live hold/recovery countdown, not
          // decorative chrome, and read too low-contrast against the
          // session's pure-black background.
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 2.0,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (hintText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              hintText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (showTapHint) ...[
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            onTap: notifier.finishRetention,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppTheme.primary.withAlpha(120)),
              ),
              child: Text(
                L10n.get(context,
                    isFreedivingHold ? 'freediving_hold_tap_hint' : 'session_tap_to_inhale'),
                style: const TextStyle(
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const _GhostModeHint(),
          if (isFreedivingHold) ...[
            const SizedBox(height: AppSpacing.lg),
            _ContractionMarker(
              markCount: state.contractionMarkCount,
              onTap: notifier.markContraction,
            ),
          ],
        ],
        if (showSkip) ...[
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            onTap: notifier.skipFreedivingPause,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                L10n.get(context, 'freediving_skip'),
                style: const TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A one-time nudge toward Ghost Mode (double-tap to dim the screen),
/// surfaced during the first breath-hold a user ever reaches rather than
/// leaving it buried in onboarding/the guide — that's the exact moment it's
/// actually useful, staring at a screen with nothing left to do but wait.
class _GhostModeHint extends StatefulWidget {
  const _GhostModeHint();

  @override
  State<_GhostModeHint> createState() => _GhostModeHintState();
}

class _GhostModeHintState extends State<_GhostModeHint> {
  static const _prefsKey = 'ghost_mode_hint_shown';
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) ?? false) return;
    await prefs.setBool(_prefsKey, true);
    if (mounted) setState(() => _visible = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Text(
        L10n.get(context, 'session_ghost_mode_hint'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.0),
      ),
    );
  }
}

/// Freediving-only control shown during a hold: marks the moment the
/// diaphragm's urge-to-breathe reflex first shows up ("first contraction")
/// without ending the hold — a small, deliberately secondary pill so it's
/// never confused with the tap-to-abort control directly above it. Taps
/// trigger a light haptic and a brief expanding-ring pulse purely as tactile
/// confirmation; the actual data (elapsed time, count) is tracked by the
/// notifier and only surfaced later, in the session summary.
class _ContractionMarker extends StatefulWidget {
  const _ContractionMarker({required this.markCount, required this.onTap});
  final int markCount;
  final VoidCallback onTap;

  @override
  State<_ContractionMarker> createState() => _ContractionMarkerState();
}

class _ContractionMarkerState extends State<_ContractionMarker> {
  int _rippleKey = 0;

  void _handleTap() {
    widget.onTap();
    setState(() => _rippleKey++);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // A fresh ValueKey per tap restarts this animation from scratch —
          // the ripple always plays even on rapid repeated taps.
          TweenAnimationBuilder<double>(
            key: ValueKey(_rippleKey),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, t, _) => _rippleKey == 0
                ? const SizedBox.shrink()
                : Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Container(
                      width: 44 + t * 26,
                      height: 44 + t * 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accent.withAlpha(160), width: 1.5),
                      ),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.waves_rounded, color: AppTheme.accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  L10n.get(context, 'freediving_mark_contraction'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.markCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${widget.markCount}',
                      style: const TextStyle(
                          color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});
  final SessionState state;

  @override
  Widget build(BuildContext context) {
    var progress = 0.0;
    // A hold has no fixed length to show fractional progress against (Wim
    // Hof retention is open-ended; even a freediving table's target isn't
    // known here) — an indeterminate animation at least reads as "running",
    // instead of the bar sitting frozen at 0% for the whole hold.
    final isIndeterminate =
        state.phase.maybeMap(retention: (_) => true, orElse: () => false);
    if (state.totalBreathsInRound > 0) {
      state.phase.maybeWhen(
        breathing: (index, _, __) => progress = index / state.totalBreathsInRound,
        orElse: () {},
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: isIndeterminate
            ? const LinearProgressIndicator(
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 3,
              )
            : TweenAnimationBuilder<double>(
                tween: Tween(end: progress.clamp(0.0, 1.0)),
                duration: AppMotion.fast,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 3,
                ),
              ),
      ),
    );
  }
}

/// Guards [_showExitDialog]/[_showRoundIncompleteDialog] against stacking on
/// top of each other — e.g. a background/foreground interruption firing the
/// exit-confirm dialog while the missed-round dialog is already open would
/// otherwise leave two `DialogRoute`s on the stack; popping the top one then
/// left the *other* dialog, not the actual SessionScreen route, as the
/// target of a subsequent `pushReplacement`.
bool _sessionDialogOpen = false;

void _showExitDialog(BuildContext context, SessionNotifier notifier) {
  if (_sessionDialogOpen) return;
  _sessionDialogOpen = true;
  showDialog(
    context: context,
    barrierColor: Colors.black.withAlpha(160),
    builder: (dialogContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          // Dialogs have no natural width cap of their own — on a tablet
          // this would otherwise stretch to the full inset width, spreading
          // the button row out awkwardly.
          constraints:
              BoxConstraints(maxWidth: dialogContext.isTablet ? 420 : double.infinity),
          child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withAlpha(28)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 8),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.priority_high_rounded, color: AppTheme.danger, size: 34),
              const SizedBox(height: AppSpacing.lg),
              Text(
                L10n.get(context, 'session_exit_dialog_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                L10n.get(context, 'session_exit_dialog_body'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        L10n.get(context, 'session_exit_dialog_back'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                      onPressed: () {
                        notifier.stopSession();
                        Navigator.of(dialogContext).pop();
                        // The session can finish on its own while this dialog
                        // is still open (e.g. the last round completes while
                        // the user is deciding) — that already navigated
                        // `context`'s route away via pushReplacement, so
                        // reusing it here would hit a deactivated widget.
                        if (context.mounted) {
                          Navigator.of(context)
                              .pushReplacement(fadeThroughRoute(const HomeShellScreen()));
                        }
                      },
                      child: Text(
                        L10n.get(context, 'session_exit_dialog_finish'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    ),
  ).then((_) => _sessionDialogOpen = false);
}

/// Shown once a freediving table round ends early (the hold itself always
/// ends immediately on tap — this only decides what happens next). No
/// barrier-tap or back-button dismissal: leaving the session mid-decision
/// with a stale `awaitingRoundDecision` would strand the flow.
void _showRoundIncompleteDialog(BuildContext context, SessionNotifier notifier) {
  if (_sessionDialogOpen) return;
  _sessionDialogOpen = true;
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(160),
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: dialogContext.isTablet ? 420 : double.infinity),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(16),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Colors.white.withAlpha(28)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 8),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.waves_rounded, color: AppTheme.accent, size: 34),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    L10n.get(context, 'freediving_round_incomplete_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    L10n.get(context, 'freediving_round_incomplete_body'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            notifier.endSessionAfterMissedRound();
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text(
                            L10n.get(context, 'freediving_round_incomplete_end'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                          onPressed: () {
                            notifier.continueAfterMissedRound();
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text(
                            L10n.get(context, 'freediving_round_incomplete_continue'),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ).then((_) => _sessionDialogOpen = false);
}
