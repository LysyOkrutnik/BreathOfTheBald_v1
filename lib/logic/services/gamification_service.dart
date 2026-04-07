import 'package:drift/drift.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';

class GamificationService {
  final UserProfileRepository _profileRepository;

  GamificationService(this._profileRepository);

  Future<void> updateXpAndLevel({
    required int breathCount,
    required int retentionSeconds,
    required double multiplier,
  }) async {
    final profile = await _profileRepository.getUserProfile();

    // Calculate XP earned for the session.
    final int xpEarned = (breathCount * multiplier).round() + (retentionSeconds * 2);
    final int newTotalXp = profile.totalXp + xpEarned;

    // Check for level up.
    int newLevel = profile.level;
    int xpForNextLevel = newLevel * 500;

    while (newTotalXp >= xpForNextLevel) {
      newLevel++;
      xpForNextLevel = newLevel * 500;
    }

    await _profileRepository.updateUserProfile(
      UserProfileCompanion(
        totalXp: Value(newTotalXp),
        level: Value(newLevel),
      ),
    );
  }

  Future<void> updateStreak() async {
    final profile = await _profileRepository.getUserProfile();
    final now = DateTime.now();
    final lastSession = profile.lastSessionDate;

    int newStreak = profile.dailyStreak;

    if (lastSession != null) {
      final difference = now.difference(lastSession);
      if (difference.inHours > 24 && difference.inHours <= 48) {
        newStreak++;
      } else if (difference.inHours > 48) {
        newStreak = 1; // Reset streak
      }
      // If less than 24h, streak remains the same.
    } else {
      newStreak = 1; // First session
    }

    await _profileRepository.updateUserProfile(
      UserProfileCompanion(
        dailyStreak: Value(newStreak),
        lastSessionDate: Value(now),
      ),
    );
  }
}
