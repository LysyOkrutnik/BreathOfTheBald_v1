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

// 2 sessions / RPE<=7 was thin evidence to permanently confirm a harder
// level on — a single good day could pass it. 3 sessions and a slightly
// stricter RPE ceiling (matching kMaxAvgRpeToAdvance's own threshold, so
// "eligible for a trial" and "trial confirmed" apply the same bar) reduce
// how often a lucky trial locks in a level the user isn't actually ready
// for yet.
const int kMinTrialSessions = 3;
const double kMaxAvgRpeToConfirmTrial = 6;

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
    this.idleDaysBeforeRollback = 0,
    this.hasNoRpeData = false,
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

  /// Set only alongside [justRolledBackFrom]: how many days of inactivity
  /// triggered the rollback, so the UI can explain "why" with a concrete
  /// number instead of a generic message.
  final int idleDaysBeforeRollback;

  /// True when there are sessions logged at [currentLevelKey] but none of
  /// them carry an RPE score — missing RPE is treated as a free pass by the
  /// eligibility/trial checks (deliberately not changed to a hard block,
  /// that's a product decision), so a user who never rates a session
  /// advances on session count and days alone, with the "listen to how it
  /// felt" signal never actually engaged for them. Advisory-only nudge.
  final bool hasNoRpeData;
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
    double pbCautionRatio = kPbCautionRetentionRatio,
  }) {
    if (!kHardWimHofLevels.contains(nextLevelKey)) return false;
    if (verifiedPbSec == null || verifiedPbSec <= 0) return false;

    // Deduped first — same as every other average/eligibility check in this
    // file — so a single day of repeated logging can't dominate the last-5
    // window and skew the average retention this compares against the PB.
    final withRetention = _dedupeSameDay(sessionsAtCurrentLevel)
        .where((s) => s.retentionSec > 0)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recent = withRetention.take(kPbCautionSessionWindow).toList();
    if (recent.isEmpty) return false;

    final avgRetention =
        recent.fold<int>(0, (sum, s) => sum + s.retentionSec) / recent.length;
    return avgRetention >= verifiedPbSec * pbCautionRatio;
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
    int detrainingDays = kDetrainingDays,
    double pbCautionRatio = kPbCautionRetentionRatio,
    double maxAvgRpeToAdvance = kMaxAvgRpeToAdvance,
    double maxAvgRpeToConfirmTrial = kMaxAvgRpeToConfirmTrial,
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

    // Detraining: no Wim Hof session at all (any level) in more than
    // kDetrainingDays — measured from the actual last session, not from
    // `since`. A previous version required *zero* sessions since the level
    // was set, which meant a single session right after a promotion
    // permanently disabled this safeguard for that level forever (the idle
    // clock never had anything to measure once `lastAny` moved past
    // `since`, even if the user then went silent for months).
    final lastAny = allWimHofSessions.isEmpty
        ? null
        : allWimHofSessions
            .map((s) => s.timestamp)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    final daysSinceLastSession = lastAny != null
        ? now.difference(lastAny).inDays
        : (since != null ? now.difference(since).inDays : 0);
    // `daysAtLevel > detrainingDays` on top of the staleness check above is
    // what actually prevents a cascade: right after a rollback persists,
    // `since` is bumped to now, so `daysAtLevel` resets to ~0 even though
    // `daysSinceLastSession` alone (still measuring off the same stale
    // `lastAny`, since no new session happened) would otherwise stay past
    // the threshold and re-trigger on every subsequent `refresh()` call —
    // and this is called every time the Wim Hof tab builds, so a user who
    // just visits the tab a few times while inactive would otherwise get
    // rolled back a level on *each visit*, not once per real idle episode.
    // Requiring the current level to have *itself* been held for a full
    // detraining period bounds this to one rollback step per elapsed
    // kDetrainingDays of continued inactivity, same as the first step.
    final idleSinceLevelSet = since != null &&
        daysSinceLastSession > detrainingDays &&
        daysAtLevel > detrainingDays;
    if (idleSinceLevelSet) {
      final previous = _previousLevel(current);
      if (previous != null) {
        return WimHofNextUp(
          currentLevelKey: previous,
          justRolledBackFrom: current,
          sessionsAtLevel: sessionsAtLevel,
          daysAtLevel: daysAtLevel,
          idleDaysBeforeRollback: daysSinceLastSession,
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
      final tooHard = trialAvgRpe != null && trialAvgRpe > maxAvgRpeToConfirmTrial;
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
    // A rolling window of the most recent sessions, not the whole history
    // at this level — matches kPbCautionSessionWindow's own reasoning
    // (_pbCautionFor, above): kMinSessionsAtLevel=5 means someone who spent
    // months at a level accumulates a long tail of old ratings that can
    // permanently anchor the average, so one rough first attempt right
    // after a promotion could keep blocking the next recommendation long
    // after the user has clearly settled in.
    final recentAtLevel = _dedupeSameDay(currentLevelSessions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final avgRpe = _avgRpe(recentAtLevel.take(kPbCautionSessionWindow).toList());
    final rpeOk = avgRpe == null || avgRpe <= maxAvgRpeToAdvance;
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
            pbCautionRatio: pbCautionRatio,
          ),
      hasNoRpeData: avgRpe == null && currentLevelSessions.isNotEmpty,
    );
  }
}

/// Collapses same-day items into one (the first of that day), keyed by
/// whatever [dateOf] returns — the generic counterpart of
/// [WimHofProgression._dedupeSameDay], which only accepts a [Session] list.
List<T> _dedupeByDay<T>(Iterable<T> items, DateTime Function(T) dateOf) {
  final seenDays = <DateTime>{};
  final out = <T>[];
  for (final item in items) {
    final d = dateOf(item);
    if (seenDays.add(DateTime(d.year, d.month, d.day))) out.add(item);
  }
  return out;
}

/// Counts "hard" sessions (Wim Hof Beast/Okrutnik, or a freediving O2 table)
/// in the trailing 7 days — a shared intensity budget across disciplines, so
/// stacking a hard Wim Hof session with an O2 table on the same day doesn't
/// slip past a per-discipline cap. Same-day sessions within *each* category
/// are deduped (matching the eligibility logic above) so a spammy day
/// doesn't burn through the weekly budget faster than actually training
/// once a day for a week would.
int countHardSessionsInPastWeek(
  List<Session> wimHofSessions,
  List<FreedivingSessionLogData> freedivingLogs, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final cutoff = now.subtract(const Duration(days: 7));
  final hardWimHof = _dedupeByDay(
    wimHofSessions.where(
        (s) => kHardWimHofLevels.contains(s.levelKey) && s.timestamp.isAfter(cutoff)),
    (s) => s.timestamp,
  );
  final o2Sessions = _dedupeByDay(
    freedivingLogs.where((l) => l.tableType == 'o2' && l.timestamp.isAfter(cutoff)),
    (l) => l.timestamp,
  );
  return hardWimHof.length + o2Sessions.length;
}
