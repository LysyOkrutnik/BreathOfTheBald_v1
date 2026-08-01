import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';

class GamificationService {
  final UserProfileRepository _profileRepository;

  GamificationService(this._profileRepository);

  /// Applies the XP and level gains for a finished session and returns the
  /// amount of XP that was earned, so the caller can persist it on the session.
  Future<int> updateXpAndLevel({
    required int breathCount,
    required int retentionSeconds,
    required double multiplier,
  }) async {
    final profile = await _profileRepository.getUserProfile();

    // Calculate XP earned for the session.
    final int xpEarned = (breathCount * multiplier).round() + (retentionSeconds * 2);
    final int newTotalXp = profile.totalXp + xpEarned;

    // Each level N is reached at a cumulative total of N * 500 XP. Derive the
    // level purely from total XP (not the stored level) so it can never drift
    // out of sync after a missed write.
    int newLevel = 1;
    while (newTotalXp >= newLevel * 500) {
      newLevel++;
    }

    await _profileRepository.updateUserProfile(
      UserProfileCompanion(
        totalXp: Value(newTotalXp),
        level: Value(newLevel),
      ),
    );

    return xpEarned;
  }

  Future<void> updateStreak() async {
    final profile = await _profileRepository.getUserProfile();
    final now = DateTime.now();
    final lastSession = profile.lastSessionDate;

    int newStreak;
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
      } else {
        newStreak = 1; // A day (or more) was missed; streak resets.
      }
    }

    await _profileRepository.updateUserProfile(
      UserProfileCompanion(
        dailyStreak: Value(newStreak),
        lastSessionDate: Value(now),
      ),
    );
  }
}
