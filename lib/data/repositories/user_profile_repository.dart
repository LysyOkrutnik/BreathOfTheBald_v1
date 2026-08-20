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
      // insertOrIgnore, not insert: two near-simultaneous first calls (quite
      // plausible right at app startup, from independent providers) could
      // both see `profile == null` above and both reach this insert with
      // the same fixed id=1 — a plain insert would throw a primary-key
      // uniqueness violation for the loser. Ignoring that conflict and just
      // re-reading below is fine either way: whichever row exists now is a
      // fresh-default profile regardless of which call created it.
      await _db.into(_db.userProfile).insert(newProfile, mode: InsertMode.insertOrIgnore);
      return await (_db.select(_db.userProfile)..limit(1)).getSingle();
    }
    return profile;
  }

  Stream<UserProfileData> watchUserProfile() {
    return (_db.select(_db.userProfile)..limit(1)).watchSingle();
  }

  /// Like [watchUserProfile] but emits null instead of throwing when no profile
  /// row exists yet (e.g. before the first completed session).
  Stream<UserProfileData?> watchUserProfileOrNull() {
    return (_db.select(_db.userProfile)..limit(1)).watchSingleOrNull();
  }

  Future<void> updateUserProfile(UserProfileCompanion entry) async {
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(1))).write(entry);
  }

  /// Part of the "reset progress" flow.
  Future<void> resetProgress() => updateUserProfile(const UserProfileCompanion(
        level: Value(1),
        totalXp: Value(0),
        dailyStreak: Value(0),
        lastSessionDate: Value(null),
      ));
}

// Provider for the repository will be added later.
