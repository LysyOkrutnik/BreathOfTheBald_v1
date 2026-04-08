import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/states/session_state.dart';
import 'package:okrutnik_breath/ui/screens/summary_screen.dart';
import 'package:okrutnik_breath/ui/widgets/ferrofluid_painter.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final LevelData level;

  const SessionScreen({super.key, required this.level});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(sessionProvider.notifier).startSession(widget.level);
    });
  }

  Future<void> _showExitDialog(BuildContext context, SessionNotifier notifier) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Text(
          L10n.get(context, 'session_exit_dialog_title'),
          style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              L10n.get(context, 'session_exit_dialog_back'),
              style: const TextStyle(color: Colors.white30),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              L10n.get(context, 'session_exit_dialog_finish'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      notifier.finishSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    ref.listen(sessionProvider, (prev, next) {
      next.phase.maybeWhen(
        finished: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SummaryScreen()),
          );
        },
        orElse: () {},
      );
    });

    void showExitDialog() => _showExitDialog(context, notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        showExitDialog();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            const Positioned.fill(child: ParticleBackground()),
            if (state.isGhostMode) _buildGhostModeOverlay(context, notifier),
            if (!state.isGhostMode)
              isLandscape
                  ? _buildLandscapeLayout(context, state, notifier, showExitDialog)
                  : _buildPortraitLayout(context, state, notifier, showExitDialog),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostModeOverlay(BuildContext context, SessionNotifier notifier) {
    return GestureDetector(
      onDoubleTap: notifier.toggleGhostMode,
      child: Container(
        color: Colors.black.withAlpha(242),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off_outlined, color: Colors.white10, size: 64),
              const SizedBox(height: 20),
              Text(
                L10n.get(context, 'session_ghost_mode_title'),
                style: const TextStyle(color: Colors.white10, fontSize: 18, letterSpacing: 2.0),
              ),
              Text(
                L10n.get(context, 'session_ghost_mode_subtitle'),
                style: const TextStyle(color: Colors.white10, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, SessionState state, SessionNotifier notifier, VoidCallback showExitDialog) {
    final shouldBeBig = state.phase.maybeWhen(breathing: (_, inhaling, __) => inhaling, orElse: () => false);
    final currentDuration = state.phase.maybeWhen(breathing: (_, __, dur) => dur, orElse: () => const Duration(seconds: 2));

    return Column(
      children: [
        _buildTopBar(context, state, notifier, showExitDialog),
        Expanded(
          child: GestureDetector(
            onDoubleTap: notifier.toggleGhostMode,
            onTap: () {
              state.phase.maybeWhen(retention: (_) => notifier.finishRetention(), orElse: () {});
            },
            onLongPress: showExitDialog,
            child: Center(
              child: FerrofluidWidget(size: 300, isInhaling: shouldBeBig, duration: currentDuration),
            ),
          ),
        ),
        _buildTopText(context, state, notifier),
        const SizedBox(height: 40),
        _buildBottomProgress(state),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, SessionState state, SessionNotifier notifier, VoidCallback showExitDialog) {
    final shouldBeBig = state.phase.maybeWhen(breathing: (_, inhaling, __) => inhaling, orElse: () => false);
    final currentDuration = state.phase.maybeWhen(breathing: (_, __, dur) => dur, orElse: () => const Duration(seconds: 2));

    return SafeArea(
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: GestureDetector(
              onDoubleTap: notifier.toggleGhostMode,
              onTap: () { state.phase.maybeWhen(retention: (_) => notifier.finishRetention(), orElse: () {}); },
              onLongPress: showExitDialog,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: FerrofluidWidget(size: 250, isInhaling: shouldBeBig, duration: currentDuration),
                ),
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
                const SizedBox(height: 20),
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

    final bool isRetention = state.phase.maybeWhen(retention: (_) => true, orElse: () => false);

    return Column(
      children: [
        Text(
          mainText,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: color, letterSpacing: 4.0, shadows: [Shadow(color: color.withAlpha(128), blurRadius: 20)]),
        ),
        const SizedBox(height: 10),
        Text(subText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2.0)),
        if (isRetention)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(L10n.get(context, 'session_tap_to_inhale'), style: const TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 1.5)),
          ),
      ],
    );
  }

  Widget _buildBottomProgress(SessionState state) {
    double progress = 0;
    state.phase.maybeWhen(
      breathing: (index, _, __) => progress = index / state.totalBreathsInRound,
      recovery: (remaining) => progress = 1 - (remaining.inSeconds / 15.0),
      orElse: () => progress = 0,
    );

    if (progress <= 0) return const SizedBox(height: 4);

    return Container(
      width: 200,
      height: 4,
      decoration: BoxDecoration(color: Colors.white.withAlpha(13), borderRadius: BorderRadius.circular(2)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0, 1),
        child: Container(decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(128), blurRadius: 10)])),
      ),
    );
  }
}
