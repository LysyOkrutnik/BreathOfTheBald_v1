import 'package:shared_preferences/shared_preferences.dart';

/// Tracks when the local, singleton "ProfileState" data (PB verification,
/// safety consent, confirmed Wim Hof level, weekly-plan preferences) last
/// actually changed — the timestamp SyncService pushes so the server can
/// last-write-wins it against whatever another device already pushed.
///
/// A free-standing helper (not a class needing DI) so every write site —
/// scattered across SettingsNotifier, FreedivingRepository, WimHofRepository
/// — can call it without a dependency on the sync feature itself.
abstract final class ProfileSyncMarker {
  static const _key = 'sync_profile_client_updated_at';

  /// Call right after writing any ProfileState-relevant field locally.
  static Future<void> markChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
  }

  /// Epoch (very old) if nothing has ever changed locally — a first sync
  /// should still push whatever the local defaults are rather than being
  /// skipped for "no timestamp".
  static Future<DateTime> lastChangedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_key);
    return iso == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.parse(iso);
  }
}
