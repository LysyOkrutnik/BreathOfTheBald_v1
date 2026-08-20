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
  });

  final String labelKey;
  final int durationSec;
  final GuidedStepPhase phase;

  /// Only meaningful for [GuidedStepPhase.breath] steps — drives the orb's
  /// pulse direction. Null for a plain repetition cue with no clear
  /// inhale/exhale (e.g. a packing "gulp").
  final bool? isInhale;
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

  // UI presentation mapping.
  final Color color;
  final String instructionTitleKey;
  final String instructionDescriptionKey;
  final List<String> instructionStepKeys;

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
    required this.color,
    required this.instructionTitleKey,
    required this.instructionDescriptionKey,
    required this.instructionStepKeys,
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
      breathPace: Duration(milliseconds: 2000),
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
      color: Color(0xFFE57373),
      instructionTitleKey: "intro_title_guru",
      instructionDescriptionKey: "intro_desc_guru",
      instructionStepKeys: [
        "intro_steps_guru_1",
        "intro_steps_guru_2",
        "intro_steps_guru_3",
        "intro_steps_guru_4",
        "intro_steps_guru_5",
      ],
    ),

    // --- AUTOMATED EXERCISES ---
    // Sessions that run automatically without user input.
    'box': LevelData(
      key: 'box',
      title: "level_sniper",
      subtitle: "desc_focus",
      type: ExerciseType.boxBreathing,
      loopCount: 16,
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
      loopCount: 32, // Approximate a 10-minute session.
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
      totalDuration: Duration(minutes: 3),
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
      instructionStepKeys: [],
      guidedSteps: [
        GuidedStep(labelKey: "guided_stretch_right", durationSec: 25, phase: GuidedStepPhase.hold),
        GuidedStep(labelKey: "guided_stretch_return", durationSec: 3, phase: GuidedStepPhase.hold),
        GuidedStep(labelKey: "guided_stretch_left", durationSec: 25, phase: GuidedStepPhase.hold),
        GuidedStep(labelKey: "guided_stretch_return", durationSec: 3, phase: GuidedStepPhase.hold),
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
      instructionStepKeys: [],
      guidedSteps: [
        GuidedStep(labelKey: "guided_uddiyana_inhale", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: true),
        GuidedStep(labelKey: "guided_uddiyana_exhale", durationSec: 3, phase: GuidedStepPhase.breath, isInhale: false),
        GuidedStep(labelKey: "guided_uddiyana_hold", durationSec: 7, phase: GuidedStepPhase.hold),
        GuidedStep(labelKey: "guided_uddiyana_rest", durationSec: 5, phase: GuidedStepPhase.hold),
      ],
    ),
    'resisted_breathing': LevelData(
      key: 'resisted_breathing',
      title: "exercise_resisted_breathing_title",
      subtitle: "exercise_resisted_breathing_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 3,
      color: Color(0xFF42A5F5),
      instructionTitleKey: "exercise_resisted_breathing_title",
      instructionDescriptionKey: "exercise_resisted_breathing_subtitle",
      instructionStepKeys: [],
      guidedSteps: [
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        ..._resistedBreathingReps, ..._resistedBreathingReps, ..._resistedBreathingReps,
        GuidedStep(labelKey: "guided_resisted_rest", durationSec: 50, phase: GuidedStepPhase.hold),
      ],
    ),
    'three_part_breath': LevelData(
      key: 'three_part_breath',
      title: "exercise_three_part_breath_title",
      subtitle: "exercise_three_part_breath_subtitle",
      type: ExerciseType.guidedRoutine,
      totalRounds: 9,
      color: Color(0xFF66BB6A),
      instructionTitleKey: "exercise_three_part_breath_title",
      instructionDescriptionKey: "exercise_three_part_breath_subtitle",
      instructionStepKeys: [],
      guidedSteps: [
        GuidedStep(labelKey: "guided_threepart_belly_in", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: true),
        GuidedStep(labelKey: "guided_threepart_ribs_in", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: true),
        GuidedStep(labelKey: "guided_threepart_chest_in", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: true),
        GuidedStep(labelKey: "guided_threepart_hold_full", durationSec: 2, phase: GuidedStepPhase.hold),
        GuidedStep(labelKey: "guided_threepart_chest_out", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: false),
        GuidedStep(labelKey: "guided_threepart_ribs_out", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: false),
        GuidedStep(labelKey: "guided_threepart_belly_out", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: false),
        GuidedStep(labelKey: "guided_threepart_hold_empty", durationSec: 2, phase: GuidedStepPhase.hold),
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
      instructionStepKeys: [],
      guidedSteps: [
        ..._packingGulps,
        GuidedStep(labelKey: "guided_packing_hold", durationSec: 10, phase: GuidedStepPhase.hold),
        GuidedStep(labelKey: "guided_packing_exhale", durationSec: 4, phase: GuidedStepPhase.breath, isInhale: false),
      ],
    ),
  };

  /// One inhale+exhale rep, spread 15× into resisted_breathing's step list —
  /// a plain `for`-generated list can't be used inside this `const` map, so
  /// the repetition is a `...` spread of a single const rep instead.
  static const _resistedBreathingReps = [
    GuidedStep(labelKey: "guided_resisted_inhale", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: true),
    GuidedStep(labelKey: "guided_resisted_exhale", durationSec: 2, phase: GuidedStepPhase.breath, isInhale: false),
  ];

  /// One small "top-up" inhale, spread 12× into freediving_packing's step
  /// list — same const-context reasoning as [_resistedBreathingReps].
  static const _packingGulp = [
    GuidedStep(labelKey: "guided_packing_gulp", durationSec: 1, phase: GuidedStepPhase.breath, isInhale: true),
  ];
  static const _packingGulps = [
    ..._packingGulp, ..._packingGulp, ..._packingGulp, ..._packingGulp,
    ..._packingGulp, ..._packingGulp, ..._packingGulp, ..._packingGulp,
    ..._packingGulp, ..._packingGulp, ..._packingGulp, ..._packingGulp,
  ];
}