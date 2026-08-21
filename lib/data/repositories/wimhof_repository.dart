import 'package:drift/drift.dart';
import 'package:okrutnik_breath/core/sync/profile_sync_marker.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';

/// Persistence + re-evaluation for the Wim Hof classic-ladder progression.
class WimHofRepository {
  WimHofRepository(this._db);

  final AppDatabase _db;

  /// Wrapped in a transaction — see FreedivingRepository.getProfile for why
  /// this select-then-insert needs to be atomic against a concurrent caller.
  Future<WimHofProgressData> _getOrCreate() {
    return _db.transaction(() async {
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
    });
  }

  /// Exposes the raw progress row — used by SyncService to read the current
  /// ladder position for a ProfileState push.
  Future<WimHofProgressData> getProgress() => _getOrCreate();

  /// Overwrites the ladder position from a sync pull (the server already
  /// decided this was the newer side of the last-write-wins comparison).
  Future<void> applyFromSync({
    required String currentLevelKey,
    required DateTime? currentLevelSetAt,
  }) async {
    final progress = await _getOrCreate();
    await (_db.update(_db.wimHofProgress)..where((t) => t.id.equals(progress.id)))
        .write(WimHofProgressCompanion(
      currentLevelKey: Value(currentLevelKey),
      currentLevelSetAt: Value(currentLevelSetAt),
    ));
  }

  /// Part of the "reset progress" flow.
  Future<void> resetProgress() async {
    final progress = await _getOrCreate();
    await (_db.update(_db.wimHofProgress)..where((t) => t.id.equals(progress.id)))
        .write(WimHofProgressCompanion(
      currentLevelKey: const Value('mild'),
      currentLevelSetAt: Value(DateTime.now()),
    ));
  }

  Future<List<Session>> _allWimHofSessions() {
    return (_db.select(_db.sessions)..where((t) => t.levelKey.isIn(wimHofLadder)))
        .get();
  }

  /// Re-evaluates progression (eligibility / trial-confirm / detraining)
  /// against the latest session history and persists a level change if one
  /// is due. Cheap enough to call every time the Wim Hof tab builds — the
  /// heavy lifting is a couple of indexed SQL queries.
  Future<WimHofNextUp> refresh({
    int? detrainingDaysOverride,
    double? pbCautionRatioOverride,
    double? maxAvgRpeToAdvanceOverride,
  }) async {
    final progress = await _getOrCreate();
    final sessions = await _allWimHofSessions();
    // Read directly rather than depending on FreedivingRepository — this is
    // the one field (verifiedPbSec) the PB-caution advisory needs, and a
    // repository-to-repository dependency would be a lot of coupling for it.
    final freedivingProfile =
        await (_db.select(_db.freedivingProfile)..limit(1)).getSingleOrNull();
    final result = WimHofProgression.compute(
      progress: progress,
      allWimHofSessions: sessions,
      verifiedPbSec: freedivingProfile?.verifiedPbSec,
      detrainingDays: detrainingDaysOverride ?? kDetrainingDays,
      pbCautionRatio: pbCautionRatioOverride ?? kPbCautionRetentionRatio,
      maxAvgRpeToAdvance: maxAvgRpeToAdvanceOverride ?? kMaxAvgRpeToAdvance,
    );
    if (result.currentLevelKey != progress.currentLevelKey || result.resetTrialWindow) {
      await (_db.update(_db.wimHofProgress)..where((t) => t.id.equals(progress.id)))
          .write(WimHofProgressCompanion(
        currentLevelKey: Value(result.currentLevelKey),
        currentLevelSetAt: Value(DateTime.now()),
      ));
      await ProfileSyncMarker.markChanged();
    }
    return result;
  }
}
