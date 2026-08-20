import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:uuid/uuid.dart';

/// CRUD for user-defined custom freediving table presets.
class CustomFreedivingRepository {
  CustomFreedivingRepository(this._db);

  final AppDatabase _db;

  Future<int> addPreset({
    required String name,
    required int startApneaSec,
    required int endApneaSec,
    required int startRestSec,
    required int endRestSec,
    required int rounds,
    required DateTime createdAt,
  }) {
    return _db.into(_db.customFreedivingPresets).insert(
          CustomFreedivingPresetsCompanion.insert(
            name: name,
            startApneaSec: startApneaSec,
            endApneaSec: endApneaSec,
            startRestSec: startRestSec,
            endRestSec: endRestSec,
            rounds: rounds,
            createdAt: createdAt,
            syncId: Value(const Uuid().v4()),
          ),
        );
  }

  /// Soft-delete — see CustomPresetRepository.deletePreset for why.
  Future<void> deletePreset(int id) {
    return (_db.update(_db.customFreedivingPresets)..where((t) => t.id.equals(id)))
        .write(CustomFreedivingPresetsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Emits saved (non-deleted) presets, newest first.
  Stream<List<CustomFreedivingPreset>> watchPresets() {
    return (_db.select(_db.customFreedivingPresets)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// One-shot read of every preset, deleted ones included — used by
  /// SyncService to build a push payload.
  Future<List<CustomFreedivingPreset>> getAllIncludingDeleted() =>
      _db.select(_db.customFreedivingPresets).get();

  /// Applied during a sync pull — same pattern as
  /// CustomPresetRepository.upsertFromSync.
  Future<void> upsertFromSync({
    required String syncId,
    required String name,
    required int startApneaSec,
    required int endApneaSec,
    required int startRestSec,
    required int endRestSec,
    required int rounds,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) async {
    final existing = await (_db.select(_db.customFreedivingPresets)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    final fields = CustomFreedivingPresetsCompanion(
      name: Value(name),
      startApneaSec: Value(startApneaSec),
      endApneaSec: Value(endApneaSec),
      startRestSec: Value(startRestSec),
      endRestSec: Value(endRestSec),
      rounds: Value(rounds),
      deletedAt: Value(deletedAt),
    );
    if (existing != null) {
      await (_db.update(_db.customFreedivingPresets)..where((t) => t.id.equals(existing.id)))
          .write(fields);
      return;
    }
    await _db.into(_db.customFreedivingPresets).insert(CustomFreedivingPresetsCompanion.insert(
          name: name,
          startApneaSec: startApneaSec,
          endApneaSec: endApneaSec,
          startRestSec: startRestSec,
          endRestSec: endRestSec,
          rounds: rounds,
          createdAt: createdAt,
          syncId: Value(syncId),
          deletedAt: Value(deletedAt),
        ));
  }
}
