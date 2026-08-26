import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'database.g.dart';

// Define tables
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();

  /// Key of the [LevelData] exercise that was performed (e.g. 'mild', 'box').
  TextColumn get levelKey => text()();

  /// Total wall-clock length of the session, in seconds.
  IntColumn get durationSec => integer()();
  IntColumn get rounds => integer()();

  /// Sum of all breath-hold (retention) durations across the session, in seconds.
  IntColumn get retentionSec => integer().withDefault(const Constant(0))();
  IntColumn get xpEarned => integer().withDefault(const Constant(0))();

  /// Blood-oxygen (SpO2 %) read from Health Connect during the session window;
  /// null when no wearable data was available.
  IntColumn get spo2Min => integer().nullable()();
  IntColumn get spo2Avg => integer().nullable()();

  /// Heart rate (bpm) read from Health Connect during the session window.
  IntColumn get hrMin => integer().nullable()();
  IntColumn get hrAvg => integer().nullable()();

  /// Rate of Perceived Exertion, 1-10. Null until the post-session prompt is
  /// answered (currently asked after Wim Hof sessions, to drive ladder
  /// auto-progression — see WimHofProgression).
  IntColumn get rpeScore => integer().nullable()();

  /// Stable cross-device identifier used by the sync backend — a
  /// client-generated UUID, distinct from the local autoincrement [id]
  /// (which only has meaning on this device). Nullable only because rows
  /// written before schemaVersion 11 are backfilled by that migration;
  /// every row inserted going forward always has one.
  TextColumn get syncId => text().nullable()();
}

class UserProfile extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get dailyStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSessionDate => dateTime().nullable()();

  /// The highest [dailyStreak] ever reached, kept even after the streak
  /// itself later resets — otherwise breaking a long streak leaves no
  /// lasting record of it at all, despite the daily history already holding
  /// everything needed to know it happened.
  IntColumn get bestStreak => integer().withDefault(const Constant(0))();
}

class HealthMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get co2ToleranceScore => integer().nullable()();
  IntColumn get avgBreathsPerMin => integer().nullable()();
}

/// A future breathing session the user has planned on the calendar. Each row's
/// [id] doubles as the notification id for its reminder.
class PlannedSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The exact date and time the session is planned for.
  DateTimeColumn get scheduledAt => dateTime()();

  /// Key of the planned [LevelData] exercise.
  TextColumn get levelKey => text()();

  /// Best-effort estimated length of this session, in seconds — lets the
  /// calendar show a duration-proportional block and flag same-day overlaps
  /// instead of every plan rendering as an identical point-in-time card.
  /// Null for rows written before this column existed; treated the same as
  /// "unknown" everywhere it's read, never backfilled.
  IntColumn get estimatedDurationSec => integer().nullable()();

  /// Set once the session this plan refers to actually finishes — the row
  /// itself is kept (not deleted) so the calendar/today views can render it
  /// as done rather than it simply vanishing. Null means still upcoming/not
  /// yet completed.
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// A user-defined breathing pattern (the custom-session builder). Durations are
/// in seconds; a phase with 0 seconds is skipped.
class CustomPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get inhaleSec => integer()();
  IntColumn get holdInSec => integer().withDefault(const Constant(0))();
  IntColumn get exhaleSec => integer()();
  IntColumn get holdOutSec => integer().withDefault(const Constant(0))();
  IntColumn get cycles => integer().withDefault(const Constant(8))();
  IntColumn get rounds => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();

  /// See [Sessions.syncId].
  TextColumn get syncId => text().nullable()();

  /// Soft-delete marker: set instead of a real row delete so a deletion on
  /// one device propagates to others on next sync, rather than the server's
  /// still-active copy silently reappearing here. Rows with this set are
  /// filtered out of [CustomPresetRepository.watchPresets].
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Single-row profile tracking freediving Personal Best and the "virtual" PB
/// used to generate CO2/O2 tables (which drifts with RPE feedback but is
/// safety-capped relative to the last verified test — see
/// FreedivingRepository.recordRpeAndAdjustPb).
///
/// The guided Max PB Test measures two separate breath-holds — an
/// exhale-hold (CO2 tolerance) and an inhale-hold (O2/capacity). Both CO2
/// and O2 tables now anchor on the same inhale-hold result
/// (`verifiedPbSec`/`virtualPbO2Sec`), matching conventional freediving
/// practice — see FreedivingRepository.effectivePb's doc comment. The
/// exhale-hold result (`verifiedPbCo2Sec`) is still measured and shown as
/// its own metric in the Max PB Test's results, it just no longer drives
/// table pacing.
class FreedivingProfile extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The last real, guided inhale-hold test result. Null until the user
  /// completes their first test. Kept under its original name for migration
  /// simplicity even though it now anchors both table types, not just O2.
  IntColumn get verifiedPbSec => integer().nullable()();
  DateTimeColumn get verifiedPbAt => dateTime().nullable()();

  /// The last real, guided exhale-hold test result — an informational
  /// metric only now, not used to generate any table. Null until the user
  /// completes their first test.
  IntColumn get verifiedPbCo2Sec => integer().nullable()();
  DateTimeColumn get verifiedPbCo2At => dateTime().nullable()();

  /// Working PB used to generate the next table of either type, adjusted
  /// ±5% per RPE feedback and clamped to [50%, 115%] of `verifiedPbSec` so
  /// RPE-driven drift can never exceed a safe margin above the last real
  /// test. `virtualPbCo2Sec` is written by the Max PB Test alongside
  /// `verifiedPbCo2Sec` (kept for historical/sync symmetry) but no longer
  /// read by anything — `virtualPbO2Sec` is the one shared working PB now.
  IntColumn get virtualPbCo2Sec => integer().nullable()();
  IntColumn get virtualPbO2Sec => integer().nullable()();

  DateTimeColumn get lastCo2SessionAt => dateTime().nullable()();
  DateTimeColumn get lastO2SessionAt => dateTime().nullable()();

  /// Timestamp the user acknowledged the apnea-specific safety disclaimer;
  /// null means the Freediving section has not been unlocked yet.
  DateTimeColumn get safetyAcknowledgedAt => dateTime().nullable()();
}

/// One completed (or aborted) CO2/O2 table session: the exact schedule used
/// and the user's post-session RPE rating, which drives the next table.
class FreedivingSessionLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();

  /// 'co2' or 'o2'.
  TextColumn get tableType => text()();

  /// The PB (seconds) used to generate this table's schedule.
  IntColumn get pbUsedSec => integer()();

  IntColumn get roundsPlanned => integer()();

  /// May be less than roundsPlanned if the user ended the session early.
  IntColumn get roundsCompleted => integer()();

  /// JSON-encoded list of {round, apneaSec, restSec} — the exact schedule used,
  /// kept for history/audit even as generator defaults evolve.
  TextColumn get roundsJson => text()();

  IntColumn get durationSec => integer()();

  /// Rate of Perceived Exertion, 1-10. Null until the post-session prompt is
  /// answered.
  IntColumn get rpeScore => integer().nullable()();

  /// Optional post-session symptom check-in: 'tingling', 'dizziness', or
  /// 'ok'. Null if the user skipped it. A trend of repeated non-'ok' values
  /// is a real safety signal (recurring dizziness/tingling across sessions),
  /// so it's kept as its own field rather than folded into rpeScore, which
  /// only measures perceived effort.
  TextColumn get symptomTag => text().nullable()();

  /// See [Sessions.syncId].
  TextColumn get syncId => text().nullable()();
}

/// A user-defined breath-hold table (the custom freediving builder): a fixed
/// apnea/rest schedule the user sets directly, rather than one generated
/// from their PB. Start/end values are linearly interpolated across rounds.
class CustomFreedivingPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get startApneaSec => integer()();
  IntColumn get endApneaSec => integer()();
  IntColumn get startRestSec => integer()();
  IntColumn get endRestSec => integer()();
  IntColumn get rounds => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// See [Sessions.syncId].
  TextColumn get syncId => text().nullable()();

  /// See [CustomPresets.deletedAt].
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Single-row tracker for the Wim Hof classic-ladder auto-progression.
/// [currentLevelKey] is the "confirmed" level shown as the default/recommended
/// choice; [currentLevelSetAt] bounds the eligibility and trial windows (see
/// WimHofProgression) — sessions before this timestamp don't count toward
/// advancing past the current level.
class WimHofProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get currentLevelKey => text().withDefault(const Constant('mild'))();
  DateTimeColumn get currentLevelSetAt => dateTime().nullable()();
}

@DriftDatabase(tables: [
  Sessions,
  UserProfile,
  HealthMetrics,
  PlannedSessions,
  CustomPresets,
  FreedivingProfile,
  FreedivingSessionLog,
  WimHofProgress,
  CustomFreedivingPresets,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: the Sessions table was redesigned (it never held real
          // data, as history previously lived in SharedPreferences), so it is
          // safe to drop and recreate it with the new columns.
          if (from < 2) {
            await m.deleteTable('sessions');
            await m.createTable(sessions);
          }
          // v2 -> v3: introduced calendar-based planned sessions.
          if (from < 3) {
            await m.createTable(plannedSessions);
          }
          // v3 -> v4: introduced custom breathing presets.
          if (from < 4) {
            await m.createTable(customPresets);
          }
          // v4 -> v5: SpO2 columns on sessions.
          //
          // Every `addColumn` below is additionally guarded on `from >= N`,
          // where N is the version whose `createTable`/recreate call above
          // already bakes in *today's* full column set (Drift's migration
          // API builds a table from the current Dart definition, not a
          // historical snapshot — there's no partial-schema table to target
          // otherwise). Without that lower bound, a device jumping several
          // versions in one upgrade (e.g. from v1 straight to v11, plausible
          // for an install that sat unused for a while) would recreate
          // `sessions` at the `from < 2` branch above with spo2Min/spo2Avg
          // already present, then this block would try to add those same
          // columns again — SQLite raises "duplicate column name", the
          // whole migration transaction fails, and the app can't open its
          // database at all afterwards.
          if (from >= 2 && from < 5) {
            await m.addColumn(sessions, sessions.spo2Min);
            await m.addColumn(sessions, sessions.spo2Avg);
          }
          // v5 -> v6: heart-rate columns on sessions.
          if (from >= 2 && from < 6) {
            await m.addColumn(sessions, sessions.hrMin);
            await m.addColumn(sessions, sessions.hrAvg);
          }
          // v6 -> v7: freediving CO2/O2 table profile + session log.
          if (from < 7) {
            await m.createTable(freedivingProfile);
            await m.createTable(freedivingSessionLog);
          }
          // v7 -> v8: RPE on regular sessions + Wim Hof ladder progression.
          if (from >= 2 && from < 8) {
            await m.addColumn(sessions, sessions.rpeScore);
          }
          if (from < 8) {
            await m.createTable(wimHofProgress);
          }
          // v8 -> v9: user-defined custom freediving table presets.
          if (from < 9) {
            await m.createTable(customFreedivingPresets);
          }
          // v9 -> v10: post-session symptom check-in on freediving logs.
          if (from >= 7 && from < 10) {
            await m.addColumn(freedivingSessionLog, freedivingSessionLog.symptomTag);
          }
          // v10 -> v11: cross-device sync — a client-generated syncId on
          // every syncable row, plus soft-delete on presets so a deletion on
          // one device propagates instead of the server's still-active copy
          // reappearing here.
          if (from >= 2 && from < 11) {
            await m.addColumn(sessions, sessions.syncId);
          }
          if (from >= 7 && from < 11) {
            await m.addColumn(freedivingSessionLog, freedivingSessionLog.syncId);
          }
          if (from >= 4 && from < 11) {
            await m.addColumn(customPresets, customPresets.syncId);
            await m.addColumn(customPresets, customPresets.deletedAt);
          }
          if (from >= 9 && from < 11) {
            await m.addColumn(customFreedivingPresets, customFreedivingPresets.syncId);
            await m.addColumn(customFreedivingPresets, customFreedivingPresets.deletedAt);
          }
          if (from < 11) {
            await _backfillSyncIds();
          }
          // v11 -> v12: the guided Max PB Test now measures an exhale-hold
          // (CO2 tolerance) separately from the inhale-hold (verifiedPbSec,
          // unchanged) — new columns for that second, independent baseline.
          if (from >= 7 && from < 12) {
            await m.addColumn(freedivingProfile, freedivingProfile.verifiedPbCo2Sec);
            await m.addColumn(freedivingProfile, freedivingProfile.verifiedPbCo2At);
          }
          // v12 -> v13: track the best streak ever reached, separately from
          // the current (resettable) one.
          if (from < 13) {
            await m.addColumn(userProfile, userProfile.bestStreak);
          }
          // v13 -> v14: estimated duration on a planned session, so the
          // calendar can show a proportional block and flag overlaps
          // instead of every plan looking identical regardless of length.
          if (from >= 3 && from < 14) {
            await m.addColumn(plannedSessions, plannedSessions.estimatedDurationSec);
          }
          // v14 -> v15: mark a planned session done in place instead of it
          // simply disappearing — the calendar/today views had no way to
          // tell a just-finished plan from an untouched one.
          if (from >= 3 && from < 15) {
            await m.addColumn(plannedSessions, plannedSessions.completedAt);
          }
        },
      );

  /// Clears every locally-stored row — called on logout, logout-everywhere,
  /// and account deletion. Without this, a session/preset's `syncId` is
  /// permanent (assigned once at creation, never reused), so leftover local
  /// rows from an account that just logged out — or was just deleted
  /// server-side — get silently re-pushed and attributed to whichever
  /// account logs in next on this device. Deliberately wipes everything,
  /// not just the synced tables: a stale WimHofProgress/UserProfile left
  /// behind would otherwise show the previous account's level/streak to
  /// the next one for that brief window before the first sync pull lands.
  Future<void> wipeAllLocalData() {
    return transaction(() async {
      await delete(sessions).go();
      await delete(userProfile).go();
      await delete(healthMetrics).go();
      await delete(plannedSessions).go();
      await delete(customPresets).go();
      await delete(freedivingProfile).go();
      await delete(freedivingSessionLog).go();
      await delete(wimHofProgress).go();
      await delete(customFreedivingPresets).go();
    });
  }

  /// One-time backfill for rows written before syncId existed — every row
  /// needs a stable identity before the first sync push, or it would look
  /// new (and get duplicated) on the server every time.
  Future<void> _backfillSyncIds() async {
    const uuid = Uuid();

    for (final row in await select(sessions).get()) {
      if (row.syncId == null) {
        await (update(sessions)..where((t) => t.id.equals(row.id)))
            .write(SessionsCompanion(syncId: Value(uuid.v4())));
      }
    }
    for (final row in await select(freedivingSessionLog).get()) {
      if (row.syncId == null) {
        await (update(freedivingSessionLog)..where((t) => t.id.equals(row.id)))
            .write(FreedivingSessionLogCompanion(syncId: Value(uuid.v4())));
      }
    }
    for (final row in await select(customPresets).get()) {
      if (row.syncId == null) {
        await (update(customPresets)..where((t) => t.id.equals(row.id)))
            .write(CustomPresetsCompanion(syncId: Value(uuid.v4())));
      }
    }
    for (final row in await select(customFreedivingPresets).get()) {
      if (row.syncId == null) {
        await (update(customFreedivingPresets)..where((t) => t.id.equals(row.id)))
            .write(CustomFreedivingPresetsCompanion(syncId: Value(uuid.v4())));
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

