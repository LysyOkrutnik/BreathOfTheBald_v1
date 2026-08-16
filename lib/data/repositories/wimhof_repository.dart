import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';

/// Persistence + re-evaluation for the Wim Hof classic-ladder progression.
class WimHofRepository {
  WimHofRepository(this._db);

  final AppDatabase _db;

  Future<WimHofProgressData> _getOrCreate() async {
    final existing =
        await (_db.select(_db.wimHofProgress)..limit(1)).getSingleOrNull();
    if (existing != null) return existing;

    final id = await _db.into(_db.wimHofProgress).insert(
          WimHofProgressCompanion.insert(
            currentLevelSetAt: Value(DateTime.now()),
          ),
        );
    return (_db.select(_db.wimHofProgress)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<List<Session>> _allWimHofSessions() {
    return (_db.select(_db.sessions)..where((t) => t.levelKey.isIn(wimHofLadder)))
        .get();
  }

  /// Re-evaluates progression (eligibility / trial-confirm / detraining)
  /// against the latest session history and persists a level change if one
  /// is due. Cheap enough to call every time the Wim Hof tab builds — the
  /// heavy lifting is a couple of indexed SQL queries.
  Future<WimHofNextUp> refresh() async {
    final progress = await _getOrCreate();
    final sessions = await _allWimHofSessions();
    final result = WimHofProgression.compute(
      progress: progress,
      allWimHofSessions: sessions,
    );
    if (result.currentLevelKey != progress.currentLevelKey) {
      await (_db.update(_db.wimHofProgress)..where((t) => t.id.equals(progress.id)))
          .write(WimHofProgressCompanion(
        currentLevelKey: Value(result.currentLevelKey),
        currentLevelSetAt: Value(DateTime.now()),
      ));
    }
    return result;
  }
}
