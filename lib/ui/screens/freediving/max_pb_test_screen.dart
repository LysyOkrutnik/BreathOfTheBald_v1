import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';
import 'package:okrutnik_breath/ui/widgets/primary_button.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// A guided, in-app Personal Best test — the app's only way to set PB (no
/// manual entry), since a supervised, in-app measurement is far more
/// reliable than a self-reported number typed from memory.
///
/// Runs TWO breath-holds back to back: an exhale-hold (empty lungs — mostly
/// limited by rising CO2, generally the gentler of the two) and, after a
/// recovery period scaled to that first hold, an inhale-hold (full lungs —
/// the closer-to-true-limit, higher-stakes test). One number alone conflates
/// two different physiological limits; measuring both lets the CO2 table
/// anchor on the exhale-hold result and the O2 table anchor on the
/// inhale-hold result, instead of both sharing a single guess.
class MaxPbTestScreen extends ConsumerStatefulWidget {
  const MaxPbTestScreen({super.key});

  @override
  ConsumerState<MaxPbTestScreen> createState() => _MaxPbTestScreenState();
}

/// Which of the two holds is currently in progress.
enum _Stage { exhale, inhale }

enum _Phase { intro, relax, holding, recovery, results }

class _MaxPbTestScreenState extends ConsumerState<MaxPbTestScreen> {
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _relaxTimer;
  Timer? _recoveryTimer;

  _Phase _phase = _Phase.intro;
  _Stage _stage = _Stage.exhale;
  Duration _elapsed = Duration.zero;

  int? _exhaleHoldSec;
  int? _inhaleHoldSec;
  FreedivingProfileData? _previousProfile;

  static const _relaxSeconds = 60;
  int _relaxRemaining = _relaxSeconds;

  /// Recovery must be at least this long even after a very short first hold —
  /// heart rate/SpO2 normalization takes a baseline amount of time regardless
  /// of how brief the exhale-hold was.
  static const _recoveryFloorSeconds = 60;
  static const _recoveryMultiplier = 3;
  int _recoveryTotalSeconds = 0;
  int _recoveryRemaining = 0;

  // `_confirmSave` is `async` — without this guard, a fast double-tap on
  // Save runs the whole sequence (record PB, award XP, log a session) twice.
  bool _saving = false;
  bool _resultsSaved = false;

  DateTime _nextTestDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _nextTestTime = TimeOfDay.now();

  @override
  void dispose() {
    _ticker?.cancel();
    _relaxTimer?.cancel();
    _recoveryTimer?.cancel();
    super.dispose();
  }

  void _beginProtocol() {
    setState(() => _stage = _Stage.exhale);
    _startRelax();
  }

  void _startRelax() {
    setState(() {
      _phase = _Phase.relax;
      _relaxRemaining = _relaxSeconds;
    });
    _relaxTimer?.cancel();
    _relaxTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_relaxRemaining <= 1) {
        t.cancel();
        if (mounted) setState(() => _relaxRemaining = 0);
      } else if (mounted) {
        setState(() => _relaxRemaining--);
      }
    });
  }

  /// Tapping this ends the relax countdown early (whatever's left) and
  /// starts the hold — the 60s is guidance, not a forced wait, matching how
  /// a real breathe-up works: you start when you're actually ready.
  void _beginHold() {
    _relaxTimer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _phase = _Phase.holding;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
    });
  }

  Future<void> _endHold() async {
    _stopwatch.stop();
    _ticker?.cancel();
    final seconds = _stopwatch.elapsed.inSeconds;

    if (_stage == _Stage.exhale) {
      _exhaleHoldSec = seconds;
      _startRecovery(seconds);
      return;
    }

    _inhaleHoldSec = seconds;
    final previous = await ref.read(freedivingRepositoryProvider).getProfile();
    if (!mounted) return;
    setState(() {
      _previousProfile = previous;
      _phase = _Phase.results;
    });
  }

  void _startRecovery(int exhaleHoldSec) {
    final total =
        math.max(_recoveryFloorSeconds, exhaleHoldSec * _recoveryMultiplier);
    setState(() {
      _phase = _Phase.recovery;
      _recoveryTotalSeconds = total;
      _recoveryRemaining = total;
    });
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_recoveryRemaining <= 1) {
        t.cancel();
        if (!mounted) return;
        setState(() => _stage = _Stage.inhale);
        _startRelax();
      } else if (mounted) {
        setState(() => _recoveryRemaining--);
      }
    });
  }

  Future<void> _confirmSave() async {
    if (_saving) return;
    _saving = true;
    final exhale = _exhaleHoldSec!;
    final inhale = _inhaleHoldSec!;
    try {
      await ref.read(freedivingRepositoryProvider).recordVerifiedPb(
            exhalePbSeconds: exhale,
            inhalePbSeconds: inhale,
          );

      // Logged as a regular training session too, so it counts toward
      // streak, history and XP like any other completed practice.
      final gamification = ref.read(gamificationServiceProvider);
      final totalHoldSec = exhale + inhale;
      // breathCount is always 0 for a breath-hold test — retention alone
      // drives XP here. `multiplier` has no effect against a 0 breathCount;
      // passing a literal 0 makes that explicit instead of a misleading 0.5
      // that reads like it's doing something.
      final xpResult = await gamification.updateXpAndLevel(
        breathCount: 0,
        retentionSeconds: (totalHoldSec * 0.3).round(),
        multiplier: 0,
      );
      await gamification.updateStreak();
      await ref.read(sessionRepositoryProvider).addSession(
            levelKey: 'freediving_pb_test',
            timestamp: DateTime.now(),
            durationSec: totalHoldSec,
            rounds: 2,
            retentionSec: totalHoldSec,
            xpEarned: xpResult.xpEarned,
          );
    } catch (e, st) {
      developer.log('Failed to save PB test',
          name: 'MaxPbTestScreen', error: e, stackTrace: st);
    }
    if (mounted) setState(() => _resultsSaved = true);
  }

  Future<void> _pickNextTestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextTestDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _nextTestDate = picked);
  }

  Future<void> _pickNextTestTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _nextTestTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            onPrimary: Colors.black,
            surface: AppTheme.background,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _nextTestTime = picked);
  }

  Future<void> _scheduleNextTest() async {
    final scheduledAt = DateTime(
      _nextTestDate.year,
      _nextTestDate.month,
      _nextTestDate.day,
      _nextTestTime.hour,
      _nextTestTime.minute,
    );
    if (scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.get(context, 'planner_time_in_past'))));
      return;
    }

    final reminderTitle = L10n.get(context, 'planner_reminder_title');
    final testLabel = L10n.get(context, 'freediving_pb_test_title');

    final planId = await ref
        .read(plannerRepositoryProvider)
        .addPlan(scheduledAt: scheduledAt, levelKey: 'freediving_pb_test');
    await ref.read(notificationServiceProvider).scheduleOneTime(
          id: planId,
          when: scheduledAt.subtract(const Duration(minutes: 5)),
          title: reminderTitle,
          body: testLabel,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(L10n.get(context, 'freediving_pb_test_scheduled_toast'))));
    Navigator.of(context).pop();
  }

  String _fmtSec(int seconds) =>
      "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";

  /// True while a hold/relax/recovery is actually in progress — leaving the
  /// screen here silently discards a just-run or in-progress result, unlike
  /// the intro/results phases where there's nothing to lose.
  bool get _midTest =>
      _phase == _Phase.relax ||
      _phase == _Phase.holding ||
      _phase == _Phase.recovery;

  Future<void> _handleBack() async {
    // `PopScope` below is permanently `canPop: false` so this handler always
    // gets a chance to confirm mid-test — but that also means
    // `Navigator.maybePop()` re-enters the very same gate and gets blocked
    // again, silently re-triggering this handler instead of leaving. A
    // direct `pop()` bypasses `PopScope.canPop` entirely (it only gates the
    // system back gesture / `maybePop()`), so it's the one that actually
    // closes the screen once we've decided to.
    if (!_midTest) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showGlassConfirm(
      context,
      title: L10n.get(context, 'freediving_pb_test_exit_confirm_title'),
      body: L10n.get(context, 'freediving_pb_test_exit_confirm_body'),
      confirmLabel: L10n.get(context, 'freediving_pb_test_exit_confirm_yes'),
      cancelLabel: L10n.get(context, 'common_cancel'),
      icon: Icons.warning_amber_rounded,
    );
    if (confirmed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(sectionAccent: AppTheme.primary)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 560 : 480),
                child: Column(
                  children: [
                    ScreenHeader(
                      title: L10n.get(context, 'freediving_pb_test_title'),
                      onBack: _handleBack,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(minHeight: constraints.maxHeight),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [_buildPhase(context)],
                                ),
                              ),
                            );
                          },
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
      ),
    );
  }

  Widget _buildPhase(BuildContext context) {
    switch (_phase) {
      case _Phase.intro:
        return _IntroView(onBegin: _beginProtocol);
      case _Phase.relax:
        return _RelaxView(
          stage: _stage,
          remainingSeconds: _relaxRemaining,
          totalSeconds: _relaxSeconds,
          onBeginHold: _beginHold,
        );
      case _Phase.holding:
        return _HoldingView(stage: _stage, elapsed: _elapsed, onEnd: () => _endHold());
      case _Phase.recovery:
        return _RecoveryView(
          remainingSeconds: _recoveryRemaining,
          totalSeconds: _recoveryTotalSeconds,
        );
      case _Phase.results:
        return _ResultsView(
          exhaleSec: _exhaleHoldSec!,
          inhaleSec: _inhaleHoldSec!,
          previousExhaleSec: _previousProfile?.verifiedPbCo2Sec,
          previousInhaleSec: _previousProfile?.verifiedPbSec,
          saved: _resultsSaved,
          onSave: _confirmSave,
          nextTestDate: _nextTestDate,
          nextTestTime: _nextTestTime,
          onPickDate: _pickNextTestDate,
          onPickTime: _pickNextTestTime,
          onScheduleNext: _scheduleNextTest,
          onSkipSchedule: () => Navigator.of(context).pop(),
          fmtSec: _fmtSec,
        );
    }
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.onBegin});
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.get(context, 'freediving_pb_test_full_intro'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
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
                  L10n.get(context, 'freediving_safety_rule1'),
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: L10n.get(context, 'freediving_pb_test_begin'),
          color: AppTheme.primary,
          onTap: onBegin,
        ),
      ],
    );
  }
}

class _RelaxView extends StatelessWidget {
  const _RelaxView({
    required this.stage,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onBeginHold,
  });

  final _Stage stage;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onBeginHold;

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (remainingSeconds / totalSeconds);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.get(context, 'freediving_pb_test_relax_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(
              context,
              stage == _Stage.exhale
                  ? 'freediving_pb_test_relax_exhale_body'
                  : 'freediving_pb_test_relax_inhale_body'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
              Text(
                '$remainingSeconds',
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 40,
                  fontWeight: FontWeight.w200,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: L10n.get(context, 'freediving_pb_test_begin_hold'),
          color: AppTheme.primary,
          onTap: onBeginHold,
        ),
      ],
    );
  }
}

class _HoldingView extends StatelessWidget {
  const _HoldingView({required this.stage, required this.elapsed, required this.onEnd});
  final _Stage stage;
  final Duration elapsed;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final fmt =
        "$minutes:${seconds.toString().padLeft(2, '0')}";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.get(
              context,
              stage == _Stage.exhale
                  ? 'freediving_pb_test_holding_exhale_label'
                  : 'freediving_pb_test_holding_inhale_label'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textDim,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5),
        ),
        const SizedBox(height: AppSpacing.xxl),
        GlowHalo(
          color: AppTheme.primary,
          diameter: context.isLandscape ? 130 : 200,
          haloScale: 1.6,
          intensity: 130,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withAlpha(20),
              border: Border.all(color: AppTheme.primary.withAlpha(100)),
            ),
            child: Center(
              child: Text(
                fmt,
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: context.isLandscape ? 32 : 44,
                  fontWeight: FontWeight.w200,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: L10n.get(context, 'freediving_pb_test_stop'),
          color: AppTheme.danger,
          onTap: onEnd,
        ),
      ],
    );
  }
}

class _RecoveryView extends StatelessWidget {
  const _RecoveryView({required this.remainingSeconds, required this.totalSeconds});
  final int remainingSeconds;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds == 0 ? 0.0 : 1 - (remainingSeconds / totalSeconds);
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.get(context, 'freediving_pb_test_recovery_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(context, 'freediving_pb_test_recovery_body'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                ),
              ),
              Text(
                "$minutes:${seconds.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.exhaleSec,
    required this.inhaleSec,
    required this.previousExhaleSec,
    required this.previousInhaleSec,
    required this.saved,
    required this.onSave,
    required this.nextTestDate,
    required this.nextTestTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.onScheduleNext,
    required this.onSkipSchedule,
    required this.fmtSec,
  });

  final int exhaleSec;
  final int inhaleSec;
  final int? previousExhaleSec;
  final int? previousInhaleSec;
  final bool saved;
  final Future<void> Function() onSave;
  final DateTime nextTestDate;
  final TimeOfDay nextTestTime;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onPickTime;
  final Future<void> Function() onScheduleNext;
  final VoidCallback onSkipSchedule;
  final String Function(int) fmtSec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.get(context, 'freediving_pb_test_results_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ResultRow(
          label: L10n.get(context, 'freediving_pb_test_result_exhale_label'),
          seconds: exhaleSec,
          previousSeconds: previousExhaleSec,
          color: AppTheme.accent,
          fmtSec: fmtSec,
        ),
        const SizedBox(height: AppSpacing.md),
        _ResultRow(
          label: L10n.get(context, 'freediving_pb_test_result_inhale_label'),
          seconds: inhaleSec,
          previousSeconds: previousInhaleSec,
          color: AppTheme.primary,
          fmtSec: fmtSec,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!saved)
          PrimaryButton(
            label: L10n.get(context, 'freediving_pb_test_save'),
            color: AppTheme.primary,
            onTap: () => onSave(),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(L10n.get(context, 'freediving_pb_test_saved_label'),
                  style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  L10n.get(context, 'freediving_pb_test_schedule_next_title'),
                  style: const TextStyle(
                      color: AppTheme.textLight, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  L10n.get(context, 'freediving_pb_test_schedule_next_body'),
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        label: L10n.get(context, 'freediving_pb_test_schedule_date_label'),
                        value: '${nextTestDate.day}.${nextTestDate.month}.${nextTestDate.year}',
                        onTap: () => onPickDate(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _PickerTile(
                        label: L10n.get(context, 'freediving_pb_test_schedule_time_label'),
                        value: nextTestTime.format(context),
                        onTap: () => onPickTime(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: L10n.get(context, 'freediving_pb_test_schedule_cta'),
                  color: AppTheme.primary,
                  onTap: () => onScheduleNext(),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onSkipSchedule,
                  child: Text(L10n.get(context, 'freediving_pb_test_schedule_skip'),
                      style: const TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.seconds,
    required this.previousSeconds,
    required this.color,
    required this.fmtSec,
  });

  final String label;
  final int seconds;
  final int? previousSeconds;
  final Color color;
  final String Function(int) fmtSec;

  @override
  Widget build(BuildContext context) {
    final warningKey = Co2O2TableGenerator.validatePb(seconds);
    final delta = previousSeconds == null ? null : seconds - previousSeconds!;

    return GlassCard(
      gradient: AppTheme.cardGradient(color),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmtSec(seconds),
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (previousSeconds != null)
                Text(
                  '${L10n.get(context, 'freediving_pb_test_result_previous_label')}: '
                  '${fmtSec(previousSeconds!)}',
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
              const Spacer(),
              if (delta != null && delta != 0)
                Text(
                  delta > 0 ? '+${delta}s' : '${delta}s',
                  style: TextStyle(
                    color: delta > 0 ? AppTheme.primary : AppTheme.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (warningKey != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    L10n.get(context, warningKey),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

