import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';

/// CRUD + progression logic for the freediving CO2/O2 table feature.
class FreedivingRepository {
  FreedivingRepository(this._db);

  final AppDatabase _db;

  /// Ensures a single profile row exists and returns it.
  Future<FreedivingProfileData> getProfile() async {
    final existing =
        await (_db.select(_db.freedivingProfile)..limit(1)).getSingleOrNull();
    if (existing != null) return existing;

    final id = await _db
        .into(_db.freedivingProfile)
        .insert(const FreedivingProfileCompanion());
    return (_db.select(_db.freedivingProfile)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Stream<FreedivingProfileData?> watchProfile() {
    return (_db.select(_db.freedivingProfile)..limit(1)).watchSingleOrNull();
  }

  Future<void> acknowledgeSafety() async {
    final profile = await getProfile();
    await (_db.update(_db.freedivingProfile)
          ..where((t) => t.id.equals(profile.id)))
        .write(FreedivingProfileCompanion(
            safetyAcknowledgedAt: Value(DateTime.now())));
  }

  /// Records a completed guided Max PB Attempt: sets the new verified PB and
  /// resets both working (virtual) PBs to match it, since a fresh, real test
  /// is the most trustworthy data point available.
  Future<void> recordVerifiedPb(int pbSeconds) async {
    final profile = await getProfile();
    await (_db.update(_db.freedivingProfile)
          ..where((t) => t.id.equals(profile.id)))
        .write(FreedivingProfileCompanion(
      verifiedPbSec: Value(pbSeconds),
      verifiedPbAt: Value(DateTime.now()),
      virtualPbCo2Sec: Value(pbSeconds),
      virtualPbO2Sec: Value(pbSeconds),
    ));
  }

  /// Persists a just-finished table session (called right after the generic
  /// Sessions history row, mirroring how custom presets get their own
  /// supplementary row). [rpeScore] is null until the post-session prompt.
  Future<int> logTableSession({
    required FreedivingTableType tableType,
    required int pbUsedSec,
    required List<BreathHoldRound> rounds,
    required int roundsCompleted,
    required int durationSec,
  }) {
    final roundsJson = jsonEncode(rounds
        .map((r) =>
            {'round': r.index, 'apneaSec': r.apneaSec, 'restSec': r.restSec})
        .toList());

    return _db.into(_db.freedivingSessionLog).insert(
          FreedivingSessionLogCompanion.insert(
            timestamp: DateTime.now(),
            tableType: tableType == FreedivingTableType.co2 ? 'co2' : 'o2',
            pbUsedSec: pbUsedSec,
            roundsPlanned: rounds.length,
            roundsCompleted: roundsCompleted,
            roundsJson: roundsJson,
            durationSec: durationSec,
          ),
        );
  }

  /// Applies the user's RPE rating for the most recent session of [tableType]:
  /// stores it on that log row and adjusts the corresponding working PB
  /// (±5%, safety-capped to 50%-115% of the last verified test — see
  /// [RpeProgression]).
  Future<void> recordRpeAndAdjustPb({
    required FreedivingTableType tableType,
    required int rpeScore,
  }) async {
    final typeStr = tableType == FreedivingTableType.co2 ? 'co2' : 'o2';

    final lastLog = await (_db.select(_db.freedivingSessionLog)
          ..where((t) => t.tableType.equals(typeStr))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    if (lastLog != null) {
      await (_db.update(_db.freedivingSessionLog)
            ..where((t) => t.id.equals(lastLog.id)))
          .write(FreedivingSessionLogCompanion(rpeScore: Value(rpeScore)));
    }

    final profile = await getProfile();
    final verifiedPb = profile.verifiedPbSec;
    if (verifiedPb == null) return; // No baseline yet; nothing to adjust.

    final currentVirtual = tableType == FreedivingTableType.co2
        ? (profile.virtualPbCo2Sec ?? verifiedPb)
        : (profile.virtualPbO2Sec ?? verifiedPb);

    final nextVirtual = RpeProgression.nextVirtualPb(
      currentVirtualPbSec: currentVirtual,
      verifiedPbSec: verifiedPb,
      rpeScore: rpeScore,
    );

    final now = DateTime.now();
    await (_db.update(_db.freedivingProfile)
          ..where((t) => t.id.equals(profile.id)))
        .write(tableType == FreedivingTableType.co2
            ? FreedivingProfileCompanion(
                virtualPbCo2Sec: Value(nextVirtual),
                lastCo2SessionAt: Value(now),
              )
            : FreedivingProfileCompanion(
                virtualPbO2Sec: Value(nextVirtual),
                lastO2SessionAt: Value(now),
              ));
  }

  Stream<List<FreedivingSessionLogData>> watchRecentLogs({int limit = 20}) {
    return (_db.select(_db.freedivingSessionLog)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }
}
