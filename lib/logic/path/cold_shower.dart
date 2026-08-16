import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';

/// The [Session.levelKey] used for a logged cold-shower exposure.
const String coldShowerLevelKey = 'cold_shower';

/// Flat XP reward for a logged cold shower — there's no duration or breath
/// count to derive XP from (the user picked a plain "mark done" flow over a
/// stopwatch), so this stands in for [GamificationService.updateXpAndLevel]'s
/// usual breathCount/retentionSeconds formula.
const int coldShowerXpReward = 15;

/// What it takes to fully undo a logged cold shower — the inserted session's
/// id, plus a snapshot of the profile fields it touched, taken right before
/// the log so [undoColdShowerSession] can restore the exact prior state
/// rather than trying to inverse-compute an XP/streak delta.
class ColdShowerLogResult {
  const ColdShowerLogResult({required this.sessionId, required this.previousProfile});
  final int sessionId;
  final UserProfileData previousProfile;
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
  final previousProfile = await ref.read(userProfileRepositoryProvider).getUserProfile();

  final gamification = ref.read(gamificationServiceProvider);
  final xpResult = await gamification.awardFlatXp(coldShowerXpReward);
  await gamification.updateStreak();
  final sessionId = await ref.read(sessionRepositoryProvider).addSession(
        levelKey: coldShowerLevelKey,
        timestamp: DateTime.now(),
        durationSec: durationSec,
        rounds: 1,
        retentionSec: 0,
        xpEarned: xpResult.xpEarned,
      );

  return ColdShowerLogResult(sessionId: sessionId, previousProfile: previousProfile);
}

/// Reverses [logColdShowerSession] within its undo window — deletes the
/// logged session and restores the profile fields it touched (XP, level,
/// streak, last-session date) to their exact pre-log values.
Future<void> undoColdShowerSession(WidgetRef ref, ColdShowerLogResult result) async {
  await ref.read(sessionRepositoryProvider).deleteSession(result.sessionId);
  await ref.read(userProfileRepositoryProvider).updateUserProfile(
        UserProfileCompanion(
          totalXp: Value(result.previousProfile.totalXp),
          level: Value(result.previousProfile.level),
          dailyStreak: Value(result.previousProfile.dailyStreak),
          lastSessionDate: Value(result.previousProfile.lastSessionDate),
        ),
      );
}
