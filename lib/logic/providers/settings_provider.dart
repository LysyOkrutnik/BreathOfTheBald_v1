import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/logic/path/weekly_plan.dart' show kAllWeekdays;
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing app settings, persisted in SharedPreferences.
class Settings {
  const Settings({
    this.profileName = '',
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.dailyReminderEnabled = false,
    this.availableWeekdays = kAllWeekdays,
    this.availableHourStart = 6,
    this.availableHourEnd = 21,
    this.allowMultipleSessionsPerDay = true,
    this.hasVisitedFreediving = false,
  });

  final String profileName;
  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Whether the recurring "practice today" daily notification is active.
  /// This is the single source of truth for that reminder — see
  /// [SettingsNotifier.setDailyReminderEnabled].
  final bool dailyReminderEnabled;

  /// Which weekdays (1=Monday..7=Sunday) Twoja Ścieżka is allowed to place a
  /// session on. Unset days are a hard guarantee of rest, not just a gap the
  /// interleaving happened to leave — the default of every day lets the
  /// weekly plan generator fall back to its own single reserved rest day.
  final Set<int> availableWeekdays;

  /// The daily window (hour of day, 0-23) Twoja Ścieżka is allowed to place
  /// sessions in when bulk-planning the week — a day's sessions are spread
  /// evenly across [availableHourStart, availableHourEnd], never outside it.
  final int availableHourStart;
  final int availableHourEnd;

  /// Whether the weekly plan may stack more than one session on the same
  /// day when the available days don't fit everything one-per-day. When
  /// false, lower-priority sessions are dropped for the week instead of
  /// being doubled up.
  final bool allowMultipleSessionsPerDay;

  /// True once the Freediving tab has been opened at least once — gates
  /// Twoja Ścieżka's weekly plan from scheduling a "Test PB" slot before the
  /// user has ever seen where PB tests and the term itself actually live.
  final bool hasVisitedFreediving;

  Settings copyWith({
    String? profileName,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? dailyReminderEnabled,
    Set<int>? availableWeekdays,
    int? availableHourStart,
    int? availableHourEnd,
    bool? allowMultipleSessionsPerDay,
    bool? hasVisitedFreediving,
  }) {
    return Settings(
      profileName: profileName ?? this.profileName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      availableWeekdays: availableWeekdays ?? this.availableWeekdays,
      availableHourStart: availableHourStart ?? this.availableHourStart,
      availableHourEnd: availableHourEnd ?? this.availableHourEnd,
      allowMultipleSessionsPerDay:
          allowMultipleSessionsPerDay ?? this.allowMultipleSessionsPerDay,
      hasVisitedFreediving: hasVisitedFreediving ?? this.hasVisitedFreediving,
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

  /// Bitmask over weekdays 1-7 (bit `weekday - 1`) — absent means "every day",
  /// matching [Settings.availableWeekdays]'s default.
  static const _kAvailableWeekdaysMask = 'path_available_weekdays_mask';
  static const _kAvailableHourStart = 'path_available_hour_start';
  static const _kAvailableHourEnd = 'path_available_hour_end';
  static const _kAllowMultiplePerDay = 'path_allow_multiple_sessions_per_day';
  static const _kHasVisitedFreediving = 'has_visited_freediving';

  /// Older builds had a dead 'schedule_active' flag (from a since-replaced
  /// time-picker scheduler) that was never written, so a splash-screen guard
  /// that checked it always saw `false` and re-scheduled the recurring daily
  /// reminder on every cold start — with no way for the user to turn it off.
  /// This one-time migration cancels that orphaned OS-level alarm so existing
  /// installs start from a clean, honest "off" state that matches this toggle.
  static const _kMigratedV2 = 'daily_reminder_migrated_v2';

  /// True for exactly one app run — the one in which [_load] actually
  /// performed the migration above — so the UI can tell an affected user
  /// their reminder was just turned off, instead of it silently vanishing.
  bool _reminderMigrationJustRan = false;

  /// Consumes (returns and clears) the one-time migration notice. Safe to
  /// call speculatively on every app start — it's only ever true once, on
  /// the run that actually performed the cancellation above.
  bool consumeReminderMigrationNotice() {
    final result = _reminderMigrationJustRan;
    _reminderMigrationJustRan = false;
    return result;
  }

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
      _reminderMigrationJustRan = true;
    }

    state = Settings(
      profileName: p.getString(_kName) ?? '',
      soundEnabled: p.getBool(_kSound) ?? true,
      hapticsEnabled: p.getBool(_kHaptics) ?? true,
      dailyReminderEnabled: p.getBool(_kDailyReminder) ?? false,
      availableWeekdays: _weekdaysFromMask(p.getInt(_kAvailableWeekdaysMask)),
      availableHourStart: p.getInt(_kAvailableHourStart) ?? 6,
      availableHourEnd: p.getInt(_kAvailableHourEnd) ?? 21,
      allowMultipleSessionsPerDay: p.getBool(_kAllowMultiplePerDay) ?? true,
      hasVisitedFreediving: p.getBool(_kHasVisitedFreediving) ?? false,
    );
  }

  static Set<int> _weekdaysFromMask(int? mask) {
    if (mask == null) return kAllWeekdays;
    return {for (var weekday = 1; weekday <= 7; weekday++)
        if (mask & (1 << (weekday - 1)) != 0) weekday};
  }

  static int _maskFromWeekdays(Set<int> weekdays) =>
      weekdays.fold(0, (mask, weekday) => mask | (1 << (weekday - 1)));

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

  /// Persists Twoja Ścieżka's weekly-plan preferences in one go — they're
  /// edited together from a single settings sheet.
  Future<void> setWeekPreferences({
    required Set<int> availableWeekdays,
    required int availableHourStart,
    required int availableHourEnd,
    required bool allowMultipleSessionsPerDay,
  }) async {
    state = state.copyWith(
      availableWeekdays: availableWeekdays,
      availableHourStart: availableHourStart,
      availableHourEnd: availableHourEnd,
      allowMultipleSessionsPerDay: allowMultipleSessionsPerDay,
    );
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kAvailableWeekdaysMask, _maskFromWeekdays(availableWeekdays));
    await p.setInt(_kAvailableHourStart, availableHourStart);
    await p.setInt(_kAvailableHourEnd, availableHourEnd);
    await p.setBool(_kAllowMultiplePerDay, allowMultipleSessionsPerDay);
  }

  /// Marks the Freediving tab as visited at least once — a one-way flag,
  /// never cleared. No-ops if already set, so it's cheap to call on every
  /// build of that tab's root screen.
  Future<void> markFreedivingVisited() async {
    if (state.hasVisitedFreediving) return;
    state = state.copyWith(hasVisitedFreediving: true);
    (await SharedPreferences.getInstance()).setBool(_kHasVisitedFreediving, true);
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
