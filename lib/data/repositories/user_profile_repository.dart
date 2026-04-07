import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';

class UserProfileRepository {
  final AppDatabase _db;

  UserProfileRepository(this._db);

  Future<UserProfileData> getUserProfile() async {
    // Ensure a profile exists, creating one if it doesn't.
    final profile = await (_db.select(_db.userProfile)..limit(1)).getSingleOrNull();
    if (profile == null) {
      final newProfile = UserProfileCompanion.insert(id: const Value(1));
      await _db.into(_db.userProfile).insert(newProfile);
      return await (_db.select(_db.userProfile)..limit(1)).getSingle();
    }
    return profile;
  }

  Stream<UserProfileData> watchUserProfile() {
    return (_db.select(_db.userProfile)..limit(1)).watchSingle();
  }

  Future<void> updateUserProfile(UserProfileCompanion entry) async {
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(1))).write(entry);
  }
}

// Provider for the repository will be added later.
