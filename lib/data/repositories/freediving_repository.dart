import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:okrutnik_breath/core/sync/profile_sync_marker.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:uuid/uuid.dart';

/// CRUD + progression logic for the freediving CO2/O2 table feature.
class FreedivingRepository {
  FreedivingRepository(this._db);

  final AppDatabase _db;

  /// Ensures a single profile row exists and returns it. Wrapped in a
  /// transaction so two near-simultaneous first calls (plausible right at
  /// app startup) can't both see "no row yet" and both insert one —
  /// Drift serializes transactions against each other on this app's single
  /// database connection, so the second caller's select-then-insert
  /// correctly waits for the first's to fully land first.
  Future<FreedivingProfileData> getProfile() {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.freedivingProfile)..limit(1)).getSingleOrNull();
      if (existing != null) return existing;

      final id = await _db
          .into(_db.freedivingProfile)
          .insert(const FreedivingProfileCompanion());
      return (_db.select(_db.freedivingProfile)..where((t) => t.id.equals(id)))
          .getSingle();
    });
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
    await ProfileSyncMarker.markChanged();
  }

  /// Records a completed guided Max PB Test: the exhale-hold result anchors
  /// the CO2 baseline, the inhale-hold result anchors the O2 baseline, and
  /// both working (virtual) PBs reset to match their matching baseline —
  /// a fresh, real test is the most trustworthy data point available for
  /// each. Returns the profile as it was *before* this write, so the caller
  /// can show a "vs. last time" comparison without a separate read.
  Future<FreedivingProfileData> recordVerifiedPb({
    required int exhalePbSeconds,
    required int inhalePbSeconds,
  }) async {
    final previous = await getProfile();
    final now = DateTime.now();
    await (_db.update(_db.freedivingProfile)
          ..where((t) => t.id.equals(previous.id)))
        .write(FreedivingProfileCompanion(
      verifiedPbSec: Value(inhalePbSeconds),
      verifiedPbAt: Value(now),
      verifiedPbCo2Sec: Value(exhalePbSeconds),
      verifiedPbCo2At: Value(now),
      virtualPbCo2Sec: Value(exhalePbSeconds),
      virtualPbO2Sec: Value(inhalePbSeconds),
    ));
    await ProfileSyncMarker.markChanged();
    return previous;
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
    // Per-round "first contraction" marks (see RoundContraction) — folded
    // into the same free-form JSON blob rather than a new column, so this
    // needed no schema migration. Absent or shorter than [rounds] (e.g. an
    // early-ended table) just means later rounds have no contraction data.
    List<RoundContraction>? contractions,
  }) {
    final roundsJson = jsonEncode(rounds.asMap().entries.map((entry) {
      final r = entry.value;
      final contraction = contractions != null && entry.key < contractions.length
          ? contractions[entry.key]
          : null;
      return {
        'round': r.index,
        'apneaSec': r.apneaSec,
        'restSec': r.restSec,
        if (contraction?.firstContractionSec != null)
          'firstContractionSec': contraction!.firstContractionSec,
        if (contraction != null && contraction.markCount > 0)
          'contractionMarks': contraction.markCount,
      };
    }).toList());

    return _db.into(_db.freedivingSessionLog).insert(
          FreedivingSessionLogCompanion.insert(
            timestamp: DateTime.now(),
            tableType: tableType == FreedivingTableType.co2 ? 'co2' : 'o2',
            pbUsedSec: pbUsedSec,
            roundsPlanned: rounds.length,
            roundsCompleted: roundsCompleted,
            roundsJson: roundsJson,
            durationSec: durationSec,
            syncId: Value(const Uuid().v4()),
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
    // Each table type is safety-capped against its OWN matching real test —
    // CO2 against the exhale-hold, O2 against the inhale-hold — not a single
    // shared verified PB, since the two measure different physiological
    // limits and can differ substantially.
    final verifiedPb =
        tableType == FreedivingTableType.co2 ? profile.verifiedPbCo2Sec : profile.verifiedPbSec;
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

  /// Concerning symptom tags (see the check-in chips on the summary screen)
  /// — 'ok' is deliberately excluded, it's the reassuring option.
  static const _concerningSymptoms = {'tingling', 'dizziness'};

  /// Records the post-session symptom check-in on the most recent log of
  /// [tableType] — same "find the last log, attach it" pattern as
  /// [recordRpeAndAdjustPb]. Unlike RPE, a single report doesn't move the
  /// working PB (one dizzy spell can have any number of unrelated causes);
  /// but a symptom recurring across recent sessions of the same table is a
  /// real safety signal, so that eases the working PB the same way a
  /// "brutal" RPE rating would.
  Future<void> recordSymptomTag({
    required FreedivingTableType tableType,
    required String symptomTag,
  }) async {
    final typeStr = tableType == FreedivingTableType.co2 ? 'co2' : 'o2';
    final recentLogs = await (_db.select(_db.freedivingSessionLog)
          ..where((t) => t.tableType.equals(typeStr))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(3))
        .get();
    if (recentLogs.isEmpty) return;
    final lastLog = recentLogs.first;
    await (_db.update(_db.freedivingSessionLog)
          ..where((t) => t.id.equals(lastLog.id)))
        .write(FreedivingSessionLogCompanion(symptomTag: Value(symptomTag)));

    if (!_concerningSymptoms.contains(symptomTag)) return;
    final priorConcerning = recentLogs
        .skip(1)
        .where((l) => _concerningSymptoms.contains(l.symptomTag))
        .isNotEmpty;
    if (!priorConcerning) return; // First report — not a pattern yet.

    final profile = await getProfile();
    final verifiedPb =
        tableType == FreedivingTableType.co2 ? profile.verifiedPbCo2Sec : profile.verifiedPbSec;
    if (verifiedPb == null) return;
    final currentVirtual = tableType == FreedivingTableType.co2
        ? (profile.virtualPbCo2Sec ?? verifiedPb)
        : (profile.virtualPbO2Sec ?? verifiedPb);
    final nextVirtual = RpeProgression.nextVirtualPb(
      currentVirtualPbSec: currentVirtual,
      verifiedPbSec: verifiedPb,
      rpeScore: 10,
    );
    await (_db.update(_db.freedivingProfile)
          ..where((t) => t.id.equals(profile.id)))
        .write(tableType == FreedivingTableType.co2
            ? FreedivingProfileCompanion(virtualPbCo2Sec: Value(nextVirtual))
            : FreedivingProfileCompanion(virtualPbO2Sec: Value(nextVirtual)));
  }

  Stream<List<FreedivingSessionLogData>> watchRecentLogs({int limit = 20}) {
    return (_db.select(_db.freedivingSessionLog)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  /// Every log with `timestamp >= cutoff` — unlike [watchRecentLogs]'s count
  /// cap, this can never silently drop a session that's still inside the
  /// window just because a more prolific user pushed it past a fixed
  /// `limit`. Used for the weekly hard-session cap, which needs a real
  /// calendar week, not "however many of the last 20 logs happen to be
  /// recent enough."
  Stream<List<FreedivingSessionLogData>> watchLogsSince(DateTime cutoff) {
    return (_db.select(_db.freedivingSessionLog)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(cutoff))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  /// All-time session log, unbounded — used to compute cumulative per-type
  /// counts (e.g. "how many CO2 tables ever") for the guided training path,
  /// where a recent-only window would undercount an established user.
  Stream<List<FreedivingSessionLogData>> watchAllLogs() {
    return (_db.select(_db.freedivingSessionLog)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  /// Overwrites the ProfileState-relevant fields of the profile row from a
  /// sync pull (the server already decided this was the newer side of the
  /// last-write-wins comparison). Deliberately leaves the RPE-driven virtual
  /// PBs untouched — those aren't part of ProfileState, they're recomputed
  /// locally per-table from RPE feedback, not synced directly.
  Future<void> applyProfileStateFromSync({
    required int? verifiedPbSec,
    required DateTime? verifiedPbAt,
    required int? verifiedPbCo2Sec,
    required DateTime? verifiedPbCo2At,
    required DateTime? safetyAcknowledgedAt,
  }) async {
    final profile = await getProfile();
    await (_db.update(_db.freedivingProfile)..where((t) => t.id.equals(profile.id)))
        .write(FreedivingProfileCompanion(
      verifiedPbSec: Value(verifiedPbSec),
      verifiedPbAt: Value(verifiedPbAt),
      verifiedPbCo2Sec: Value(verifiedPbCo2Sec),
      verifiedPbCo2At: Value(verifiedPbCo2At),
      safetyAcknowledgedAt: Value(safetyAcknowledgedAt),
    ));
  }

  /// Part of the "reset progress" flow: wipes every table-session log and
  /// clears the verified/virtual PBs, but deliberately keeps
  /// [FreedivingProfileData.safetyAcknowledgedAt] — that's a one-time
  /// consent, not progress, and re-showing the safety disclaimer wouldn't
  /// serve the user starting over.
  Future<void> resetProgress() async {
    await _db.delete(_db.freedivingSessionLog).go();
    final profile = await getProfile();
    await (_db.update(_db.freedivingProfile)..where((t) => t.id.equals(profile.id)))
        .write(const FreedivingProfileCompanion(
      verifiedPbSec: Value(null),
      verifiedPbAt: Value(null),
      verifiedPbCo2Sec: Value(null),
      verifiedPbCo2At: Value(null),
      virtualPbCo2Sec: Value(null),
      virtualPbO2Sec: Value(null),
      lastCo2SessionAt: Value(null),
      lastO2SessionAt: Value(null),
    ));
    await ProfileSyncMarker.markChanged();
  }

  /// One-shot read of every log — used by SyncService to build a push
  /// payload.
  Future<List<FreedivingSessionLogData>> getAllLogsOnce() =>
      _db.select(_db.freedivingSessionLog).get();

  /// Applied during a sync pull — same insert-or-refresh-mutable-fields
  /// pattern as [SessionRepository.upsertFromSync].
  Future<void> upsertFromSync({
    required String syncId,
    required String tableType,
    required int pbUsedSec,
    required int roundsPlanned,
    required int roundsCompleted,
    required String roundsJson,
    required int durationSec,
    required DateTime timestamp,
    int? rpeScore,
    String? symptomTag,
  }) async {
    final existing = await (_db.select(_db.freedivingSessionLog)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.freedivingSessionLog)..where((t) => t.id.equals(existing.id)))
          .write(FreedivingSessionLogCompanion(
        rpeScore: Value(rpeScore),
        symptomTag: Value(symptomTag),
      ));
      return;
    }
    await _db.into(_db.freedivingSessionLog).insert(FreedivingSessionLogCompanion.insert(
          timestamp: timestamp,
          tableType: tableType,
          pbUsedSec: pbUsedSec,
          roundsPlanned: roundsPlanned,
          roundsCompleted: roundsCompleted,
          roundsJson: roundsJson,
          durationSec: durationSec,
          rpeScore: Value(rpeScore),
          symptomTag: Value(symptomTag),
          syncId: Value(syncId),
        ));
  }
}
