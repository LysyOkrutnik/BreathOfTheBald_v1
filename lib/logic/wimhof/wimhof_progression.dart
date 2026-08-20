import 'package:okrutnik_breath/data/db/database.dart';

/// The classic Wim Hof ladder, in ascending order of difficulty.
const List<String> wimHofLadder = ['mild', 'strong', 'beast', 'guru'];

/// The two hardest Wim Hof levels, plus the O2 freediving table (the most
/// hypoxia-intensive exercise) — shared "hard session" definition used by the
/// weekly load cap, so a user can't stack intensity across disciplines.
const Set<String> kHardWimHofLevels = {'beast', 'guru'};

const int kMinSessionsAtLevel = 5;
const int kMinDaysAtLevel = 14;
const double kMaxAvgRpeToAdvance = 6;

const int kMinTrialSessions = 2;
const double kMaxAvgRpeToConfirmTrial = 7;

/// No Wim Hof session (any level) in this many days rolls the ladder back
/// one step — deconditioning is real, and re-entering at the old level risks
/// pushing too hard on a body that's lost its adaptation.
const int kDetrainingDays = 21;

const int kWeeklyHardSessionCap = 4;

/// If recent Wim Hof retention already reaches this fraction of the user's
/// real, verified max PB, a recommendation to advance to a hard level comes
/// with an advisory caution note (see [WimHofNextUp.pbCautionAdvised]).
const double kPbCautionRetentionRatio = 0.8;

/// How many of the most recent sessions at the current level feed the
/// PB-caution average — a handful of recent holds, not the whole history,
/// so an old, easier stretch doesn't mask a recent trend of pushing hard.
const int kPbCautionSessionWindow = 5;

/// The result of re-evaluating a user's Wim Hof ladder standing.
class WimHofNextUp {
  const WimHofNextUp({
    required this.currentLevelKey,
    this.recommendedLevelKey,
    this.justRolledBackFrom,
    this.sessionsAtLevel = 0,
    this.daysAtLevel = 0,
    this.resetTrialWindow = false,
    this.pbCautionAdvised = false,
  });

  /// The ladder level the app currently treats as "confirmed" (the one
  /// pre-selected/highlighted as the default choice).
  final String currentLevelKey;

  /// Set when the user is eligible to try the next level up — surfaced as a
  /// "Next Up" suggestion. Null when not yet eligible or already at the top.
  final String? recommendedLevelKey;

  /// Set only in the single computation where a detraining rollback just
  /// happened, so the UI can explain why the level dropped.
  final String? justRolledBackFrom;

  /// Same-day-deduped session count at [currentLevelKey] since it was set —
  /// exposed (alongside [daysAtLevel]) so the UI can show concrete progress
  /// toward [kMinSessionsAtLevel]/[kMinDaysAtLevel] instead of just a
  /// yes/no eligibility flag.
  final int sessionsAtLevel;
  final int daysAtLevel;

  /// Set the one time a trial at the next level up was just judged "too
  /// hard" — the caller must bump `currentLevelSetAt` to now even though
  /// `currentLevelKey` itself didn't change. Without that, the failed
  /// trial's sessions never age out of the `since`-filtered window this
  /// same computation re-derives every time, so the average RPE that
  /// failed it once would fail it forever — permanently blocking any future
  /// recommendation with no way for the user to earn a fresh attempt.
  final bool resetTrialWindow;

  /// Set when [recommendedLevelKey] is a hard level (beast/guru) and the
  /// user's recent Wim Hof retention is already close to their real,
  /// normal-breath max PB — a signal they may be relying on the preceding
  /// hyperventilation's blunted CO2 warning rather than genuine tolerance,
  /// since Wim Hof retention isn't directly comparable to a plain
  /// breath-hold. Advisory only — never hides or blocks the recommendation.
  final bool pbCautionAdvised;
}

/// Pure progression logic for the Wim Hof classic ladder. The ladder itself
/// is never locked — a user can always pick any level manually — this only
/// decides what to *recommend* and when to move the "confirmed" level.
///
/// The "trial" in trial-then-confirm isn't a separate opt-in step: it's
/// simply whatever sessions the user has already logged at the next level up
/// since the current one was set. There's nothing extra to persist for it —
/// [compute] derives everything from the plain session history.
class WimHofProgression {
  WimHofProgression._();

  static int _levelIndex(String key) => wimHofLadder.indexOf(key);

  static String? _nextLevel(String key) {
    final i = _levelIndex(key);
    if (i < 0 || i >= wimHofLadder.length - 1) return null;
    return wimHofLadder[i + 1];
  }

  static String? _previousLevel(String key) {
    final i = _levelIndex(key);
    if (i <= 0) return null;
    return wimHofLadder[i - 1];
  }

  /// Collapses same-day sessions into one (the first of that day) so a
  /// single spammy day can't fast-track eligibility or skew the RPE average.
  static List<Session> _dedupeSameDay(List<Session> sessions) {
    final seenDays = <DateTime>{};
    final out = <Session>[];
    for (final s in sessions) {
      final day = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
      if (seenDays.add(day)) out.add(s);
    }
    return out;
  }

  /// Average RPE across sessions that have one recorded; null if none do
  /// (callers treat "no data yet" as a passing/neutral gate, not a blocker).
  static double? _avgRpe(List<Session> sessions) {
    final scored = sessions.where((s) => s.rpeScore != null).toList();
    if (scored.isEmpty) return null;
    final sum = scored.fold<int>(0, (acc, s) => acc + s.rpeScore!);
    return sum / scored.length;
  }

  /// True when a recommended advance to [nextLevelKey] deserves the PB
  /// caution note — only for hard levels, only once a real PB exists, and
  /// only when recent retention at the current level is already close to it.
  static bool _pbCautionFor({
    required String nextLevelKey,
    required List<Session> sessionsAtCurrentLevel,
    required int? verifiedPbSec,
  }) {
    if (!kHardWimHofLevels.contains(nextLevelKey)) return false;
    if (verifiedPbSec == null || verifiedPbSec <= 0) return false;

    final withRetention = sessionsAtCurrentLevel
        .where((s) => s.retentionSec > 0)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recent = withRetention.take(kPbCautionSessionWindow).toList();
    if (recent.isEmpty) return false;

    final avgRetention =
        recent.fold<int>(0, (sum, s) => sum + s.retentionSec) / recent.length;
    return avgRetention >= verifiedPbSec * kPbCautionRetentionRatio;
  }

  /// Computes the next-up recommendation and any detraining rollback, given
  /// [progress] (the persisted confirmed level) and every Wim Hof session
  /// ever logged (any order). The caller persists a level change whenever
  /// the returned [WimHofNextUp.currentLevelKey] differs from
  /// [progress.currentLevelKey].
  static WimHofNextUp compute({
    required WimHofProgressData progress,
    required List<Session> allWimHofSessions,
    int? verifiedPbSec,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final current = progress.currentLevelKey;
    final since = progress.currentLevelSetAt;

    final sessionsAtLevel = _dedupeSameDay(allWimHofSessions
            .where((s) => s.levelKey == current)
            .where((s) => since == null || !s.timestamp.isBefore(since))
            .toList())
        .length;
    final daysAtLevel = since == null ? kMinDaysAtLevel : now.difference(since).inDays;

    // Detraining: no Wim Hof session at all since the current level was set,
    // for more than kDetrainingDays. Gated on `since` (not just "last session
    // ever") so a rollback only fires once per idle stretch — otherwise every
    // recomputation during a long idle period would cascade another level
    // down, since "last session" never moves while the user stays inactive.
    // currentLevelSetAt is bumped to `now` whenever a rollback is persisted,
    // which is exactly what breaks the cascade on the next check.
    final lastAny = allWimHofSessions.isEmpty
        ? null
        : allWimHofSessions
            .map((s) => s.timestamp)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    final idleSinceLevelSet =
        since != null && now.difference(since).inDays > kDetrainingDays &&
            (lastAny == null || !lastAny.isAfter(since));
    if (idleSinceLevelSet) {
      final previous = _previousLevel(current);
      if (previous != null) {
        return WimHofNextUp(
          currentLevelKey: previous,
          justRolledBackFrom: current,
          sessionsAtLevel: sessionsAtLevel,
          daysAtLevel: daysAtLevel,
        );
      }
    }

    final next = _nextLevel(current);
    if (next == null) {
      return WimHofNextUp(
        currentLevelKey: current,
        sessionsAtLevel: sessionsAtLevel,
        daysAtLevel: daysAtLevel,
      );
    }

    // Trial-then-confirm: sessions already logged at the next level since
    // the current one was set.
    final trialSessions = _dedupeSameDay(allWimHofSessions
        .where((s) => s.levelKey == next)
        .where((s) => since == null || !s.timestamp.isBefore(since))
        .toList());
    if (trialSessions.length >= kMinTrialSessions) {
      final trialAvgRpe = _avgRpe(trialSessions);
      final tooHard = trialAvgRpe != null && trialAvgRpe > kMaxAvgRpeToConfirmTrial;
      if (!tooHard) {
        return WimHofNextUp(currentLevelKey: next);
      }
      // Too hard — stay put, and reset the trial window so these same
      // failed sessions don't keep failing every future recommendation.
      return WimHofNextUp(
        currentLevelKey: current,
        sessionsAtLevel: 0,
        daysAtLevel: 0,
        resetTrialWindow: true,
      );
    }

    // Eligibility to recommend a trial of the next level.
    final currentLevelSessions = allWimHofSessions
        .where((s) => s.levelKey == current)
        .where((s) => since == null || !s.timestamp.isBefore(since))
        .toList();
    final avgRpe = _avgRpe(_dedupeSameDay(currentLevelSessions));
    final rpeOk = avgRpe == null || avgRpe <= kMaxAvgRpeToAdvance;
    final eligible = sessionsAtLevel >= kMinSessionsAtLevel &&
        daysAtLevel >= kMinDaysAtLevel &&
        rpeOk;

    return WimHofNextUp(
      currentLevelKey: current,
      recommendedLevelKey: eligible ? next : null,
      sessionsAtLevel: sessionsAtLevel,
      daysAtLevel: daysAtLevel,
      pbCautionAdvised: eligible &&
          _pbCautionFor(
            nextLevelKey: next,
            sessionsAtCurrentLevel: currentLevelSessions,
            verifiedPbSec: verifiedPbSec,
          ),
    );
  }
}

/// Counts "hard" sessions (Wim Hof Beast/Okrutnik, or a freediving O2 table)
/// in the trailing 7 days — a shared intensity budget across disciplines, so
/// stacking a hard Wim Hof session with an O2 table on the same day doesn't
/// slip past a per-discipline cap.
int countHardSessionsInPastWeek(
  List<Session> wimHofSessions,
  List<FreedivingSessionLogData> freedivingLogs, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final cutoff = now.subtract(const Duration(days: 7));
  final hardWimHof = wimHofSessions.where(
      (s) => kHardWimHofLevels.contains(s.levelKey) && s.timestamp.isAfter(cutoff));
  final o2Sessions =
      freedivingLogs.where((l) => l.tableType == 'o2' && l.timestamp.isAfter(cutoff));
  return hardWimHof.length + o2Sessions.length;
}
