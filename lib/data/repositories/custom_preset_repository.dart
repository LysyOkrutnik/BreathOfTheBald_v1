import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:uuid/uuid.dart';

/// CRUD for user-defined breathing presets (the custom-session builder).
class CustomPresetRepository {
  CustomPresetRepository(this._db);

  final AppDatabase _db;

  Future<int> addPreset({
    required String name,
    required int inhaleSec,
    required int holdInSec,
    required int exhaleSec,
    required int holdOutSec,
    required int cycles,
    required int rounds,
    required DateTime createdAt,
  }) {
    return _db.into(_db.customPresets).insert(
          CustomPresetsCompanion.insert(
            name: name,
            inhaleSec: inhaleSec,
            holdInSec: Value(holdInSec),
            exhaleSec: exhaleSec,
            holdOutSec: Value(holdOutSec),
            cycles: Value(cycles),
            rounds: Value(rounds),
            createdAt: createdAt,
            syncId: Value(const Uuid().v4()),
          ),
        );
  }

  /// Soft-delete — sets [deletedAt] instead of removing the row outright, so
  /// the deletion propagates to other devices on next sync rather than the
  /// server's still-active copy silently reappearing here.
  Future<void> deletePreset(int id) {
    return (_db.update(_db.customPresets)..where((t) => t.id.equals(id)))
        .write(CustomPresetsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Emits saved (non-deleted) presets, newest first.
  Stream<List<CustomPreset>> watchPresets() {
    return (_db.select(_db.customPresets)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// One-shot read of every preset, deleted ones included — used by
  /// SyncService to build a push payload (a soft-deleted row still needs to
  /// be pushed so the server learns about the deletion).
  Future<List<CustomPreset>> getAllIncludingDeleted() =>
      _db.select(_db.customPresets).get();

  /// Applied during a sync pull: inserts a preset that originated on another
  /// device, or overwrites the existing local row (including a pulled
  /// [deletedAt], which is exactly how a deletion on another device
  /// propagates here) — matched by [syncId].
  Future<void> upsertFromSync({
    required String syncId,
    required String name,
    required int inhaleSec,
    required int holdInSec,
    required int exhaleSec,
    required int holdOutSec,
    required int cycles,
    required int rounds,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) async {
    final existing = await (_db.select(_db.customPresets)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
    final fields = CustomPresetsCompanion(
      name: Value(name),
      inhaleSec: Value(inhaleSec),
      holdInSec: Value(holdInSec),
      exhaleSec: Value(exhaleSec),
      holdOutSec: Value(holdOutSec),
      cycles: Value(cycles),
      rounds: Value(rounds),
      deletedAt: Value(deletedAt),
    );
    if (existing != null) {
      await (_db.update(_db.customPresets)..where((t) => t.id.equals(existing.id))).write(fields);
      return;
    }
    await _db.into(_db.customPresets).insert(CustomPresetsCompanion.insert(
          name: name,
          inhaleSec: inhaleSec,
          holdInSec: Value(holdInSec),
          exhaleSec: exhaleSec,
          holdOutSec: Value(holdOutSec),
          cycles: Value(cycles),
          rounds: Value(rounds),
          createdAt: createdAt,
          syncId: Value(syncId),
          deletedAt: Value(deletedAt),
        ));
  }
}
