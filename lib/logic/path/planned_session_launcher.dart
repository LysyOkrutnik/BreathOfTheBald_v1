import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/widgets/freediving_pb_gate.dart';

/// Starts a [PlannedSession] the same way regardless of which screen it was
/// tapped from (the Scheduler's day panel, or Dziś's "scheduled today"
/// section) — each level type has its own launch quirk (the PB test needs
/// its own screen, cold shower logs immediately with no session lifecycle,
/// CO2/O2 tables need a live PB gate check), previously only implemented
/// once, inside the Scheduler screen.
Future<void> startPlannedSession(
  BuildContext context,
  WidgetRef ref,
  PlannedSession plan,
) async {
  final level = LevelData.levels[plan.levelKey];
  if (level == null) return;

  if (level.key == 'freediving_pb_test') {
    Navigator.of(context)
        .push(fadeThroughRoute(MaxPbTestScreen(plannedSessionId: plan.id)));
    return;
  }
  if (level.key == coldShowerLevelKey) {
    // No guided screen for this one either — logging it *is* "starting" it,
    // so it's done the instant this returns rather than waiting on a
    // session lifecycle that doesn't apply here.
    final messenger = ScaffoldMessenger.of(context);
    final result = await logColdShowerSession(ref);
    unawaited(ref.read(plannerRepositoryProvider).completePlan(plan.id));
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(L10n.get(context, 'coldshower_logged_toast')),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: L10n.get(context, 'common_undo'),
          onPressed: () => undoColdShowerSession(ref, result),
        ),
      ));
    }
    return;
  }

  var toStart = level;
  if (level.type == ExerciseType.co2Table || level.type == ExerciseType.o2Table) {
    final profile = await ref.read(freedivingRepositoryProvider).getProfile();
    if (!context.mounted) return;
    final tableType =
        level.type == ExerciseType.co2Table ? FreedivingTableType.co2 : FreedivingTableType.o2;
    final pb = checkFreedivingPbGate(context, tableType: tableType, profile: profile);
    if (pb == null) return;
    toStart = LevelData.freedivingTable(tableType: tableType, pbSeconds: pb);
  }
  if (context.mounted) {
    Navigator.of(context)
        .push(fadeThroughRoute(IntroScreen(level: toStart, plannedSessionId: plan.id)));
  }
}
