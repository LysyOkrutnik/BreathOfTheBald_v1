import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';

/// CRUD for calendar-planned breathing sessions.
class PlannerRepository {
  PlannerRepository(this._db);

  final AppDatabase _db;

  Future<int> addPlan({
    required DateTime scheduledAt,
    required String levelKey,
    int? estimatedDurationSec,
  }) {
    return _db.into(_db.plannedSessions).insert(
          PlannedSessionsCompanion.insert(
            scheduledAt: scheduledAt,
            levelKey: levelKey,
            estimatedDurationSec: Value(estimatedDurationSec),
          ),
        );
  }

  Future<void> deletePlan(int id) {
    return (_db.delete(_db.plannedSessions)..where((t) => t.id.equals(id))).go();
  }

  /// All planned sessions, soonest first.
  Stream<List<PlannedSession>> watchPlans() {
    return (_db.select(_db.plannedSessions)
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]))
        .watch();
  }
}
