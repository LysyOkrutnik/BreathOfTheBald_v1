import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/formatters.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/home_shell_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  bool _rpeSubmitted = false;
  bool _symptomSubmitted = false;

  /// True once we know the just-finished session never made it into the
  /// database — `lastSessionIdFuture` resolves to null either on a genuine
  /// write failure or when there was nothing to persist in the first place.
  /// Either way, celebrating XP/streak the user didn't actually get would be
  /// a convincing lie, so this gates the RPE prompt and drives a warning
  /// banner instead.
  bool _saveFailed = false;

  static const _lastStagePrefsKey = 'training_path_last_seen_stage';

  // "Twoja Ścieżka" stage-advance celebration: compares the path's stage as
  // of this summary against the last one we ever recorded, entirely local to
  // this screen so it only needs to run once, right when a session (the only
  // thing that can move the path forward) just finished.
  PathStage? _celebratedStage;

  /// The new character level, if this session pushed XP into a new bracket —
  /// same one-shot-read lifecycle as [_celebratedStage], sourced from
  /// [SessionNotifier.justLeveledUpTo] instead of a separate provider diff.
  int? _leveledUpTo;

  /// Whether this session's streak update spent its one-day grace (a missed
  /// day forgiven rather than resetting the streak) — surfaced so a saved
  /// streak doesn't look unexplained.
  bool _streakGraceUsed = false;

  @override
  void initState() {
    super.initState();
    _resolveStageCelebration();
  }

  /// Waits for the just-finished session to actually persist (the same
  /// signal the RPE flow uses), plus a short margin for the Drift watch
  /// streams behind [trainingPathProvider] to re-emit — otherwise this would
  /// almost certainly read the *pre-session* path value (the DB write is
  /// still in flight when this screen's very first frame builds) and record
  /// it as "last seen", permanently skipping the real celebration.
  Future<void> _resolveStageCelebration() async {
    final notifier = ref.read(sessionProvider.notifier);
    final sessionId = await notifier.lastSessionIdFuture;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    if (sessionId == null) {
      setState(() => _saveFailed = true);
    } else {
      setState(() {
        _leveledUpTo = notifier.justLeveledUpTo;
        _streakGraceUsed = notifier.justUsedStreakGrace;
      });
    }

    final current = ref.read(trainingPathProvider);
    if (current == null) return;

    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_lastStagePrefsKey);
    final previous = index == null ? null : PathStage.values[index];
    await prefs.setInt(_lastStagePrefsKey, current.stage.index);
    if (!mounted) return;

    if (previous != null && current.stage.index > previous.index) {
      setState(() => _celebratedStage = current.stage);
    }
  }

  /// A guided-routine hold of fixed duration (e.g. Uddiyana's 7s vacuum,
  /// repeated identically every round by construction) logs the exact same
  /// value N times — showing N identical "Round X: 7s" chips reads as
  /// meaningless noise, or worse, like progress isn't registering. Collapse
  /// that case into a single "6 × 7s" chip; a real Wim Hof/freediving
  /// session (genuinely variable effort-driven hold times) keeps the
  /// existing per-round breakdown untouched.
  List<Widget> _retentionChips(BuildContext context, List<Duration> logs) {
    if (logs.length > 1 && logs.toSet().length == 1) {
      return [
        _RetentionChip(
          label:
              "${logs.length} ${L10n.get(context, 'summary_retention_fixed_count_suffix')} ${formatDurationMmSs(logs.first)}",
        ),
      ];
    }
    return [
      for (final e in logs.asMap().entries)
        _RetentionChip(
          label:
              "${L10n.get(context, 'summary_retention_round')} ${e.key + 1}: ${formatDurationMmSs(e.value)}",
        ),
    ];
  }

  ExerciseType? get _lastType =>
      ref.read(sessionProvider.notifier).lastFinishedExerciseType;

  FreedivingTableType? get _freedivingTableType {
    final type = _lastType;
    if (type == ExerciseType.co2Table) return FreedivingTableType.co2;
    if (type == ExerciseType.o2Table) return FreedivingTableType.o2;
    return null;
  }

  /// Broader than [_freedivingTableType]: also covers custom freediving
  /// tables and packing, which carry the same real breath-hold risks as the
  /// generated CO2/O2 tables but don't participate in RPE-driven PB
  /// adjustment (no PB to adjust) — used only to gate the symptom check-in,
  /// a pure safety signal that applies regardless.
  FreedivingTableType? get _symptomCheckInTableType {
    final direct = _freedivingTableType;
    if (direct != null) return direct;
    if (_lastType == ExerciseType.customFreedivingTable) {
      return FreedivingTableType.custom;
    }
    if (_lastType == ExerciseType.guidedRoutine &&
        ref.read(sessionProvider.notifier).lastFinishedLevelKey ==
            'freediving_packing') {
      return FreedivingTableType.packing;
    }
    return null;
  }

  // Computed synchronously at the moment the session finished (same
  // lifecycle as [_lastType]) — doesn't need to wait on the DB persist the
  // way the RPE flow does.
  RoundContractionSummary? get _contractionSummary =>
      ref.read(sessionProvider.notifier).lastFreedivingContractionSummary;

  bool get _ratesToGenericSession =>
      _lastType == ExerciseType.wimHof ||
      _lastType == ExerciseType.customFreedivingTable ||
      // Packing is structurally a single near-maximal breath hold — the
      // same category as the freediving tables it sits next to, which
      // already get an RPE prompt.
      (_lastType == ExerciseType.guidedRoutine &&
          ref.read(sessionProvider.notifier).lastFinishedLevelKey ==
              'freediving_packing');

  bool get _showRpePrompt => _freedivingTableType != null || _ratesToGenericSession;

  String get _rpeHintKey {
    if (_freedivingTableType != null) return 'freediving_rpe_hint';
    if (_lastType == ExerciseType.wimHof) return 'wimhof_rpe_hint';
    return 'session_rpe_hint';
  }

  String get _rpeThanksKey {
    if (_freedivingTableType != null) return 'freediving_rpe_thanks';
    if (_lastType == ExerciseType.wimHof) return 'wimhof_rpe_thanks';
    return 'session_rpe_thanks';
  }

  Future<void> _submitRpe(int score) async {
    final tableType = _freedivingTableType;
    if (tableType != null) {
      await ref
          .read(freedivingRepositoryProvider)
          .recordRpeAndAdjustPb(tableType: tableType, rpeScore: score);
    } else if (_ratesToGenericSession) {
      final sessionId =
          await ref.read(sessionProvider.notifier).lastSessionIdFuture;
      if (sessionId != null) {
        await ref.read(sessionRepositoryProvider).updateRpe(sessionId, score);
      }
    } else {
      return;
    }
    if (mounted) setState(() => _rpeSubmitted = true);
  }

  /// Deliberately separate from RPE (which measures perceived effort) — a
  /// recurring symptom report across sessions is a safety signal RPE alone
  /// wouldn't surface. Kept to a single tap: no follow-up questions, no
  /// requirement to answer.
  Future<void> _submitSymptom(String tag) async {
    final tableType = _symptomCheckInTableType;
    if (tableType == null) return;
    await ref
        .read(freedivingRepositoryProvider)
        .recordSymptomTag(tableType: tableType, symptomTag: tag);
    if (mounted) setState(() => _symptomSubmitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.read(sessionProvider);
    final duration = state.sessionDuration ?? Duration.zero;
    // Rating a session that was never actually saved has nothing to attach
    // the rating to — and would misleadingly suggest it went through.
    final showRpePrompt = _showRpePrompt && !_saveFailed;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 480),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Badge()
                          .animate()
                          .scale(duration: AppMotion.slow, curve: Curves.easeOutBack)
                          .fadeIn(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        L10n.get(context, 'summary_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3.0,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: AppSpacing.sm),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                              color: Colors.white.withAlpha(160), fontSize: 15),
                          children: [
                            TextSpan(text: "${L10n.get(context, 'summary_great_job')}, "),
                            TextSpan(
                              text: ref.watch(settingsProvider).profileName.isEmpty
                                  ? L10n.get(context, 'summary_okrutnik')
                                  : ref.watch(settingsProvider).profileName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            const TextSpan(text: "."),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms),
                      if (_saveFailed) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const _SaveFailedCard().animate().fadeIn(delay: 280.ms),
                      ],
                      if (_celebratedStage != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _StageAdvanceCard(stage: _celebratedStage!)
                            .animate()
                            .fadeIn(delay: 280.ms)
                            .scale(begin: const Offset(0.95, 0.95)),
                      ],
                      if (_leveledUpTo != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _LevelUpCard(level: _leveledUpTo!)
                            .animate()
                            .fadeIn(delay: 280.ms)
                            .scale(begin: const Offset(0.95, 0.95)),
                      ],
                      if (_streakGraceUsed) ...[
                        const SizedBox(height: AppSpacing.md),
                        const _StreakGraceNote().animate().fadeIn(delay: 300.ms),
                      ],
                      if (_contractionSummary != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _ContractionSummaryCard(summary: _contractionSummary!)
                            .animate()
                            .fadeIn(delay: 280.ms),
                      ],
                      if (_symptomCheckInTableType != null && !_saveFailed) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _SymptomCard(
                          submitted: _symptomSubmitted,
                          onSelect: _submitSymptom,
                        ).animate().fadeIn(delay: 290.ms),
                      ],
                      if (showRpePrompt) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _RpeCard(
                          submitted: _rpeSubmitted,
                          onSubmit: _submitRpe,
                          hint: L10n.get(context, _rpeHintKey),
                          thanks: L10n.get(context, _rpeThanksKey),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _StatRow(
                        icon: Icons.timer_outlined,
                        label: L10n.get(context, 'summary_stat_duration'),
                        value: formatDurationMmSs(duration),
                        delay: 300,
                      ),
                      if (state.totalRounds > 1) ...[
                        const SizedBox(height: AppSpacing.md),
                        _StatRow(
                          icon: Icons.all_inclusive_rounded,
                          label: L10n.get(context, 'summary_stat_rounds'),
                          value: "${state.totalRounds}",
                          delay: 380,
                        ),
                      ],
                      if (state.retentionLogs.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          L10n.get(context, 'summary_retention_times'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _retentionChips(context, state.retentionLogs),
                        ).animate().fadeIn(delay: 450.ms),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      PressableScale(
                        onTap: () => Navigator.of(context).pushAndRemoveUntil(
                          fadeThroughRoute(const HomeShellScreen()),
                          (route) => false,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            boxShadow: AppTheme.glow(AppTheme.primary, blur: 26),
                          ),
                          child: Text(
                            L10n.get(context, 'summary_back_to_menu'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpeCard extends StatefulWidget {
  const _RpeCard({
    required this.submitted,
    required this.onSubmit,
    required this.hint,
    required this.thanks,
  });
  final bool submitted;
  final ValueChanged<int> onSubmit;
  final String hint;
  final String thanks;

  @override
  State<_RpeCard> createState() => _RpeCardState();
}

class _RpeCardState extends State<_RpeCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    if (widget.submitted) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.thanks,
                style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'freediving_rpe_question'),
            style: const TextStyle(
                color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.hint,
            style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 1; i <= 10; i++)
                PressableScale(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    // Was 34x34 — below the 48dp minimum recommended touch
                    // target for a row of 10 adjacent number chips.
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selected == i
                          ? AppTheme.primary
                          : Colors.white.withAlpha(14),
                      border: Border.all(
                        color: _selected == i
                            ? AppTheme.primary
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: _selected == i ? Colors.black : AppTheme.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: _selected == null ? 0.4 : 1.0,
            child: PressableScale(
              onTap: _selected == null ? null : () => widget.onSubmit(_selected!),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  L10n.get(context, 'freediving_rpe_submit'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-tap, fully-optional post-freediving-session check-in — three
/// large chips instead of a form, so it costs the user one tap or none at
/// all. Deliberately separate from the RPE scale below it: RPE measures how
/// hard the session felt, this measures whether anything safety-relevant
/// happened during it.
class _SymptomCard extends StatelessWidget {
  const _SymptomCard({required this.submitted, required this.onSelect});
  final bool submitted;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                L10n.get(context, 'freediving_symptom_thanks'),
                style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'freediving_symptom_question'),
            style: const TextStyle(
                color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SymptomChip(
                label: L10n.get(context, 'freediving_symptom_tingling'),
                onTap: () => onSelect('tingling'),
              ),
              _SymptomChip(
                label: L10n.get(context, 'freediving_symptom_dizziness'),
                onTap: () => onSelect('dizziness'),
              ),
              _SymptomChip(
                label: L10n.get(context, 'freediving_symptom_euphoria'),
                onTap: () => onSelect('euphoria'),
              ),
              _SymptomChip(
                label: L10n.get(context, 'freediving_symptom_lmc'),
                onTap: () => onSelect('lmc'),
              ),
              _SymptomChip(
                label: L10n.get(context, 'freediving_symptom_ok'),
                onTap: () => onSelect('ok'),
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({required this.label, required this.onTap, this.highlight = false});
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.primary.withAlpha(30) : Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: highlight ? AppTheme.primary.withAlpha(140) : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: highlight ? AppTheme.primary : AppTheme.textLight,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Shown when the just-finished session never made it into the database —
/// the numbers above are real (read straight from in-memory session state),
/// but nothing was recorded: no XP, no streak, no history entry.
class _SaveFailedCard extends StatelessWidget {
  const _SaveFailedCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppTheme.cardGradient(AppTheme.danger),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, 'summary_save_failed_title'),
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10n.get(context, 'summary_save_failed_body'),
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once, right when "Twoja Ścieżka" advances to a new stage — the
/// summary screen is the one moment we know a session (the only thing that
/// can move the path forward) just finished, so it's the natural place to
/// surface this rather than a silent background change.
class _StageAdvanceCard extends StatelessWidget {
  const _StageAdvanceCard({required this.stage});
  final PathStage stage;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppTheme.cardGradient(AppTheme.accent),
      child: Row(
        children: [
          const Icon(Icons.military_tech_rounded, color: AppTheme.accent, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, 'path_stage_advanced_title'),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10n.get(context, stageTitleKey(stage)),
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once, right when a session pushes total XP into a new level
/// bracket — same card pattern as [_StageAdvanceCard], since a character
/// level-up previously had zero celebration of its own despite the exact
/// same "compare before/after, show once" plumbing already existing.
class _LevelUpCard extends StatelessWidget {
  const _LevelUpCard({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppTheme.cardGradient(AppTheme.primary),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.primary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, 'summary_level_up_title'),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${L10n.get(context, 'summary_level_up_body')} $level',
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after a freediving table with at least one marked "first
/// contraction" — a metric distinct from raw hold time: a growing gap
/// between contraction onset and total hold time is real CO2-tolerance
/// progress that the hold-time number alone doesn't show.
class _ContractionSummaryCard extends StatelessWidget {
  const _ContractionSummaryCard({required this.summary});
  final RoundContractionSummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradient: AppTheme.cardGradient(AppTheme.accent),
      child: Row(
        children: [
          const Icon(Icons.waves_rounded, color: AppTheme.accent, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, 'summary_contraction_title'),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMmSs(summary.averageFirstContractionSec)} '
                  '(${summary.roundsMarked}/${summary.totalRounds} ${L10n.get(context, 'summary_contraction_rounds')})',
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line acknowledgment that the streak survived on its one-day grace —
/// without this, a preserved streak after a missed day would just look
/// unexplained (or worse, like a bug).
class _StreakGraceNote extends StatelessWidget {
  const _StreakGraceNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, color: AppTheme.textDim.withAlpha(200), size: 14),
        const SizedBox(width: 6),
        Text(
          L10n.get(context, 'summary_streak_grace_note'),
          style: TextStyle(color: AppTheme.textDim.withAlpha(200), fontSize: 11),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlowHalo(
        color: AppTheme.primary,
        diameter: 108,
        haloScale: 1.9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withAlpha(24),
            border: Border.all(color: AppTheme.primary.withAlpha(90)),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: AppTheme.primary, size: 56),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.delay,
  });

  final IconData icon;
  final String label;
  final String value;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 26),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white54, letterSpacing: 1.5, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.08);
  }
}

class _RetentionChip extends StatelessWidget {
  const _RetentionChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}
