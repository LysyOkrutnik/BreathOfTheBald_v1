import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/custom_freediving_repository.dart';
import 'package:okrutnik_breath/data/repositories/custom_preset_repository.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/data/repositories/planner_repository.dart';
import 'package:okrutnik_breath/data/repositories/session_repository.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';
import 'package:okrutnik_breath/data/repositories/wimhof_repository.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/logic/freediving/freediving_progress.dart';
import 'package:okrutnik_breath/logic/freediving/pb_readiness.dart';
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
  final settings = ref.watch(settingsProvider);
  yield await repo.refresh(
    detrainingDaysOverride: settings.detrainingDaysOverride,
    pbCautionRatioOverride: settings.pbCautionRatioOverride,
    maxAvgRpeToAdvanceOverride: settings.maxAvgRpeToAdvanceOverride,
    maxAvgRpeToConfirmTrialOverride: settings.maxAvgRpeToConfirmTrialOverride,
    pbRetestDaysOverride: settings.pbRetestDaysOverride,
    readinessIntermediateSecOverride: settings.readinessIntermediateSecOverride,
    readinessAdvancedSecOverride: settings.readinessAdvancedSecOverride,
  );
});

/// The single source of truth for "where does the user stand relative to
/// the Max PB Test" — CO2/O2 unlock, the Wim Hof ladder's climb past
/// `mild`, and the cold-shower hint all read this instead of each
/// independently re-deriving their own notion of "has PB".
final freedivingReadinessProvider = Provider<PbReadiness?>((ref) {
  final profile = ref.watch(freedivingProfileProvider).value;
  if (profile == null) return null;
  final settings = ref.watch(settingsProvider);
  return PbReadiness.compute(
    profile: profile,
    retestRequiredDays: settings.pbRetestDaysOverride ?? kPbRetestRequiredDays,
    intermediateSec: settings.readinessIntermediateSecOverride ?? kReadinessIntermediateSec,
    advancedSec: settings.readinessAdvancedSecOverride ?? kReadinessAdvancedSec,
  );
});

/// The trailing 7 days of freediving logs, unbounded by count — unlike
/// [freedivingRecentLogsProvider]'s fixed `limit`, this can't silently drop
/// an in-window session for a user prolific enough to log more than that
/// limit within a week.
final freedivingLogsPastWeekProvider =
    StreamProvider<List<FreedivingSessionLogData>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  return ref.watch(freedivingRepositoryProvider).watchLogsSince(cutoff);
});

/// Count of "hard" sessions (Wim Hof Beast/Okrutnik or a freediving O2 table)
/// in the trailing 7 days, for the soft weekly-load warning.
final weeklyHardSessionCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  final freedivingLogs =
      ref.watch(freedivingLogsPastWeekProvider).value ?? const <FreedivingSessionLogData>[];
  return countHardSessionsInPastWeek(sessions, freedivingLogs);
});

/// How many gulps ("top-ups") today's packing session should use, based on
/// how many packing sessions the user has already completed — see
/// [packingGulpCountFor].
final packingGulpCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  final completed = sessions.where((s) => s.levelKey == 'freediving_packing').length;
  return packingGulpCountFor(completed);
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

  // A lifetime cumulative count never got smaller — someone who did 5 CO2
  // sessions two years ago and hasn't touched a table since would sail
  // straight into "Adaptacja O2"/"Zaawansowany" on their first table this
  // year, same as someone training every week, with no notion of
  // deconditioning at all (unlike the Wim Hof ladder's kDetrainingDays).
  // Counting only sessions within a rolling window gets the same
  // regression effect for free, without needing new persisted state the
  // way the Wim Hof ladder's rollback does: stop training a table for
  // long enough and its count on its own drifts back under the threshold.
  final freedivingRecencyWindow = const Duration(days: 90);
  final recencyFloor = DateTime.now().subtract(freedivingRecencyWindow);
  final co2Count = logs
      .where((l) => l.tableType == 'co2' && l.timestamp.isAfter(recencyFloor))
      .length;
  final o2Count = logs
      .where((l) => l.tableType == 'o2' && l.timestamp.isAfter(recencyFloor))
      .length;
  final weeklyCap =
      ref.watch(settingsProvider).weeklyHardCapOverride ?? kWeeklyHardSessionCap;
  final weeklyCapReached = ref.watch(weeklyHardSessionCountProvider) >= weeklyCap;

  final readiness = ref.watch(freedivingReadinessProvider);
  return TrainingPath.compute(
    wimHof: wimHof,
    pbVerified: readiness?.isActive ?? false,
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
  final readiness = ref.watch(freedivingReadinessProvider);
  return WeeklyPlanGenerator.compute(
    wimHof: wimHof,
    pbVerified: readiness?.isActive ?? false,
    hardSessionsUsedThisWeek: ref.watch(weeklyHardSessionCountProvider),
    availableWeekdays: settings.availableWeekdays,
    allowMultiplePerDay: settings.allowMultipleSessionsPerDay,
    freedivingVisited: settings.hasVisitedFreediving,
    weeklyHardSessionCap: settings.weeklyHardCapOverride ?? kWeeklyHardSessionCap,
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

/// Storage keys (see `plannableStorageKeyFor`) of every session already
/// logged today — the Dziś tab's `_TodayCard` uses this to visually mark a
/// suggested action as done instead of it just sitting there identical to
/// an untouched one after the user actually completes it. Same idea as
/// [coldShowerDoneTodayProvider], generalized: every non-cold-shower action
/// type here logs into the same generic [Session] history under the exact
/// key `plannableStorageKeyFor` would derive for it (confirmed for CO2/O2
/// tables too — `LevelData.freedivingTable`'s generated level reuses the
/// fixed `'freediving_co2'`/`'freediving_o2'` key, not a synthetic one).
final todayCompletedActionKeysProvider = Provider<Set<String>>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  final now = DateTime.now();
  return {
    for (final s in sessions)
      if (s.timestamp.year == now.year &&
          s.timestamp.month == now.month &&
          s.timestamp.day == now.day)
        s.levelKey,
  };
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

/// Cold shower had no progress surface at all beyond defaulting the
/// duration stepper to last time's value — a simple rolling count is enough
/// to show the habit is actually building, without a whole dedicated
/// trend screen like freediving's.
final coldShowerMonthCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return sessions
      .where((s) => s.levelKey == coldShowerLevelKey && s.timestamp.isAfter(cutoff))
      .length;
});
