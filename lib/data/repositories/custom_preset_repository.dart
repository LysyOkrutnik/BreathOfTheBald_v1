import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';

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
          ),
        );
  }

  Future<void> deletePreset(int id) {
    return (_db.delete(_db.customPresets)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<CustomPreset>> watchPresets() {
    return (_db.select(_db.customPresets)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
