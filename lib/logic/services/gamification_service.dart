import 'package:drift/drift.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';

/// Which broad practice family a level belongs to, for the weekly diversity
/// bonus below — coarser than [ExerciseType] (a Wim Hof session and a
/// custom breathing pattern both count as the same "breathing" family).
/// Null for a levelKey this can't place (defensive only — every real
/// session's levelKey should match one of these).
String? disciplineFamilyFor(String levelKey) {
  // Literal 'cold_shower' rather than importing cold_shower.dart's
  // coldShowerLevelKey constant — that file already imports
  // data_providers.dart, which imports levels.dart, which this file also
  // imports; importing it here too would complete a cycle for one constant.
  if (levelKey == 'cold_shower') return 'cold';
  // Freediving tables/PB test/packing/custom-freediving all key off this
  // prefix (or the exact 'custom_freediving' key) regardless of whichever
  // ExerciseType they're built with — packing in particular is
  // ExerciseType.guidedRoutine, same as the Mobility-tab exercises, but is
  // clearly a freediving discipline, not a mobility one.
  if (levelKey.startsWith('freediving_') || levelKey == 'custom_freediving') {
    return 'freediving';
  }
  final type = LevelData.levels[levelKey]?.type;
  switch (type) {
    case ExerciseType.wimHof:
    case ExerciseType.custom:
    case ExerciseType.boxBreathing:
    case ExerciseType.relax478:
    case ExerciseType.fireBreathing:
      return 'breathing';
    case ExerciseType.guidedRoutine:
      return 'mobility';
    case ExerciseType.co2Table:
    case ExerciseType.o2Table:
    case ExerciseType.customFreedivingTable:
      return 'freediving';
    case ExerciseType.coldShower:
      return 'cold';
    case null:
      return null;
  }
}

/// A small XP bonus for training multiple distinct disciplines in the same
/// week instead of only ever rewarding volume within one — Twoja Ścieżka's
/// weekly plan already deliberately interleaves disciplines (Wim Hof,
/// CO2/O2, cold shower, mobility), but XP never reflected that variety at
/// all before this.
double diversityXpMultiplier(int distinctFamiliesThisWeek) {
  if (distinctFamiliesThisWeek >= 4) return 1.25;
  if (distinctFamiliesThisWeek >= 3) return 1.15;
  return 1.0;
}

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

  /// Applies the XP and level gains for a finished session. [bonusMultiplier]
  /// scales the whole computed amount (e.g. the weekly discipline-diversity
  /// bonus — see [diversityXpMultiplier]) — unlike [multiplier], which only
  /// scales the breath-count term, a bonus for training variety should apply
  /// to the session's real earned XP as a whole, retention included.
  Future<XpResult> updateXpAndLevel({
    required int breathCount,
    required int retentionSeconds,
    required double multiplier,
    double bonusMultiplier = 1.0,
  }) async {
    final xpEarned =
        (((breathCount * multiplier).round() + (retentionSeconds * 2)) * bonusMultiplier)
            .round();
    return _applyXp(xpEarned);
  }

  /// Applies a fixed XP amount directly — for activities with no natural
  /// breath-count/duration to derive XP from (e.g. a logged cold shower).
  Future<XpResult> awardFlatXp(int amount, {double bonusMultiplier = 1.0}) =>
      _applyXp((amount * bonusMultiplier).round());

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
