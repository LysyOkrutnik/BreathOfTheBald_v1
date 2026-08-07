import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
}

class UserProfile extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get dailyStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSessionDate => dateTime().nullable()();
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
}

/// Single-row profile tracking freediving Personal Best and the "virtual" PB
/// used to generate CO2/O2 tables (which drifts with RPE feedback but is
/// safety-capped relative to the last verified test — see
/// FreedivingRepository.recordRpeAndAdjustPb).
class FreedivingProfile extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The last real, guided Max PB Attempt result. Null until the user
  /// completes their first test.
  IntColumn get verifiedPbSec => integer().nullable()();
  DateTimeColumn get verifiedPbAt => dateTime().nullable()();

  /// Working PB used to generate the next table of each type. Initialized to
  /// verifiedPbSec and adjusted ±5% per RPE feedback, clamped to
  /// [50%, 115%] of verifiedPbSec so RPE-driven drift can never exceed a safe
  /// margin above the last real test.
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
}

@DriftDatabase(tables: [
  Sessions,
  UserProfile,
  HealthMetrics,
  PlannedSessions,
  CustomPresets,
  FreedivingProfile,
  FreedivingSessionLog,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

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
          if (from < 5) {
            await m.addColumn(sessions, sessions.spo2Min);
            await m.addColumn(sessions, sessions.spo2Avg);
          }
          // v5 -> v6: heart-rate columns on sessions.
          if (from < 6) {
            await m.addColumn(sessions, sessions.hrMin);
            await m.addColumn(sessions, sessions.hrAvg);
          }
          // v6 -> v7: freediving CO2/O2 table profile + session log.
          if (from < 7) {
            await m.createTable(freedivingProfile);
            await m.createTable(freedivingSessionLog);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

