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

  /// [dailyStreak] here is the longest run of consecutive calendar days,
  /// ending at the most recent day with a session — no one-day grace,
  /// unlike the incremental version. On a single device with no pending
  /// grace day this always agrees with the incremental value; the only
  /// place it can differ is while the user is currently sitting inside a
  /// just-forgiven gap, where this reads one day short until their next
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
      // The run must end *today or yesterday* to still count as "current" —
      // anchoring strictly at today would otherwise zero out a real,
      // unbroken streak on the ordinary case of syncing before training
      // today (this was a real bug: every sync recomputes and overwrites
      // dailyStreak unconditionally, so it fired on any sync performed
      // before the day's first session, not just the grace-day edge case).
      if (!days.contains(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    return DerivedGamificationState(totalXp: totalXp, level: level, dailyStreak: streak);
  }
}
