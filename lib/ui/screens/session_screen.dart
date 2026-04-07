import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/states/session_state.dart';
import 'package:okrutnik_breath/ui/screens/menu_screen.dart';
import 'package:okrutnik_breath/ui/screens/summary_screen.dart';
import 'package:okrutnik_breath/ui/widgets/ferrofluid_painter.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);

    // Navigate to the summary screen when the session is marked as finished.
    ref.listen(sessionProvider, (prev, next) {
      if (next.phase == const SessionPhase.finished()) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SummaryScreen()),
        );
      }
    });

    void showExitDialog() {
      showDialog(
        context: context,
        barrierColor: Colors.black.withAlpha(153),
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(26)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(204), blurRadius: 30, spreadRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.priority_high_rounded, color: AppTheme.danger, size: 32),
                  const SizedBox(height: 24),
                  Text(L10n.get(context, 'session_exit_dialog_title'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300, letterSpacing: 3.0)),
                  const SizedBox(height: 32),
                  Row(children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(L10n.get(context, 'session_exit_dialog_back'), style: const TextStyle(color: Colors.white70)))),
                    const SizedBox(width: 16),
                    Expanded(child: ElevatedButton(onPressed: () { notifier.stopSession(); Navigator.of(context).pop(); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MenuScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), child: Text(L10n.get(context, 'session_exit_dialog_finish'), style: const TextStyle(color: Colors.white))))
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Determine the scale and duration for the central breathing animation based on the current session phase.
    bool shouldBeBig = false;
    Duration currentDuration = const Duration(seconds: 2);
    if (state.customIsBig != null) {
      shouldBeBig = state.customIsBig!;
      state.phase.maybeWhen(breathing: (_, __, dur) => currentDuration = dur, orElse: () {});
    } else {
      state.phase.maybeWhen(
        breathing: (_, isInhaling, duration) { shouldBeBig = isInhaling; currentDuration = duration; },
        retention: (_) { shouldBeBig = false; currentDuration = const Duration(seconds: 2); },
        recovery: (remaining) { shouldBeBig = remaining.inSeconds > 2; currentDuration = const Duration(seconds: 2); },
        orElse: () {},
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async { if (didPop) return; showExitDialog(); },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: OrientationBuilder(
          builder: (context, orientation) {
            final bool isLandscape = orientation == Orientation.landscape;
            return Stack(
              children: [
                // Render the particle background, which is visible in all modes.
                const Positioned.fill(child: ParticleBackground()),

                // Conditionally render the UI based on ghost mode status and device orientation.
                if (state.isGhostMode)
                  _buildGhostModeUI(context, notifier, shouldBeBig, currentDuration)
                else
                  isLandscape
                      ? _buildLandscapeLayout(context, state, notifier, shouldBeBig, currentDuration, showExitDialog)
                      : _buildPortraitLayout(context, state, notifier, shouldBeBig, currentDuration, showExitDialog),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGhostModeUI(BuildContext context, SessionNotifier notifier, bool shouldBeBig, Duration currentDuration) {
    return GestureDetector(
      onDoubleTap: notifier.toggleGhostMode,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Center(
            child: AnimatedScale(
              scale: shouldBeBig ? 1.0 : 0.6,
              duration: currentDuration ~/ 2,
              curve: Curves.easeInOut,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(13), width: 1.5),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "${L10n.get(context, 'session_ghost_mode_title')}\n${L10n.get(context, 'session_ghost_mode_subtitle')}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white12, fontSize: 10, letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, SessionState state, SessionNotifier notifier, bool shouldBeBig, Duration currentDuration, VoidCallback showExitDialog) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: GestureDetector(
              onDoubleTap: notifier.toggleGhostMode,
              onTap: () { state.phase.maybeWhen(retention: (_) => notifier.finishRetention(), orElse: () {}); },
              onLongPress: showExitDialog,
              // Use a FittedBox to ensure the animation scales correctly within the landscape layout without clipping.
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FerrofluidWidget(size: 300, isInhaling: shouldBeBig, duration: currentDuration),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildTopBar(context, state, notifier, showExitDialog),
                const Spacer(),
                _buildTopText(context, state, notifier),
                const Spacer(),
                _buildBottomProgress(state),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, SessionState state, SessionNotifier notifier, VoidCallback showExitDialog) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white30, size: 28), onPressed: showExitDialog),
          if (kDebugMode)
            TextButton(
              onPressed: notifier.finishSession,
              child: Text(L10n.get(context, 'session_skip_button'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          if (state.totalRounds > 1)
            Text("${L10n.get(context, 'session_round')} ${state.currentRound} / ${state.totalRounds}", style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildTopText(BuildContext context, SessionState state, SessionNotifier notifier) {
    String mainText = "";
    String subText = "";
    Color color = Colors.white;

    if (state.customLabel != null) {
      mainText = L10n.get(context, state.customLabel!);
      subText = state.customDescription != null ? L10n.get(context, state.customDescription!) : "";
      if (state.customLabel!.contains("inhale")) {
        color = AppTheme.breathInhale;
      } else if (state.customLabel!.contains("exhale")) {
        color = AppTheme.breathExhale;
      } else if (state.customLabel!.contains("fire")) {
        color = AppTheme.danger;
      } else {
        color = AppTheme.primary;
      }
    } else {
      state.phase.when(
        idle: () {},
        breathing: (index, isInhaling, _) {
          mainText = isInhaling ? L10n.get(context, 'session_inhale') : L10n.get(context, 'session_exhale');
          subText = "$index / ${state.totalBreathsInRound}";
          color = isInhaling ? AppTheme.breathInhale : AppTheme.breathExhale;
        },
        retention: (elapsed) {
          mainText = L10n.get(context, 'session_hold');
          subText = "${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}";
          color = AppTheme.textDim;
        },
        recovery: (remaining) {
          mainText = L10n.get(context, 'session_recovery');
          subText = "${remaining.inSeconds}";
          color = AppTheme.accent;
        },
        finished: () { mainText = L10n.get(context, 'session_finished'); },
      );
    }

    return Column(
      children: [
        Text(
          mainText,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: color, letterSpacing: 4.0, shadows: [Shadow(color: color.withAlpha(128), blurRadius: 20)]),
        ),
        const SizedBox(height: 10),
        Text(subText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2.0)),

        if (state.phase.maybeMap(retention: (_) => true, orElse: () => false) && state.customLabel == null) ...[
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => notifier.finishRetention(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              decoration: BoxDecoration(border: Border.all(color: AppTheme.primary.withAlpha(128)), borderRadius: BorderRadius.circular(30), color: AppTheme.primary.withAlpha(26)),
              child: Text(L10n.get(context, 'session_tap_to_inhale'), style: const TextStyle(color: AppTheme.primary, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildBottomProgress(SessionState state) {
    double progress = 0.0;
    if (state.customLabel != null && state.totalBreathsInRound > 0) {
      state.phase.maybeWhen(breathing: (index, _, __) { progress = index / state.totalBreathsInRound; }, orElse: () {});
    } else {
      state.phase.maybeWhen(breathing: (index, _, __) => progress = index / state.totalBreathsInRound, orElse: () => progress = 0.0);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary), minHeight: 2),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, SessionState state, SessionNotifier notifier, bool shouldBeBig, Duration currentDuration, VoidCallback showExitDialog) {
    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onDoubleTap: notifier.toggleGhostMode,
            onTap: () { state.phase.maybeWhen(retention: (_) => notifier.finishRetention(), orElse: () {}); },
            onLongPress: showExitDialog,
            child: FerrofluidWidget(size: 300, isInhaling: shouldBeBig, duration: currentDuration),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, state, notifier, showExitDialog),
              const SizedBox(height: 40),
              _buildTopText(context, state, notifier),
              const Spacer(),
              _buildBottomProgress(state),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }
}