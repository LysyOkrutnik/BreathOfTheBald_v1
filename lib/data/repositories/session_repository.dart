import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists completed breathing sessions to the Drift database and exposes a
/// reactive stream for the history screen.
///
/// This replaces the previous SharedPreferences-backed JSON list, which left
/// the typed [Sessions] table unused. A one-time migration ([importLegacyData])
/// moves any sessions saved by older builds into the database.
class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// Key used by legacy builds that stored sessions as a JSON string list.
  static const String _legacyPrefsKey = 'sessions';

  /// Flag preventing the legacy import from running more than once.
  static const String _legacyMigratedKey = 'sessions_migrated_to_drift';

  Future<int> addSession({
    required String levelKey,
    required DateTime timestamp,
    required int durationSec,
    required int rounds,
    required int retentionSec,
    required int xpEarned,
  }) {
    return _db.into(_db.sessions).insert(
          SessionsCompanion.insert(
            timestamp: timestamp,
            levelKey: levelKey,
            durationSec: durationSec,
            rounds: rounds,
            retentionSec: Value(retentionSec),
            xpEarned: Value(xpEarned),
            syncId: Value(const Uuid().v4()),
          ),
        );
  }

  /// Records the post-session RPE rating (1-10) for [sessionId].
  Future<void> updateRpe(int sessionId, int rpeScore) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
        .write(SessionsCompanion(rpeScore: Value(rpeScore)));
  }

  /// Removes a session outright — used to back out of an accidental log
  /// (e.g. the cold-shower checklist's "undo" window) rather than leaving a
  /// false record in history.
  Future<void> deleteSession(int id) {
    return (_db.delete(_db.sessions)..where((t) => t.id.equals(id))).go();
  }

  /// Emits the full session history, newest first, updating on every change.
  Stream<List<Session>> watchSessions() {
    return (_db.select(_db.sessions)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  /// Wipes every session — part of the "reset progress" flow. Custom
  /// presets aren't touched (they're user-authored content, not progress).
  Future<void> deleteAll() => _db.delete(_db.sessions).go();

  /// One-shot read of every session — used by SyncService to build a push
  /// payload (the full set is pushed every sync; the server-side upsert is
  /// idempotent, so re-pushing an already-synced row is a harmless no-op).
  Future<List<Session>> getAllSessions() => _db.select(_db.sessions).get();

  /// Applied during a sync pull: inserts a session that originated on
  /// another device (matched by [syncId]), or refreshes the one field that
  /// can change after the fact (rpeScore) if it already exists locally —
  /// everything else about a session is immutable once logged.
  Future<void> upsertFromSync({
    required String syncId,
    required String levelKey,
    required DateTime timestamp,
    required int durationSec,
    required int rounds,
    required int retentionSec,
    required int xpEarned,
    int? rpeScore,
  }) async {
    final existing = await (_db.select(_db.sessions)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(existing.id)))
          .write(SessionsCompanion(rpeScore: Value(rpeScore)));
      return;
    }
    await _db.into(_db.sessions).insert(SessionsCompanion.insert(
          timestamp: timestamp,
          levelKey: levelKey,
          durationSec: durationSec,
          rounds: rounds,
          retentionSec: Value(retentionSec),
          xpEarned: Value(xpEarned),
          rpeScore: Value(rpeScore),
          syncId: Value(syncId),
        ));
  }

  /// Moves sessions persisted by older SharedPreferences-based builds into the
  /// database exactly once, then clears the legacy entry.
  Future<void> importLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyMigratedKey) ?? false) return;

    final legacy = prefs.getStringList(_legacyPrefsKey) ?? const [];
    for (final raw in legacy) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        await addSession(
          levelKey: (data['levelKey'] as String?) ?? 'mild',
          timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ??
              DateTime.now(),
          durationSec: (data['duration'] as num?)?.toInt() ?? 0,
          rounds: (data['rounds'] as num?)?.toInt() ?? 1,
          retentionSec: (data['retentionSeconds'] as num?)?.toInt() ?? 0,
          xpEarned: 0,
        );
      } catch (e, st) {
        developer.log('Skipped malformed legacy session',
            name: 'SessionRepository', error: e, stackTrace: st);
      }
    }

    await prefs.remove(_legacyPrefsKey);
    await prefs.setBool(_legacyMigratedKey, true);
  }
}
