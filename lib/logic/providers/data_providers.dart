import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/custom_freediving_repository.dart';
import 'package:okrutnik_breath/data/repositories/custom_preset_repository.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/data/repositories/planner_repository.dart';
import 'package:okrutnik_breath/data/repositories/session_repository.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';
import 'package:okrutnik_breath/data/repositories/wimhof_repository.dart';
import 'package:okrutnik_breath/logic/freediving/freediving_progress.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart';
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/logic/services/gamification_service.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';

// Database
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Release the SQLite connection when the provider is disposed.
  ref.onDispose(db.close);
  return db;
});

// Repositories
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserProfileRepository(db);
});

/// Reactive user profile (level, XP, streak); null until the first session.
final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  return ref.watch(userProfileRepositoryProvider).watchUserProfileOrNull();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SessionRepository(db);
});

// Services
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return GamificationService(repo);
});

/// Reactive stream of the user's session history, newest first.
final sessionHistoryProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchSessions();
});

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository(ref.watch(databaseProvider));
});

/// Reactive stream of all planned sessions, soonest first.
final plannedSessionsProvider = StreamProvider<List<PlannedSession>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchPlans();
});

final customPresetRepositoryProvider = Provider<CustomPresetRepository>((ref) {
  return CustomPresetRepository(ref.watch(databaseProvider));
});

/// Reactive stream of saved custom breathing presets, newest first.
final customPresetsProvider = StreamProvider<List<CustomPreset>>((ref) {
  return ref.watch(customPresetRepositoryProvider).watchPresets();
});

final freedivingRepositoryProvider = Provider<FreedivingRepository>((ref) {
  return FreedivingRepository(ref.watch(databaseProvider));
});

final customFreedivingRepositoryProvider =
    Provider<CustomFreedivingRepository>((ref) {
  return CustomFreedivingRepository(ref.watch(databaseProvider));
});

/// Reactive stream of saved custom freediving table presets, newest first.
final customFreedivingPresetsProvider =
    StreamProvider<List<CustomFreedivingPreset>>((ref) {
  return ref.watch(customFreedivingRepositoryProvider).watchPresets();
});

/// Reactive freediving profile (verified/working PBs, safety-consent flag);
/// null only before the very first read (getProfile() lazily creates the row).
final freedivingProfileProvider =
    StreamProvider<FreedivingProfileData?>((ref) {
  return ref.watch(freedivingRepositoryProvider).watchProfile();
});

/// Reactive stream of recent freediving table sessions, newest first — used
/// by the weekly hard-session-load cap.
final freedivingRecentLogsProvider =
    StreamProvider<List<FreedivingSessionLogData>>((ref) {
  return ref.watch(freedivingRepositoryProvider).watchRecentLogs();
});

/// Recent-progress rollup for the Freediving tab's progress section — pure
/// derived data, computed from whatever [freedivingRecentLogsProvider]
/// already has, so it never needs its own persisted state.
final freedivingProgressProvider = Provider<FreedivingProgressSummary>((ref) {
  final logs = ref.watch(freedivingRecentLogsProvider).value ??
      const <FreedivingSessionLogData>[];
  return FreedivingProgressSummary.fromLogs(logs);
});

final wimHofRepositoryProvider = Provider<WimHofRepository>((ref) {
  return WimHofRepository(ref.watch(databaseProvider));
});

/// Re-evaluates Wim Hof ladder progression whenever session history changes
/// and persists any resulting level change; the emitted value reflects the
/// latest confirmed level and any "next up" recommendation.
final wimHofNextUpProvider = StreamProvider<WimHofNextUp>((ref) async* {
  final repo = ref.watch(wimHofRepositoryProvider);
  // Re-run whenever a session finishes — that's the only thing that can move
  // progression forward.
  ref.watch(sessionHistoryProvider);
  yield await repo.refresh();
});

/// Count of "hard" sessions (Wim Hof Beast/Okrutnik or a freediving O2 table)
/// in the trailing 7 days, for the soft weekly-load warning.
final weeklyHardSessionCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  final freedivingLogs =
      ref.watch(freedivingRecentLogsProvider).value ?? const <FreedivingSessionLogData>[];
  return countHardSessionsInPastWeek(sessions, freedivingLogs);
});

/// Reactive stream of every freediving table session ever logged — used for
/// the cumulative per-type counts the guided training path needs (a
/// recent-only window would undercount an established user).
final freedivingAllLogsProvider =
    StreamProvider<List<FreedivingSessionLogData>>((ref) {
  return ref.watch(freedivingRepositoryProvider).watchAllLogs();
});

/// The current stage and single "what to do today" recommendation for the
/// combined Wim Hof + CO2/O2 guided path ("Twoja Ścieżka"). Recomputes
/// whenever any of its underlying signals change.
final trainingPathProvider = Provider<PathState?>((ref) {
  final wimHof = ref.watch(wimHofNextUpProvider).value;
  final profile = ref.watch(freedivingProfileProvider).value;
  final logs = ref.watch(freedivingAllLogsProvider).value;
  if (wimHof == null || profile == null || logs == null) return null;

  final co2Count = logs.where((l) => l.tableType == 'co2').length;
  final o2Count = logs.where((l) => l.tableType == 'o2').length;
  final weeklyCapReached =
      ref.watch(weeklyHardSessionCountProvider) >= kWeeklyHardSessionCap;

  return TrainingPath.compute(
    wimHof: wimHof,
    pbVerified: profile.verifiedPbSec != null,
    co2SessionCount: co2Count,
    o2SessionCount: o2Count,
    weeklyCapReached: weeklyCapReached,
  );
});

/// The interleaved 7-day plan (today = index 0) across every discipline the
/// user has unlocked — the concrete "what to do, which day" layer underneath
/// the [trainingPathProvider]'s broader stage narrative.
final weeklyPlanProvider = Provider<WeeklyPlan?>((ref) {
  final wimHof = ref.watch(wimHofNextUpProvider).value;
  final profile = ref.watch(freedivingProfileProvider).value;
  if (wimHof == null || profile == null) return null;

  final settings = ref.watch(settingsProvider);
  return WeeklyPlanGenerator.compute(
    wimHof: wimHof,
    pbVerified: profile.verifiedPbSec != null,
    hardSessionsUsedThisWeek: ref.watch(weeklyHardSessionCountProvider),
    availableWeekdays: settings.availableWeekdays,
    allowMultiplePerDay: settings.allowMultipleSessionsPerDay,
    freedivingVisited: settings.hasVisitedFreediving,
  );
});

/// Whether a cold shower has already been logged today — the daily checklist
/// checkbox reflects this and can't be un-checked, since a logged session is
/// a real completed action, not a plain to-do toggle.
final coldShowerDoneTodayProvider = Provider<bool>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  final now = DateTime.now();
  return sessions.any((s) =>
      s.levelKey == coldShowerLevelKey &&
      s.timestamp.year == now.year &&
      s.timestamp.month == now.month &&
      s.timestamp.day == now.day);
});

/// The most recently logged cold-shower duration (seconds), or null if none
/// has ever been logged with a real duration yet (older logs, and every
/// non-Wim-Hof-tab entry point, stored 0) — seeds the duration stepper's
/// default so progression is a simple "start from last time", not a fixed
/// ladder the user has to follow.
final lastColdShowerDurationSecProvider = Provider<int?>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  for (final s in sessions) {
    if (s.levelKey == coldShowerLevelKey && s.durationSec > 0) return s.durationSec;
  }
  return null;
});
