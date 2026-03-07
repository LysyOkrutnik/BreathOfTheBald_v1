import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

enum Difficulty { mild, strong, beast, guru }

enum ExerciseType { wimHof, boxBreathing, relax478, fireBreathing }

class LevelData {
  final String title;
  final String subtitle;
  final ExerciseType type;

  // Configure parameters specific to the Wim Hof method.
  final int totalRounds;
  final int totalBreaths;
  final Duration breathPace;

  // Configure parameters for loop-based or time-boxed exercises.
  final int? loopCount;
  final Duration? totalDuration;

  // Define UI presentation mapping.
  final Color color;
  final String instructionTitleKey;
  final String instructionDescriptionKey;
  final List<String> instructionStepKeys;

  const LevelData({
    required this.title,
    required this.subtitle,
    required this.type,
    this.totalRounds = 0,
    this.totalBreaths = 0,
    this.breathPace = Duration.zero,
    this.loopCount,
    this.totalDuration,
    required this.color,
    required this.instructionTitleKey,
    required this.instructionDescriptionKey,
    required this.instructionStepKeys,
  });

  static const Map<String, LevelData> levels = {
    // --- WIM HOF ---
    'mild': LevelData(
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
    // Group automated sessions that require no user input during execution.
    'box': LevelData(
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
      title: "level_relax",
      subtitle: "desc_sleep",
      type: ExerciseType.relax478,
      loopCount: 32, // Target an approximate 10-minute session length.
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
  };
}