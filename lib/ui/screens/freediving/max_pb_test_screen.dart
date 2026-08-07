import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// A guided, in-app Personal Best (static apnea) test: a simple stopwatch the
/// user starts when beginning their breath-hold and stops the moment they
/// resume breathing. This is deliberately the app's only way to set PB (no
/// manual entry) since a supervised, in-app measurement is far more reliable
/// than a self-reported number typed from memory.
class MaxPbTestScreen extends ConsumerStatefulWidget {
  const MaxPbTestScreen({super.key});

  @override
  ConsumerState<MaxPbTestScreen> createState() => _MaxPbTestScreenState();
}

enum _TestState { idle, running, stopped }

class _MaxPbTestScreenState extends ConsumerState<MaxPbTestScreen> {
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  _TestState _testState = _TestState.idle;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch
      ..reset()
      ..start();
    setState(() => _testState = _TestState.running);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() => _elapsed = _stopwatch.elapsed);
    });
  }

  void _stop() {
    _stopwatch.stop();
    _ticker?.cancel();
    setState(() {
      _elapsed = _stopwatch.elapsed;
      _testState = _TestState.stopped;
    });
  }

  void _reset() {
    _stopwatch.reset();
    setState(() {
      _elapsed = Duration.zero;
      _testState = _TestState.idle;
    });
  }

  Future<void> _save() async {
    final seconds = _elapsed.inSeconds;
    try {
      await ref.read(freedivingRepositoryProvider).recordVerifiedPb(seconds);

      // Log as a regular training session too, so it counts toward streak,
      // history and XP like any other completed practice.
      final gamification = ref.read(gamificationServiceProvider);
      final xpEarned = await gamification.updateXpAndLevel(
        breathCount: 0,
        retentionSeconds: (seconds * 0.3).round(),
        multiplier: 0.5,
      );
      await gamification.updateStreak();
      await ref.read(sessionRepositoryProvider).addSession(
            levelKey: 'freediving_pb_test',
            timestamp: DateTime.now(),
            durationSec: seconds,
            rounds: 1,
            retentionSec: seconds,
            xpEarned: xpEarned,
          );
    } catch (e, st) {
      developer.log('Failed to save PB test',
          name: 'MaxPbTestScreen', error: e, stackTrace: st);
    }
    if (mounted) Navigator.of(context).pop();
  }

  String _fmt(Duration d) =>
      "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(accent: AppTheme.primary)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 560 : 480),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'freediving_pb_test_title')),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_testState == _TestState.idle) ...[
                              Text(
                                L10n.get(context, 'freediving_pb_test_intro'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppTheme.textDim, fontSize: 14, height: 1.5),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                            ],
                            GlowHalo(
                              color: AppTheme.primary,
                              diameter: 200,
                              haloScale: 1.6,
                              intensity: _testState == _TestState.running ? 130 : 70,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primary.withAlpha(20),
                                  border: Border.all(
                                      color: AppTheme.primary.withAlpha(100)),
                                ),
                                child: Center(
                                  child: Text(
                                    _fmt(_elapsed),
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w200,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            if (_testState != _TestState.stopped)
                              _ActionButton(
                                label: L10n.get(
                                  context,
                                  _testState == _TestState.idle
                                      ? 'freediving_pb_test_start'
                                      : 'freediving_pb_test_stop',
                                ),
                                color: _testState == _TestState.idle
                                    ? AppTheme.primary
                                    : AppTheme.danger,
                                onTap: _testState == _TestState.idle ? _start : _stop,
                              )
                            else
                              _ConfirmPanel(
                                elapsedSeconds: _elapsed.inSeconds,
                                onSave: _save,
                                onDiscard: _reset,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppTheme.glow(color, blur: 22),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({
    required this.elapsedSeconds,
    required this.onSave,
    required this.onDiscard,
  });

  final int elapsedSeconds;
  final Future<void> Function() onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final warningKey = Co2O2TableGenerator.validatePb(elapsedSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          L10n.get(context, 'freediving_pb_test_confirm_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (warningKey != null) ...[
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            radius: AppRadius.md,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.danger, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    L10n.get(context, warningKey),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ActionButton(
          label: L10n.get(context, 'freediving_pb_test_save'),
          color: AppTheme.primary,
          onTap: () => onSave(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: onDiscard,
          child: Text(
            L10n.get(context, 'freediving_pb_test_cancel'),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
