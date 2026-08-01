import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing app settings, persisted in SharedPreferences.
class Settings {
  const Settings({
    this.profileName = '',
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final String profileName;
  final bool soundEnabled;
  final bool hapticsEnabled;

  Settings copyWith({
    String? profileName,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return Settings(
      profileName: profileName ?? this.profileName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings()) {
    _load();
  }

  static const _kName = 'profile_name';
  static const _kSound = 'sound_enabled';
  static const _kHaptics = 'haptics_enabled';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = Settings(
      profileName: p.getString(_kName) ?? '',
      soundEnabled: p.getBool(_kSound) ?? true,
      hapticsEnabled: p.getBool(_kHaptics) ?? true,
    );
  }

  Future<void> setProfileName(String value) async {
    state = state.copyWith(profileName: value);
    (await SharedPreferences.getInstance()).setString(_kName, value);
  }

  Future<void> setSound(bool value) async {
    state = state.copyWith(soundEnabled: value);
    (await SharedPreferences.getInstance()).setBool(_kSound, value);
  }

  Future<void> setHaptics(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    (await SharedPreferences.getInstance()).setBool(_kHaptics, value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) => SettingsNotifier());
