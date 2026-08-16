import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';

/// The six stages of the guided "Twoja Ścieżka" (Your Path) program — a
/// single, cross-discipline curriculum that walks a complete beginner from
/// their first Wim Hof round to comfortably rotating through Wim Hof and
/// both freediving tables. Entirely derived from existing progress signals
/// (Wim Hof ladder level, freediving PB status, session counts) — there's
/// nothing new to persist for the stage itself.
enum PathStage {
  breathFoundations,
  buildingPower,
  introToHolds,
  co2Tolerance,
  o2Adaptation,
  advanced,
}

/// The single most relevant thing to do today, given where the user is on
/// the path.
enum PathAction { wimHof, pbTest, co2Table, o2Table, coldShower, rest, maintain }

class PathState {
  const PathState({
    required this.stage,
    required this.action,
    this.actionLevelKey,
    this.progressCurrent,
    this.progressTarget,
    this.daysRemaining,
  });

  final PathStage stage;
  final PathAction action;

  /// Set only when [action] is [PathAction.wimHof] — which ladder level to
  /// suggest (the user's current confirmed level).
  final String? actionLevelKey;

  /// Concrete progress toward unlocking the next stage — e.g. "3 of 5"
  /// sessions, or null when the current stage isn't gated by a count (a
  /// single-action stage like the PB test, or the terminal advanced stage).
  final int? progressCurrent;
  final int? progressTarget;

  /// Days still needed at the current Wim Hof level before it's eligible to
  /// advance (stages 1-2 only); null elsewhere, 0 once satisfied.
  final int? daysRemaining;
}

/// Computes the current path stage and today's single recommended action.
class TrainingPath {
  TrainingPath._();

  /// Freediving sessions of a given type below this count mean "still
  /// building comfort with it" — matches the Wim Hof ladder's own
  /// kMinSessionsAtLevel gate for a consistent pace across disciplines.
  static const int minSessionsToAdvance = kMinSessionsAtLevel;

  static PathState compute({
    required WimHofNextUp wimHof,
    required bool pbVerified,
    required int co2SessionCount,
    required int o2SessionCount,
    required bool weeklyCapReached,
  }) {
    final wimHofCurrentLevelKey = wimHof.currentLevelKey;
    late final PathStage stage;
    late PathAction action;
    String? actionLevelKey;
    int? progressCurrent;
    int? progressTarget;
    int? daysRemaining;

    if (wimHofCurrentLevelKey == 'mild' || wimHofCurrentLevelKey == 'strong') {
      stage = wimHofCurrentLevelKey == 'mild'
          ? PathStage.breathFoundations
          : PathStage.buildingPower;
      action = PathAction.wimHof;
      actionLevelKey = wimHofCurrentLevelKey;
      progressCurrent = wimHof.sessionsAtLevel;
      progressTarget = kMinSessionsAtLevel;
      daysRemaining = (kMinDaysAtLevel - wimHof.daysAtLevel).clamp(0, kMinDaysAtLevel);
    } else if (!pbVerified) {
      stage = PathStage.introToHolds;
      action = PathAction.pbTest;
    } else if (co2SessionCount < minSessionsToAdvance) {
      stage = PathStage.co2Tolerance;
      action = PathAction.co2Table;
      progressCurrent = co2SessionCount;
      progressTarget = minSessionsToAdvance;
    } else if (o2SessionCount < minSessionsToAdvance) {
      stage = PathStage.o2Adaptation;
      action = PathAction.o2Table;
      progressCurrent = o2SessionCount;
      progressTarget = minSessionsToAdvance;
    } else {
      stage = PathStage.advanced;
      action = PathAction.maintain;
    }

    // A PB test is a single all-out effort and both tables are demanding —
    // all three defer to the weekly load cap same as a hard Wim Hof level.
    // Plain Wim Hof (mild/strong, the only levels reachable before the PB
    // stage) and the maintenance suggestion are left alone.
    final isHardAction = action == PathAction.pbTest ||
        action == PathAction.co2Table ||
        action == PathAction.o2Table;
    if (weeklyCapReached && isHardAction) {
      action = PathAction.rest;
    }

    return PathState(
      stage: stage,
      action: action,
      actionLevelKey: actionLevelKey,
      progressCurrent: progressCurrent,
      progressTarget: progressTarget,
      daysRemaining: daysRemaining,
    );
  }
}

String stageTitleKey(PathStage stage) {
  switch (stage) {
    case PathStage.breathFoundations:
      return 'path_stage_1_title';
    case PathStage.buildingPower:
      return 'path_stage_2_title';
    case PathStage.introToHolds:
      return 'path_stage_3_title';
    case PathStage.co2Tolerance:
      return 'path_stage_4_title';
    case PathStage.o2Adaptation:
      return 'path_stage_5_title';
    case PathStage.advanced:
      return 'path_stage_6_title';
  }
}

String stageDescKey(PathStage stage) {
  switch (stage) {
    case PathStage.breathFoundations:
      return 'path_stage_1_desc';
    case PathStage.buildingPower:
      return 'path_stage_2_desc';
    case PathStage.introToHolds:
      return 'path_stage_3_desc';
    case PathStage.co2Tolerance:
      return 'path_stage_4_desc';
    case PathStage.o2Adaptation:
      return 'path_stage_5_desc';
    case PathStage.advanced:
      return 'path_stage_6_desc';
  }
}

/// A short "3/5 sessions • 4 days left" progress line for the current stage,
/// or null when the stage isn't gated by a count (e.g. the PB-test stage or
/// the terminal advanced stage — nothing to count toward there).
String? progressLabelForLocale(String languageCode, PathState path) {
  if (path.progressCurrent == null || path.progressTarget == null) return null;
  var label = L10n
      .getForLocale(languageCode, 'path_progress_sessions')
      .replaceFirst('{current}', '${path.progressCurrent}')
      .replaceFirst('{target}', '${path.progressTarget}');
  final days = path.daysRemaining;
  if (days != null && days > 0) {
    final daysLabel = L10n
        .getForLocale(languageCode, 'path_days_remaining')
        .replaceFirst('{n}', '$days');
    label = '$label • $daysLabel';
  }
  return label;
}
