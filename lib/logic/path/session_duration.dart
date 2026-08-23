import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart' show PathAction;
import 'package:okrutnik_breath/logic/path/weekly_plan.dart' show PlannedAction;

/// Best-effort length of a [PlannedAction], in seconds — the [PathAction]
/// counterpart to [estimatedDurationSecForLevel], covering the action types
/// that don't have (or can't be resolved to) a real static [LevelData]
/// entry. CO2/O2 use the caller's live [freedivingProfile] to generate a
/// real schedule with [Co2O2TableGenerator], the same way the app would
/// actually build the session — not a guess. Test PB and cold shower are
/// genuinely open-ended/user-timed, so they fall back to a documented rough
/// placeholder purely for calendar overlap purposes; that placeholder is
/// never shown to the user as a real duration anywhere else.
int estimatedDurationSecForAction(
  PlannedAction action, {
  FreedivingProfileData? freedivingProfile,
}) {
  const freedivingTableFallbackSec = 20 * 60;

  switch (action.type) {
    case PathAction.wimHof:
    case PathAction.mobility:
      final level = LevelData.levels[action.levelKey];
      return level == null ? 0 : estimatedDurationSecForLevel(level);

    case PathAction.co2Table:
    case PathAction.o2Table:
      if (freedivingProfile == null) return freedivingTableFallbackSec;
      final tableType = action.type == PathAction.co2Table
          ? FreedivingTableType.co2
          : FreedivingTableType.o2;
      final pb =
          FreedivingRepository.effectivePb(tableType: tableType, profile: freedivingProfile);
      if (pb <= 0) return freedivingTableFallbackSec;
      final rounds = tableType == FreedivingTableType.co2
          ? Co2O2TableGenerator.generateCo2Table(pb)
          : Co2O2TableGenerator.generateO2Table(pb);
      return rounds.fold<int>(
          0, (sum, r) => sum + r.apneaSec + r.restSec + FreedivingSessionTiming.perRoundOverheadSec);

    // Both use LevelData.levels' dedicated fallback estimate (see
    // estimatedDurationSecForLevel) rather than duplicating it here.
    case PathAction.pbTest:
      return estimatedDurationSecForLevel(LevelData.levels['freediving_pb_test']!);
    case PathAction.coldShower:
      return estimatedDurationSecForLevel(LevelData.levels['cold_shower']!);

    case PathAction.rest:
    case PathAction.maintain:
      return 0;
  }
}
