import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';

enum Difficulty { mild, strong, beast, guru }

enum ExerciseType {
  wimHof,
  boxBreathing,
  relax478,
  fireBreathing,
  custom,
  co2Table,
  o2Table,
  customFreedivingTable,
  coldShower,
  /// Lung-mobility/diaphragm exercises (chest stretch, Uddiyana Bandha,
  /// resisted breathing, three-part breath) and packing — a sequence of
  /// [GuidedStep]s run by [LevelData.guidedSteps], repeated for
  /// [LevelData.totalRounds]. See SessionNotifier._startGuidedRoutine.
  guidedRoutine,
}

/// Which existing [SessionPhase] a [GuidedStep] displays as. `breath` reuses
/// the normal orb-pulse visual (inhale/exhale/rep); `hold` shows a live
/// countdown (same visual language as freediving's rest/pause) — never
/// `retention`, since that phase's tap-to-abort gesture and freediving
/// contraction marker don't apply to a fixed-duration technique step.
enum GuidedStepPhase { breath, hold }

/// One step of a guided lung-mobility/packing routine — pure data, run by a
/// single generic engine (SessionNotifier._startGuidedRoutine) instead of a
/// bespoke method per exercise.
class GuidedStep {
  const GuidedStep({
    required this.labelKey,
    required this.durationSec,
    required this.phase,
    this.isInhale,
    this.recordAsRetention = false,
    this.cycleStepIndex,
    this.skipOnFinalRound = false,
  });

  final String labelKey;
  final int durationSec;
  final GuidedStepPhase phase;

  /// Skips this step only on the exercise's last round — for a rest that
  /// belongs *between* rounds (resisted_breathing's inter-set rest) rather
  /// than after every single one, including the last, which is what a
  /// plain per-round repeat would otherwise produce.
  final bool skipOnFinalRound;

  /// Only meaningful for [GuidedStepPhase.breath] steps — drives the orb's
  /// pulse direction. Null for a plain repetition cue with no clear
  /// inhale/exhale (e.g. a packing "gulp").
  final bool? isInhale;

  /// Only meaningful for [GuidedStepPhase.hold] steps — logs this hold's
  /// duration into the session's `retentionLogs`, so the *one* hold that
  /// actually defines the exercise (Uddiyana's vacuum, packing's final hold)
  /// shows up in the summary screen's existing "Czasy wstrzymań" chips,
  /// reusing that UI instead of a bespoke one. Left false for short,
  /// incidental holds (a "return to center" pause, a rest beat) that would
  /// just clutter that list with numbers nobody cares to see afterwards.
  final bool recordAsRetention;

  /// Which node of [LevelData.cycleSteps] this engine step corresponds to,
  /// for the live cycle diagram — null for a step with no diagram node of
  /// its own (e.g. a mid-set rest break), in which case the diagram keeps
  /// showing whichever node was last active rather than losing the
  /// highlight. Several consecutive steps can share the same index (e.g.
  /// packing's 12 individual "gulp" steps all collapse into one "×12" node).
  final int? cycleStepIndex;
}

/// One node of a live "cycle diagram" — every step of a single repeating
/// cycle of an exercise (e.g. inhale->hold->exhale->hold for box breathing),
/// shown as a box in `session_screen.dart`'s diagram with the currently
/// active one highlighted. Deliberately separate from [GuidedStep]/the
/// per-phase duration fields: those drive the session engine, this only
/// drives what the diagram displays, which isn't always a 1:1 mirror (e.g.
/// packing's 12 "gulp" engine steps collapse into a single node here).
class CycleStep {
  const CycleStep({required this.labelKey, this.durationSec, this.countLabel});

  final String labelKey;

  /// Shown as "Ns" on the node. Null for an open-ended phase with no fixed
  /// length (e.g. Wim Hof's retention, which lasts until the user taps).
  final int? durationSec;

  /// Shown instead of a duration for a node that collapses several repeated
  /// engine steps into one (e.g. "×12" for packing's gulps).
  final String? countLabel;
}

/// The gulp ("top-up") count to build a packing session with, given how many
/// packing sessions the user has already completed — GPB/PFI-style
/// instruction starts at 2-4 gulps and builds up gradually, rather than
/// throwing 12 at a first-timer the way the old fixed count did.
int packingGulpCountFor(int completedSessions) {
  if (completedSessions < 3) return 4;
  if (completedSessions < 7) return 8;
  return 12;
}

/// Best-effort length of a session, in seconds, for the exercise types with
/// a real static [LevelData] entry — consolidates formulas that used to
/// live only inline in level_grid.dart's card description (box/relax/fire/
/// guidedRoutine) and custom_builder_screen.dart's own preview (custom),
/// now shared with the calendar's duration/overlap estimate. Wim Hof has no
/// exact answer — the retention itself is open-ended, ended by the user's
/// own tap — so it uses a documented, deliberately rough per-round guess
/// for the hold on top of the two components that *are* exactly known
/// (the breathing phase, the fixed recovery).
///
/// Freediving tables (co2Table/o2Table) aren't handled here — they need a
/// live PB to generate a real schedule, so a caller with access to that
/// (see [FreedivingRepository.effectivePb]) should compute theirs directly
/// via [Co2O2TableGenerator] instead. Test PB and cold shower are likewise
/// open-ended/user-timed and have no LevelData entry at all to build this
/// estimate from.
int estimatedDurationSecForLevel(LevelData level) {
  // Both keyed onto an existing ExerciseType purely so they can flow
  // through generic level-based screens (IntroScreen etc.) — neither is
  // actually that type, so each needs its own estimate before falling into
  // the type-based switch below, which would otherwise misclassify them
  // (freediving_pb_test's LevelData entry uses ExerciseType.co2Table as a
  // borrowed placeholder, which the switch would otherwise read as a real,
  // fixed-schedule CO2 table and return 0 for).
  if (level.key == 'freediving_pb_test') {
    return 5 * 60; // Genuinely open-ended (a max-effort hold) — rough guess.
  }
  if (level.key == 'cold_shower') {
    return 60; // No fixed session shape either — rough default.
  }

  switch (level.type) {
    case ExerciseType.wimHof:
      const avgRetentionGuessSec = 60;
      const recoverySec = 15;
      final breathingSec = (level.totalBreaths * level.breathPace.inMilliseconds / 1000).round();
      return level.totalRounds * (breathingSec + avgRetentionGuessSec + recoverySec);
    case ExerciseType.custom:
      return (level.inhaleSec + level.holdInSec + level.exhaleSec + level.holdOutSec) *
          (level.loopCount ?? 0) *
          level.totalRounds;
    case ExerciseType.boxBreathing:
      return (level.loopCount ?? 16) * 4 * 4;
    case ExerciseType.relax478:
      return (level.loopCount ?? 8) * 19;
    case ExerciseType.fireBreathing:
      return (level.totalDuration ?? const Duration(seconds: 207)).inSeconds;
    case ExerciseType.guidedRoutine:
      final perRound =
          (level.guidedSteps ?? const []).fold<int>(0, (sum, step) => sum + step.durationSec);
      return perRound * (level.totalRounds > 0 ? level.totalRounds : 1);
    case ExerciseType.co2Table:
    case ExerciseType.o2Table:
    case ExerciseType.customFreedivingTable:
    case ExerciseType.coldShower:
      return 0;
  }
}

extension ExerciseTypeX on ExerciseType {
  /// True for any freediving breath-hold table — CO2/O2 (PB-driven) or a
  /// user-defined custom table — all of which run through the same
  /// warm-up/hold/rest session engine.
  bool get isFreedivingTable =>
      this == ExerciseType.co2Table ||
      this == ExerciseType.o2Table ||
      this == ExerciseType.customFreedivingTable;
}

class LevelData {
  final String title;
  final String subtitle;
  final ExerciseType type;
  final String key;

  // Parameters specific to the Wim Hof method.
  final int totalRounds;
  final int totalBreaths;
  final Duration breathPace;

  // Parameters for loop-based or time-boxed exercises.
  final int? loopCount;
  final Duration? totalDuration;

  // Per-phase durations (seconds) for custom user-defined patterns. A phase
  // with 0 seconds is skipped.
  final int inhaleSec;
  final int holdInSec;
  final int exhaleSec;
  final int holdOutSec;

  /// The exact per-round schedule for a CO2/O2 freediving table. Null for
  /// every other exercise type.
  final List<BreathHoldRound>? freedivingRounds;

  /// The PB (seconds) this freediving table was generated from — persisted
  /// alongside the session log for history/audit.
  final int? freedivingPbUsedSec;

  /// The step sequence for a [ExerciseType.guidedRoutine] exercise — run
  /// once per round ([totalRounds] rounds total). Null for every other type.
  final List<GuidedStep>? guidedSteps;

  /// The live cycle-diagram definition for this exercise — every node of
  /// one repeating cycle, shown as boxes+arrows in `session_screen.dart`
  /// with the current one highlighted. Null for exercise types with no
  /// single repeating cycle to diagram (freediving tables/PB test are a
  /// table of changing rounds, not a fixed cycle — they keep their existing
  /// round-list preview instead).
  final List<CycleStep>? cycleSteps;

  // UI presentation mapping.
  final Color color;
  final String instructionTitleKey;
  final String instructionDescriptionKey;
  final List<String> instructionStepKeys;

  /// A highlighted, danger-styled banner shown on IntroScreen right below
  /// the step list — for the handful of exercises whose real risk (blackout,
  /// a specific medical contraindication) is easy to skim past as just
  /// another bullet in the numbered steps above. Null shows no banner.
  final String? introWarningKey;

  const LevelData({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.key,
    this.totalRounds = 0,
    this.totalBreaths = 0,
    this.breathPace = Duration.zero,
    this.loopCount,
    this.totalDuration,
    this.inhaleSec = 0,
    this.holdInSec = 0,
    this.exhaleSec = 0,
    this.holdOutSec = 0,
    this.freedivingRounds,
    this.freedivingPbUsedSec,
    this.guidedSteps,
    this.cycleSteps,
    required this.color,
    required this.instructionTitleKey,
    required this.instructionDescriptionKey,
    required this.instructionStepKeys,
    this.introWarningKey,
  });

  /// Builds a runtime [LevelData] for a user-defined custom pattern. [cycles]
  /// is the number of breaths per round; [rounds] the number of rounds.
  factory LevelData.custom({
    required String name,
    required int inhaleSec,
    required int holdInSec,
    required int exhaleSec,
    required int holdOutSec,
    required int cycles,
    required int rounds,
    Color color = const Color(0xFF4DD0E1),
  }) {
    return LevelData(
      key: 'custom',
      title: name,
      subtitle: '',
      type: ExerciseType.custom,
      totalRounds: rounds,
      totalBreaths: cycles,
      loopCount: cycles,
      inhaleSec: inhaleSec,
      holdInSec: holdInSec,
      exhaleSec: exhaleSec,
      holdOutSec: holdOutSec,
      // Skips zero-duration phases, same rule SessionNotifier._customPhase
      // itself uses to skip running them — kept in sync there via
      // `_startCustom`'s own parallel skip-and-index logic.
      cycleSteps: [
        if (inhaleSec > 0) CycleStep(labelKey: "session_inhale", durationSec: inhaleSec),
        if (holdInSec > 0) CycleStep(labelKey: "session_hold", durationSec: holdInSec),
        if (exhaleSec > 0) CycleStep(labelKey: "session_exhale", durationSec: exhaleSec),
        if (holdOutSec > 0) CycleStep(labelKey: "session_hold", durationSec: holdOutSec),
      ],
      color: color,
      instructionTitleKey: name,
      instructionDescriptionKey: '',
      instructionStepKeys: const [],
    );
  }

  /// Builds a runtime [LevelData] for a user-defined breath-hold table (fixed
  /// apnea/rest schedule, not derived from PB — see CustomFreedivingPreset).
  factory LevelData.customFreedivingTable({
    required String name,
    required List<BreathHoldRound> rounds,
  }) {
    const color = Color(0xFF9575CD);
    return LevelData(
      key: 'custom_freediving',
      title: name,
      subtitle: '',
      type: ExerciseType.customFreedivingTable,
      totalRounds: rounds.length,
      freedivingRounds: rounds,
      color: color,
      instructionTitleKey: name,
      instructionDescriptionKey: '',
      instructionStepKeys: const [],
    );
  }

  /// Builds packing with a specific gulp ("top-up") count, instead of the
  /// static `levels['freediving_packing']` entry's fixed 12 — GPB/PFI-style
  /// packing instruction starts at 2-4 gulps and builds up over weeks, not
  /// 12 from someone's very first session. The caller (freediving_home_
  /// screen.dart) picks [gulpCount] from the user's own packing session
  /// history; `levels['freediving_packing']` stays as a static fallback for
  /// contexts that only need the level's metadata (filtering, stats
  /// grouping), not an actual session to run.
  factory LevelData.packing({required int gulpCount}) {
    final gulp = List.generate(
      gulpCount,
      (_) => const GuidedStep(
          labelKey: "guided_packing_gulp",
          durationSec: 1,
          phase: GuidedStepPhase.breath,
          isInhale: true,
          cycleStepIndex: 1),
    );
    return LevelData(
      key: 'freediving_packing',
      title: "exercise_packing_title",
      subtitle: "exercise_packing_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 1,
      color: const Color(0xFFEF5350),
      instructionTitleKey: "exercise_packing_title",
      instructionDescriptionKey: "exercise_packing_subtitle",
      instructionStepKeys: const [
        "guide_packing_step1",
        "guide_packing_step2",
        "guide_packing_step3",
        "guide_packing_step4",
        "guide_packing_step5",
      ],
      cycleSteps: [
        const CycleStep(labelKey: "guided_packing_full_inhale", durationSec: 3),
        CycleStep(labelKey: "guided_packing_gulp", countLabel: "×$gulpCount"),
        const CycleStep(labelKey: "guided_packing_hold", durationSec: 10),
        const CycleStep(labelKey: "guided_packing_exhale", durationSec: 4),
      ],
      guidedSteps: [
        const GuidedStep(labelKey: "guided_packing_full_inhale", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 0),
        ...gulp,
        const GuidedStep(labelKey: "guided_packing_hold", durationSec: 10, phase: GuidedStepPhase.hold, recordAsRetention: true, cycleStepIndex: 2),
        const GuidedStep(labelKey: "guided_packing_exhale", durationSec: 4, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 3),
      ],
    );
  }

  /// Builds a runtime [LevelData] for a CO2 or O2 breath-hold table, generated
  /// from the user's current working PB. [pbSeconds] should be the caller's
  /// virtual PB for that table type (see FreedivingProfile).
  factory LevelData.freedivingTable({
    required FreedivingTableType tableType,
    required int pbSeconds,
    int rounds = Co2O2TableGenerator.defaultRounds,
  }) {
    final isCo2 = tableType == FreedivingTableType.co2;
    final generatedRounds = isCo2
        ? Co2O2TableGenerator.generateCo2Table(pbSeconds, rounds: rounds)
        : Co2O2TableGenerator.generateO2Table(pbSeconds, rounds: rounds);

    return LevelData(
      key: isCo2 ? 'freediving_co2' : 'freediving_o2',
      title: isCo2 ? 'freediving_co2_title' : 'freediving_o2_title',
      subtitle: isCo2 ? 'freediving_co2_subtitle' : 'freediving_o2_subtitle',
      type: isCo2 ? ExerciseType.co2Table : ExerciseType.o2Table,
      totalRounds: rounds,
      freedivingRounds: generatedRounds,
      freedivingPbUsedSec: pbSeconds,
      color: isCo2 ? const Color(0xFF4FC3F7) : const Color(0xFFFF7043),
      instructionTitleKey:
          isCo2 ? 'freediving_co2_title' : 'freediving_o2_title',
      instructionDescriptionKey:
          isCo2 ? 'freediving_co2_desc' : 'freediving_o2_desc',
      instructionStepKeys: isCo2
          ? const [
              'freediving_co2_step1',
              'freediving_co2_step2',
              'freediving_co2_step3',
            ]
          : const [
              'freediving_o2_step1',
              'freediving_o2_step2',
              'freediving_o2_step3',
            ],
    );
  }

  static const Map<String, LevelData> levels = {
    // --- WIM HOF ---
    'mild': LevelData(
      key: 'mild',
      title: "level_novice",
      subtitle: "pace_calm",
      type: ExerciseType.wimHof,
      totalRounds: 3,
      totalBreaths: 30,
      breathPace: Duration(milliseconds: 3000),
      cycleSteps: [
        CycleStep(labelKey: "session_breathing_phase", countLabel: "×30"),
        CycleStep(labelKey: "session_hold"),
        CycleStep(labelKey: "session_recovery", durationSec: 15),
      ],
      color: Color(0xFF4DB6AC),
      instructionTitleKey: "intro_title_mild",
      instructionDescriptionKey: "intro_desc_mild",
      instructionStepKeys: [
        "intro_steps_mild_1",
        "intro_steps_mild_2",
        "intro_steps_mild_3",
        "intro_steps_mild_4",
        "intro_steps_mild_5",
        "intro_steps_mild_6",
      ],
    ),
    'strong': LevelData(
      key: 'strong',
      title: "level_warrior",
      subtitle: "pace_power",
      type: ExerciseType.wimHof,
      totalRounds: 3,
      totalBreaths: 40,
      breathPace: Duration(milliseconds: 2500),
      cycleSteps: [
        CycleStep(labelKey: "session_breathing_phase", countLabel: "×40"),
        CycleStep(labelKey: "session_hold"),
        CycleStep(labelKey: "session_recovery", durationSec: 15),
      ],
      color: Color(0xFF81C784),
      instructionTitleKey: "intro_title_strong",
      instructionDescriptionKey: "intro_desc_strong",
      instructionStepKeys: [
        "intro_steps_strong_1",
        "intro_steps_strong_2",
        "intro_steps_strong_3",
        "intro_steps_strong_4",
        "intro_steps_strong_5",
        "intro_steps_strong_6",
      ],
    ),
    'beast': LevelData(
      key: 'beast',
      title: "level_beast",
      subtitle: "pace_fire",
      type: ExerciseType.wimHof,
      totalRounds: 4,
      totalBreaths: 50,
      // 2000ms gave beast the exact same per-round breathing-phase duration
      // as strong (40*2500ms == 50*2000ms == 100s) — the entire difficulty
      // step between them was just +1 round, with no distinct pace signature
      // of its own. 2100ms keeps beast's pace strictly between strong's
      // 2500ms and guru's 1800ms (as before) while also putting its
      // per-round time (105s) strictly between strong's 100s and guru's
      // 108s, so both dimensions of the ladder now increase monotonically.
      breathPace: Duration(milliseconds: 2100),
      cycleSteps: [
        CycleStep(labelKey: "session_breathing_phase", countLabel: "×50"),
        CycleStep(labelKey: "session_hold"),
        CycleStep(labelKey: "session_recovery", durationSec: 15),
      ],
      color: Color(0xFFFFB74D),
      instructionTitleKey: "intro_title_beast",
      instructionDescriptionKey: "intro_desc_beast",
      instructionStepKeys: [
        "intro_steps_beast_1",
        "intro_steps_beast_2",
        "intro_steps_beast_3",
        "intro_steps_beast_4",
        "intro_steps_beast_5",
        "intro_steps_beast_6",
      ],
    ),
    'guru': LevelData(
      key: 'guru',
      title: "level_okrutnik",
      subtitle: "pace_extreme",
      type: ExerciseType.wimHof,
      totalRounds: 5,
      totalBreaths: 60,
      breathPace: Duration(milliseconds: 1800),
      cycleSteps: [
        CycleStep(labelKey: "session_breathing_phase", countLabel: "×60"),
        CycleStep(labelKey: "session_hold"),
        CycleStep(labelKey: "session_recovery", durationSec: 15),
      ],
      color: Color(0xFFE57373),
      instructionTitleKey: "intro_title_guru",
      instructionDescriptionKey: "intro_desc_guru",
      instructionStepKeys: [
        "intro_steps_guru_1",
        "intro_steps_guru_2",
        "intro_steps_guru_contraindications",
        "intro_steps_guru_3",
        "intro_steps_guru_4",
        "intro_steps_guru_recovery",
        "intro_steps_guru_5",
      ],
      introWarningKey: "warning_guru",
    ),

    // --- AUTOMATED EXERCISES ---
    // Sessions that run automatically without user input.
    'box': LevelData(
      key: 'box',
      title: "level_sniper",
      subtitle: "desc_focus",
      type: ExerciseType.boxBreathing,
      loopCount: 16,
      cycleSteps: [
        CycleStep(labelKey: "session_inhale", durationSec: 4),
        CycleStep(labelKey: "session_hold", durationSec: 4),
        CycleStep(labelKey: "session_exhale", durationSec: 4),
        CycleStep(labelKey: "session_hold", durationSec: 4),
      ],
      color: Color(0xFF5C6BC0),
      instructionTitleKey: "intro_title_box",
      instructionDescriptionKey: "intro_desc_box",
      instructionStepKeys: [
        "intro_steps_box_1",
        "intro_steps_box_2",
        "intro_steps_box_3",
        "intro_steps_box_4",
        "intro_steps_box_5",
        "intro_steps_box_6",
        "intro_steps_box_7",
      ],
    ),
    'relax': LevelData(
      key: 'relax',
      title: "level_relax",
      subtitle: "desc_sleep",
      type: ExerciseType.relax478,
      // Dr. Weil's own protocol caps a session at 8 cycles (starting most
      // people at 4) — 4-7-8's long breath-hold phase makes it a genuine
      // hyperventilation/hypoventilation technique, not something to just
      // repeat as many times as fits a "10-minute session" (the previous
      // loopCount of 32 was 4x that ceiling).
      loopCount: 8,
      cycleSteps: [
        CycleStep(labelKey: "session_inhale", durationSec: 4),
        CycleStep(labelKey: "session_hold", durationSec: 7),
        CycleStep(labelKey: "session_exhale", durationSec: 8),
      ],
      color: Color(0xFFBA68C8),
      instructionTitleKey: "intro_title_relax",
      instructionDescriptionKey: "intro_desc_relax",
      instructionStepKeys: [
        "intro_steps_relax_1",
        "intro_steps_relax_2",
        "intro_steps_relax_3",
        "intro_steps_relax_4",
        "intro_steps_relax_5",
        "intro_steps_relax_6",
      ],
    ),
    'fire': LevelData(
      key: 'fire',
      title: "level_bhastrika",
      subtitle: "desc_fire",
      type: ExerciseType.fireBreathing,
      // Used to be one uninterrupted 3-minute block of rapid breathing —
      // no rounds, no hold, no rest, unlike the classic Kapalabhati/
      // Bhastrika pattern (a short series of fast breaths, then a full
      // inhale, a hold, an exhale, a rest, repeated). That meant a much
      // longer uninterrupted hyperventilation exposure than the technique's
      // own reference pattern, and no natural point to reassess before
      // continuing. totalBreaths/breathPace here mean the same thing they
      // do for Wim Hof: breaths per round and per-breath cadence.
      totalRounds: 3,
      totalBreaths: 30,
      breathPace: Duration(milliseconds: 1400),
      // 3 * (30*1.4s fast breathing + 3s inhale + 12s hold + 2s exhale) +
      // 2 * 15s rest between rounds = 207s.
      totalDuration: Duration(seconds: 207),
      cycleSteps: [
        CycleStep(labelKey: "session_breathing_phase", countLabel: "×30"),
        CycleStep(labelKey: "session_inhale", durationSec: 3),
        CycleStep(labelKey: "session_hold", durationSec: 12),
        CycleStep(labelKey: "session_exhale", durationSec: 2),
        CycleStep(labelKey: "session_recovery", durationSec: 15),
      ],
      color: AppTheme.danger,
      instructionTitleKey: "intro_title_fire",
      instructionDescriptionKey: "intro_desc_fire",
      instructionStepKeys: [
        "intro_steps_fire_1",
        "intro_steps_fire_2",
        "intro_steps_fire_3",
        "intro_steps_fire_4",
        "intro_steps_fire_5",
        "intro_steps_fire_6",
      ],
      introWarningKey: "warning_fire_breath",
    ),

    // --- FREEDIVING (display/lookup only) ---
    // These two entries exist so History/Stats can resolve a name, color and
    // icon for past sessions via LevelData.levels[session.levelKey]. A real
    // session is never started from these static entries — it is always
    // built fresh by LevelData.freedivingTable(...) using the user's current
    // working PB, since the round schedule depends on that live value.
    'freediving_co2': LevelData(
      key: 'freediving_co2',
      title: "freediving_co2_title",
      subtitle: "freediving_co2_subtitle",
      type: ExerciseType.co2Table,
      color: Color(0xFF4FC3F7),
      instructionTitleKey: "freediving_co2_title",
      instructionDescriptionKey: "freediving_co2_desc",
      instructionStepKeys: [],
    ),
    'freediving_o2': LevelData(
      key: 'freediving_o2',
      title: "freediving_o2_title",
      subtitle: "freediving_o2_subtitle",
      type: ExerciseType.o2Table,
      color: Color(0xFFFF7043),
      instructionTitleKey: "freediving_o2_title",
      instructionDescriptionKey: "freediving_o2_desc",
      instructionStepKeys: [],
    ),
    'freediving_pb_test': LevelData(
      key: 'freediving_pb_test',
      title: "freediving_pb_test_title",
      subtitle: "freediving_pb_test_title",
      type: ExerciseType.co2Table,
      color: Color(0xFF81C784),
      instructionTitleKey: "freediving_pb_test_title",
      instructionDescriptionKey: "freediving_pb_test_intro",
      instructionStepKeys: [],
    ),
    'cold_shower': LevelData(
      key: 'cold_shower',
      title: "coldshower_title",
      subtitle: "coldshower_title",
      type: ExerciseType.coldShower,
      color: Color(0xFF80D8FF),
      instructionTitleKey: "coldshower_title",
      instructionDescriptionKey: "coldshower_title",
      instructionStepKeys: [],
    ),

    // --- LUNG MOBILITY / DIAPHRAGM (guidedRoutine) ---
    'stretch_chest': LevelData(
      key: 'stretch_chest',
      title: "exercise_stretch_chest_title",
      subtitle: "exercise_stretch_chest_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 3,
      color: Color(0xFF26A69A),
      instructionTitleKey: "exercise_stretch_chest_title",
      instructionDescriptionKey: "exercise_stretch_chest_subtitle",
      instructionStepKeys: [
        "guide_stretch_chest_step1",
        "guide_stretch_chest_step2",
        "guide_stretch_chest_step3",
        "guide_stretch_chest_step4",
      ],
      guidedSteps: [
        GuidedStep(labelKey: "guided_stretch_right", durationSec: 25, phase: GuidedStepPhase.hold, cycleStepIndex: 0),
        GuidedStep(labelKey: "guided_stretch_return", durationSec: 4, phase: GuidedStepPhase.hold, cycleStepIndex: 1),
        GuidedStep(labelKey: "guided_stretch_left", durationSec: 25, phase: GuidedStepPhase.hold, cycleStepIndex: 2),
        GuidedStep(labelKey: "guided_stretch_return", durationSec: 4, phase: GuidedStepPhase.hold, cycleStepIndex: 3),
      ],
      cycleSteps: [
        CycleStep(labelKey: "guided_stretch_right", durationSec: 25),
        CycleStep(labelKey: "guided_stretch_return", durationSec: 4),
        CycleStep(labelKey: "guided_stretch_left", durationSec: 25),
        CycleStep(labelKey: "guided_stretch_return", durationSec: 4),
      ],
    ),
    'uddiyana_bandha': LevelData(
      key: 'uddiyana_bandha',
      title: "exercise_uddiyana_title",
      subtitle: "exercise_uddiyana_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 6,
      color: Color(0xFF7E57C2),
      instructionTitleKey: "exercise_uddiyana_title",
      instructionDescriptionKey: "exercise_uddiyana_subtitle",
      instructionStepKeys: [
        "guide_uddiyana_step1",
        "guide_uddiyana_step2",
        "guide_uddiyana_step3",
        "guide_uddiyana_step4",
        "guide_uddiyana_step5",
      ],
      introWarningKey: "warning_uddiyana",
      guidedSteps: [
        GuidedStep(labelKey: "guided_uddiyana_inhale", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 0),
        GuidedStep(labelKey: "guided_uddiyana_exhale", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 1),
        GuidedStep(labelKey: "guided_uddiyana_hold", durationSec: 7, phase: GuidedStepPhase.hold, recordAsRetention: true, cycleStepIndex: 2),
        GuidedStep(labelKey: "guided_uddiyana_rest", durationSec: 8, phase: GuidedStepPhase.hold, cycleStepIndex: 3),
      ],
      cycleSteps: [
        CycleStep(labelKey: "guided_uddiyana_inhale", durationSec: 3),
        CycleStep(labelKey: "guided_uddiyana_exhale", durationSec: 3),
        CycleStep(labelKey: "guided_uddiyana_hold", durationSec: 7),
        CycleStep(labelKey: "guided_uddiyana_rest", durationSec: 8),
      ],
    ),
    'resisted_breathing': LevelData(
      key: 'resisted_breathing',
      title: "exercise_resisted_breathing_title",
      subtitle: "exercise_resisted_breathing_subtitle",
      type: ExerciseType.guidedRoutine,
      // 45 breaths (3 sets of 15) exceeded the clinical IMST protocol this
      // technique is modeled on (Craighead 2021 and similar: 30 breaths/day)
      // — reduced to 2 real rounds of 15 (30 total), now using
      // `skipOnFinalRound` so the trailing rest only shows *between* the
      // two rounds, not after the last one. This also fixes a real UX
      // regression the old flattened-single-round encoding caused: with
      // `totalRounds` always 1, the "Runda x/y" indicator was permanently
      // hidden for this exercise even though it's fundamentally set-based.
      totalRounds: 2,
      color: Color(0xFF42A5F5),
      instructionTitleKey: "exercise_resisted_breathing_title",
      instructionDescriptionKey: "exercise_resisted_breathing_subtitle",
      instructionStepKeys: [
        "guide_resisted_breathing_step1",
        "guide_resisted_breathing_step2",
        "guide_resisted_breathing_step3",
        "guide_resisted_breathing_step4",
      ],
      // The cycle diagram shows just the repeating inhale/exhale pair, not
      // the inter-set rest (which has no cycleStepIndex of its own).
      cycleSteps: [
        CycleStep(labelKey: "guided_resisted_inhale", durationSec: 2),
        CycleStep(labelKey: "guided_resisted_exhale", durationSec: 2),
      ],
      guidedSteps: [
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        GuidedStep(labelKey: "guided_resisted_rest", durationSec: 50, phase: GuidedStepPhase.hold, skipOnFinalRound: true),
      ],
    ),
    'three_part_breath': LevelData(
      key: 'three_part_breath',
      title: "exercise_three_part_breath_title",
      subtitle: "exercise_three_part_breath_subtitle",
      type: ExerciseType.guidedRoutine,
      // 2s/phase (16s/round * 9) was too fast to actually notice the
      // transition between the three breathing zones — the whole point of
      // this technique — despite the instructions promising exactly that.
      // 3s/phase gives each zone room to register; totalRounds trimmed from
      // 9 to 7 to keep the overall session length about the same (24s/round
      // * 7 = 168s vs the old 144s — close enough, not worth chasing exact
      // parity at the cost of a worse per-phase pace).
      totalRounds: 7,
      color: Color(0xFF66BB6A),
      instructionTitleKey: "exercise_three_part_breath_title",
      instructionDescriptionKey: "exercise_three_part_breath_subtitle",
      instructionStepKeys: [
        "guide_three_part_breath_step1",
        "guide_three_part_breath_step2",
        "guide_three_part_breath_step3",
        "guide_three_part_breath_step4",
      ],
      guidedSteps: [
        GuidedStep(labelKey: "guided_threepart_belly_in", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 0),
        GuidedStep(labelKey: "guided_threepart_ribs_in", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 1),
        GuidedStep(labelKey: "guided_threepart_chest_in", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 2),
        GuidedStep(labelKey: "guided_threepart_hold_full", durationSec: 3, phase: GuidedStepPhase.hold, cycleStepIndex: 3),
        GuidedStep(labelKey: "guided_threepart_chest_out", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 4),
        GuidedStep(labelKey: "guided_threepart_ribs_out", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 5),
        GuidedStep(labelKey: "guided_threepart_belly_out", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 6),
        GuidedStep(labelKey: "guided_threepart_hold_empty", durationSec: 3, phase: GuidedStepPhase.hold, cycleStepIndex: 7),
      ],
      cycleSteps: [
        CycleStep(labelKey: "guided_threepart_belly_in", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_ribs_in", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_chest_in", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_hold_full", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_chest_out", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_ribs_out", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_belly_out", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_hold_empty", durationSec: 3),
      ],
    ),
    // A holds-free variant of the same technique — the traditional Dirga
    // Pranayama is a purely relaxational, flowing three-zone breath with no
    // kumbhaka at all; three_part_breath above adds brief holds as a
    // deliberate variant, but that's a step up from the classic form, not
    // the form itself. This gives back the original, gentler version
    // instead of only offering the version with holds.
    'three_part_breath_gentle': LevelData(
      key: 'three_part_breath_gentle',
      title: "exercise_three_part_breath_gentle_title",
      subtitle: "exercise_three_part_breath_gentle_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 7,
      color: Color(0xFF9CCC65),
      instructionTitleKey: "exercise_three_part_breath_gentle_title",
      instructionDescriptionKey: "exercise_three_part_breath_gentle_subtitle",
      instructionStepKeys: [
        "guide_three_part_breath_step1",
        "guide_three_part_breath_step2",
        "guide_three_part_breath_gentle_step3",
        "guide_three_part_breath_step4",
      ],
      guidedSteps: [
        GuidedStep(labelKey: "guided_threepart_belly_in", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 0),
        GuidedStep(labelKey: "guided_threepart_ribs_in", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 1),
        GuidedStep(labelKey: "guided_threepart_chest_in", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 2),
        GuidedStep(labelKey: "guided_threepart_chest_out", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 3),
        GuidedStep(labelKey: "guided_threepart_ribs_out", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 4),
        GuidedStep(labelKey: "guided_threepart_belly_out", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 5),
      ],
      cycleSteps: [
        CycleStep(labelKey: "guided_threepart_belly_in", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_ribs_in", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_chest_in", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_chest_out", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_ribs_out", durationSec: 3),
        CycleStep(labelKey: "guided_threepart_belly_out", durationSec: 3),
      ],
    ),
    // Freediving-specific — surfaced from the Freediving section (already
    // gated behind its safety consent), not the general Mobilność list. A
    // one-time warning dialog (real risks: barotrauma, gas embolism,
    // blackout) shows before its first use — see freediving_home_screen.dart.
    'freediving_packing': LevelData(
      key: 'freediving_packing',
      title: "exercise_packing_title",
      subtitle: "exercise_packing_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 1,
      color: Color(0xFFEF5350),
      instructionTitleKey: "exercise_packing_title",
      instructionDescriptionKey: "exercise_packing_subtitle",
      instructionStepKeys: [
        "guide_packing_step1",
        "guide_packing_step2",
        "guide_packing_step3",
        "guide_packing_step4",
        "guide_packing_step5",
      ],
      // The 12 individual "gulp" engine steps below all collapse into one
      // "×12" diagram node (index 1) — showing 12 separate boxes for a
      // single top-up motion repeated in place would be absurd.
      cycleSteps: [
        CycleStep(labelKey: "guided_packing_full_inhale", durationSec: 3),
        CycleStep(labelKey: "guided_packing_gulp", countLabel: "×12"),
        CycleStep(labelKey: "guided_packing_hold", durationSec: 10),
        CycleStep(labelKey: "guided_packing_exhale", durationSec: 4),
      ],
      guidedSteps: [
        GuidedStep(labelKey: "guided_packing_full_inhale", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 0),
        ..._packingGulps,
        GuidedStep(labelKey: "guided_packing_hold", durationSec: 10, phase: GuidedStepPhase.hold, recordAsRetention: true, cycleStepIndex: 2),
        GuidedStep(labelKey: "guided_packing_exhale", durationSec: 4, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 3),
      ],
    ),
  };

  /// One inhale+exhale rep, spread 15× into resisted_breathing's step list —
  /// a plain `for`-generated list can't be used inside this `const` map, so
  /// the repetition is a `...` spread of a single const rep instead.
  static const _resistedBreathingReps = [
    GuidedStep(labelKey: "guided_resisted_inhale", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 0),
    GuidedStep(labelKey: "guided_resisted_exhale", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: false, cycleStepIndex: 1),
  ];

  /// One small "top-up" inhale, spread 12× into freediving_packing's step
  /// list — same const-context reasoning as [_resistedBreathingReps].
  static const _packingGulp = [
    GuidedStep(labelKey: "guided_packing_gulp", durationSec: 1, phase: GuidedStepPhase.breath, isInhale: true, cycleStepIndex: 1),
  ];
  static const _packingGulps = [
    ..._packingGulp, ..._packingGulp, ..._packingGulp, ..._packingGulp,
    ..._packingGulp, ..._packingGulp, ..._packingGulp, ..._packingGulp,
    ..._packingGulp, ..._packingGulp, ..._packingGulp, ..._packingGulp,
  ];
}