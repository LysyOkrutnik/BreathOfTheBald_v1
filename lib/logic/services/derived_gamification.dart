import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/services/gamification_service.dart';

/// Recomputed from the full local session history — needed after a sync
/// pull, since sessions merged in from another device never went through
/// [GamificationService]'s incremental updateXpAndLevel/updateStreak calls
/// (those only ever fire for a session that just finished on this device).
class DerivedGamificationState {
  const DerivedGamificationState({
    required this.totalXp,
    required this.level,
    required this.dailyStreak,
  });

  final int totalXp;
  final int level;
  final int dailyStreak;

  /// [dailyStreak] here is the longest run of consecutive calendar days (up
  /// to and including the most recent one) with at least one session — no
  /// one-day grace, unlike the incremental version. On a single device with
  /// no pending grace day this always agrees with the incremental value; the
  /// only place it can differ is while the user is currently sitting inside
  /// a just-forgiven gap, where this reads one day short until their next
  /// session. An accepted simplification: replicating the incremental
  /// grace's exact history-dependent behavior from a merged multi-device
  /// dataset isn't worth the complexity for a cosmetic streak number.
  static DerivedGamificationState fromSessions(List<Session> sessions) {
    final totalXp = sessions.fold<int>(0, (sum, s) => sum + s.xpEarned);

    var level = 1;
    while (totalXp >= xpToAdvanceFromLevel(level)) {
      level++;
    }

    final days = sessions.map((s) {
      final t = s.timestamp;
      return DateTime(t.year, t.month, t.day);
    }).toSet();

    var streak = 0;
    if (days.isNotEmpty) {
      final now = DateTime.now();
      var cursor = DateTime(now.year, now.month, now.day);
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    return DerivedGamificationState(totalXp: totalXp, level: level, dailyStreak: streak);
  }
}
