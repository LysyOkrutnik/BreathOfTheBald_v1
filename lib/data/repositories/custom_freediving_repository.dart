import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';

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
          ),
        );
  }

  Future<void> deletePreset(int id) {
    return (_db.delete(_db.customFreedivingPresets)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Emits saved presets, newest first.
  Stream<List<CustomFreedivingPreset>> watchPresets() {
    return (_db.select(_db.customFreedivingPresets)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
