import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing app settings, persisted in SharedPreferences.
class Settings {
  const Settings({
    this.profileName = '',
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.dailyReminderEnabled = false,
  });

  final String profileName;
  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Whether the recurring "practice today" daily notification is active.
  /// This is the single source of truth for that reminder — see
  /// [SettingsNotifier.setDailyReminderEnabled].
  final bool dailyReminderEnabled;

  Settings copyWith({
    String? profileName,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? dailyReminderEnabled,
  }) {
    return Settings(
      profileName: profileName ?? this.profileName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier(this._ref) : super(const Settings()) {
    _load();
  }

  final Ref _ref;

  static const _kName = 'profile_name';
  static const _kSound = 'sound_enabled';
  static const _kHaptics = 'haptics_enabled';
  static const _kDailyReminder = 'daily_reminder_enabled';

  /// Older builds had a dead 'schedule_active' flag (from a since-replaced
  /// time-picker scheduler) that was never written, so a splash-screen guard
  /// that checked it always saw `false` and re-scheduled the recurring daily
  /// reminder on every cold start — with no way for the user to turn it off.
  /// This one-time migration cancels that orphaned OS-level alarm so existing
  /// installs start from a clean, honest "off" state that matches this toggle.
  static const _kMigratedV2 = 'daily_reminder_migrated_v2';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    if (!(p.getBool(_kMigratedV2) ?? false)) {
      try {
        await _ref.read(notificationServiceProvider).cancelDailyReminder();
      } catch (e, st) {
        developer.log('Daily reminder migration cancel failed',
            name: 'SettingsNotifier', error: e, stackTrace: st);
      }
      await p.setBool(_kMigratedV2, true);
      await p.setBool(_kDailyReminder, false);
    }

    state = Settings(
      profileName: p.getString(_kName) ?? '',
      soundEnabled: p.getBool(_kSound) ?? true,
      hapticsEnabled: p.getBool(_kHaptics) ?? true,
      dailyReminderEnabled: p.getBool(_kDailyReminder) ?? false,
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

  /// Turns the recurring daily reminder on or off, actually (re)scheduling or
  /// cancelling the OS-level alarm — this is the only place that should do so,
  /// so the toggle state and the real alarm can never drift apart.
  Future<void> setDailyReminderEnabled(
    bool value, {
    required String title,
    required String body,
  }) async {
    final notifications = _ref.read(notificationServiceProvider);
    if (value) {
      await notifications.init();
      await notifications.scheduleDailyReminder(title: title, body: body);
    } else {
      await notifications.cancelDailyReminder();
    }
    state = state.copyWith(dailyReminderEnabled: value);
    (await SharedPreferences.getInstance()).setBool(_kDailyReminder, value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
    (ref) => SettingsNotifier(ref));
