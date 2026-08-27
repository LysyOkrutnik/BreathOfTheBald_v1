import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';

/// The single "can this CO2/O2 table actually start" check — used to be
/// reimplemented independently at every place a table can be started
/// (Dziś's `_startAction`, the Scheduler's `_startFromPlan`), keyed by two
/// different discriminators (`PathAction` vs `LevelData.type`) with
/// identical but separately-maintained snackbar copy. A future change to
/// the lock condition (e.g. a stale-but-not-fully-expired PB state) only
/// needed updating here now instead of drifting between call sites.
///
/// Returns the effective PB in seconds when the table is unlocked; shows
/// the "locked, no PB" snackbar (with a CTA straight to the Max PB Test)
/// and returns null otherwise — callers just check for null and return.
int? checkFreedivingPbGate(
  BuildContext context, {
  required FreedivingTableType tableType,
  required FreedivingProfileData profile,
}) {
  final pb = FreedivingRepository.effectivePb(tableType: tableType, profile: profile);
  if (pb > 0) return pb;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(L10n.get(context, 'freediving_locked_no_pb')),
    action: SnackBarAction(
      label: L10n.get(context, 'freediving_pb_test_cta'),
      onPressed: () =>
          Navigator.of(context).push(fadeThroughRoute(const MaxPbTestScreen())),
    ),
  ));
  return null;
}
