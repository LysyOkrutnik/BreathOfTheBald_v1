import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';

/// Cumulative XP required to advance from [level] to [level] + 1.
///
/// Grows quadratically (500, 1500, 3000, 5000, ...) rather than the flat
/// `level * 500` this used to be — a flat step means every level costs the
/// same, so at a roughly constant XP/session rate a user would level up
/// almost every single session forever. That's fine unnoticed as a static
/// number, but it turns an active level-up celebration into spam rather than
/// an earned moment. The first step stays 500 (an early, quick first win);
/// later ones grow apart on purpose.
int xpToAdvanceFromLevel(int level) => 250 * level * (level + 1);

/// Outcome of an XP-earning action — carries the before/after level so a
/// caller can detect (and celebrate) a level-up without a second read.
class XpResult {
  const XpResult({
    required this.xpEarned,
    required this.previousLevel,
    required this.newLevel,
  });

  final int xpEarned;
  final int previousLevel;
  final int newLevel;

  bool get leveledUp => newLevel > previousLevel;
}

/// Outcome of a streak update — flags the one-day grace so a caller can
/// acknowledge it rather than leaving the streak's survival unexplained.
class StreakResult {
  const StreakResult({required this.streak, required this.graceUsed});

  final int streak;
  final bool graceUsed;
}

class GamificationService {
  final UserProfileRepository _profileRepository;

  GamificationService(this._profileRepository);

  /// Applies the XP and level gains for a finished session.
  Future<XpResult> updateXpAndLevel({
    required int breathCount,
    required int retentionSeconds,
    required double multiplier,
  }) async {
    final xpEarned = (breathCount * multiplier).round() + (retentionSeconds * 2);
    return _applyXp(xpEarned);
  }

  /// Applies a fixed XP amount directly — for activities with no natural
  /// breath-count/duration to derive XP from (e.g. a logged cold shower).
  Future<XpResult> awardFlatXp(int amount) => _applyXp(amount);

  Future<XpResult> _applyXp(int xpEarned) async {
    final profile = await _profileRepository.getUserProfile();
    final newTotalXp = profile.totalXp + xpEarned;

    // Derive the level purely from total XP (not the stored level) so it can
    // never drift out of sync after a missed write.
    int newLevel = 1;
    while (newTotalXp >= xpToAdvanceFromLevel(newLevel)) {
      newLevel++;
    }

    await _profileRepository.updateUserProfile(
      UserProfileCompanion(
        totalXp: Value(newTotalXp),
        level: Value(newLevel),
      ),
    );

    return XpResult(xpEarned: xpEarned, previousLevel: profile.level, newLevel: newLevel);
  }

  /// One missed day doesn't reset the streak — training every single day
  /// with zero tolerance is a harsh bar, and a silent, unexplained reset
  /// after a single busy day is exactly the kind of thing that makes people
  /// give up on a streak altogether once it's "ruined". Missing two or more
  /// days in a row still resets it.
  Future<StreakResult> updateStreak() async {
    final profile = await _profileRepository.getUserProfile();
    final now = DateTime.now();
    final lastSession = profile.lastSessionDate;

    int newStreak;
    var graceUsed = false;
    if (lastSession == null) {
      newStreak = 1; // First ever session.
    } else {
      // Compare calendar days, not elapsed hours: a session late one evening
      // and early the next morning are on consecutive days and must count.
      final today = DateTime(now.year, now.month, now.day);
      final lastDay =
          DateTime(lastSession.year, lastSession.month, lastSession.day);
      final dayGap = today.difference(lastDay).inDays;

      if (dayGap == 0) {
        newStreak = profile.dailyStreak; // Another session the same day.
      } else if (dayGap == 1) {
        newStreak = profile.dailyStreak + 1; // Consecutive day.
      } else if (dayGap == 2) {
        newStreak = profile.dailyStreak; // One missed day, forgiven.
        graceUsed = true;
      } else {
        newStreak = 1; // Two or more days missed; streak resets.
      }
    }

    final newBest =
        newStreak > profile.bestStreak ? newStreak : profile.bestStreak;
    await _profileRepository.updateUserProfile(
      UserProfileCompanion(
        dailyStreak: Value(newStreak),
        lastSessionDate: Value(now),
        bestStreak: Value(newBest),
      ),
    );

    return StreakResult(streak: newStreak, graceUsed: graceUsed);
  }
}
