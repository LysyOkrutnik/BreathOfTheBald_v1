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
  };
}