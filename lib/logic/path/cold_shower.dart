import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/services/derived_gamification.dart';

/// The [Session.levelKey] used for a logged cold-shower exposure.
const String coldShowerLevelKey = 'cold_shower';

/// Minimum XP reward for a logged cold shower — the floor for entry points
/// with no duration UI of their own (the scheduler quick-start, the
/// home-screen widget), which log a plain 0 duration.
const int coldShowerXpReward = 15;

/// Same flat-XP-scaled-by-duration approach guided routines use (there's no
/// breath count to derive XP from here either) — a 15s log and a 10-minute
/// one used to earn the identical flat reward, which didn't reward actually
/// staying in longer. The floor keeps the no-duration entry points unchanged.
int coldShowerXpFor(int durationSec) =>
    (durationSec * 0.5).round().clamp(coldShowerXpReward, 1000);

/// What it takes to undo a logged cold shower — just the inserted session's
/// id. Undo no longer restores a pre-log profile snapshot (see
/// [undoColdShowerSession] for why), so nothing else needs to travel with it.
class ColdShowerLogResult {
  const ColdShowerLogResult({required this.sessionId});
  final int sessionId;
}

/// Logs a completed cold-shower exposure — the third pillar of the Wim Hof
/// method, alongside breathing and (already covered) commitment. Same
/// streak/history treatment as any other session.
///
/// [durationSec] is optional and purely informational — progression is
/// whatever the user chooses to log next time, not a forced ladder. Entry
/// points with no duration UI of their own (the scheduler quick-start, the
/// home-screen widget) simply omit it, matching the previous always-0
/// behavior.
Future<ColdShowerLogResult> logColdShowerSession(WidgetRef ref, {int durationSec = 0}) async {
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final now = DateTime.now();
  // Nothing stopped a 0-duration quick-log from being tapped repeatedly in
  // one day, each earning the same guaranteed floor XP and counting toward
  // the streak — a real way to farm both with zero time actually spent
  // under cold water. Only the day's first log earns XP/streak; later ones
  // in the same day are still recorded (so the day's real shower count
  // stays honest) but contribute neither.
  final todaysLogs = (await sessionRepo.getSessionsForLevel(coldShowerLevelKey))
      .where((s) =>
          s.timestamp.year == now.year &&
          s.timestamp.month == now.month &&
          s.timestamp.day == now.day)
      .isNotEmpty;

  var xpEarned = 0;
  if (!todaysLogs) {
    final gamification = ref.read(gamificationServiceProvider);
    final xpResult = await gamification.awardFlatXp(coldShowerXpFor(durationSec));
    await gamification.updateStreak();
    xpEarned = xpResult.xpEarned;
  }

  final sessionId = await sessionRepo.addSession(
    levelKey: coldShowerLevelKey,
    timestamp: now,
    durationSec: durationSec,
    rounds: 1,
    retentionSec: 0,
    xpEarned: xpEarned,
  );

  return ColdShowerLogResult(sessionId: sessionId);
}

/// Reverses [logColdShowerSession] within its undo window — deletes the
/// logged session, then recomputes totalXp/level/dailyStreak from the
/// *remaining* history instead of restoring a pre-log snapshot. A snapshot
/// restore is only correct if nothing else was logged in between; if
/// another session landed between the cold shower and the user tapping
/// Undo, restoring an absolute pre-log value would silently discard that
/// other session's XP/streak effect too. Recomputing from what's actually
/// left is correct regardless of what happened in between.
Future<void> undoColdShowerSession(WidgetRef ref, ColdShowerLogResult result) async {
  final sessionRepo = ref.read(sessionRepositoryProvider);
  await sessionRepo.deleteSession(result.sessionId);
  final remaining = await sessionRepo.getAllSessions();
  final derived = DerivedGamificationState.fromSessions(remaining);
  // Also needs fixing up: GamificationService.updateStreak() already
  // stamped lastSessionDate to "now" (when the shower was logged) before
  // this undo ran. Left as-is, it would make the *next* real session's
  // incremental day-gap calculation think the streak was touched more
  // recently than it actually was now that this entry is gone.
  DateTime? lastSessionDate;
  for (final s in remaining) {
    if (lastSessionDate == null || s.timestamp.isAfter(lastSessionDate)) {
      lastSessionDate = s.timestamp;
    }
  }
  await ref.read(userProfileRepositoryProvider).updateUserProfile(
        UserProfileCompanion(
          totalXp: Value(derived.totalXp),
          level: Value(derived.level),
          dailyStreak: Value(derived.dailyStreak),
          lastSessionDate: Value(lastSessionDate),
        ),
      );
}
