/// One round of a CO2/O2 breath-hold table.
class BreathHoldRound {
  const BreathHoldRound({
    required this.index,
    required this.apneaSec,
    required this.restSec,
  });

  /// 1-based round number.
  final int index;
  final int apneaSec;
  final int restSec;
}

enum FreedivingTableType { co2, o2 }

/// Fixed per-round timing that sits around a table's own apnea+rest
/// seconds — a calm breathe-up, the final full inhale, and the exhale right
/// after the hold. Shared between the session runner and the pre-start
/// preview so the "~X min" estimate shown before starting stays honest
/// rather than silently undercounting real session length.
abstract final class FreedivingSessionTiming {
  static const int breatheUpCycles = 3;
  static const int breatheUpBreathSec = 4;
  static const int finalInhaleSec = 3;
  static const int exhaleSec = 2;

  static int get perRoundOverheadSec =>
      breatheUpCycles * breatheUpBreathSec * 2 + finalInhaleSec + exhaleSec;
}

/// One round's "first contraction" data — the moment the diaphragm's urge-
/// to-breathe reflex first kicks in during a hold, marked by the user via
/// the "Fala kontrakcji" control. Tracked separately from the hold's total
/// duration since the two can move in opposite directions: a growing gap
/// between them (contraction earlier, hold time still the same or longer)
/// is real, measurable CO2-tolerance progress that total hold time alone
/// doesn't show.
class RoundContraction {
  const RoundContraction({required this.firstContractionSec, required this.markCount});

  /// Seconds into the hold when the first tap landed — null if the round
  /// was never marked at all.
  final int? firstContractionSec;

  /// Total number of taps in the round (>= 1 whenever [firstContractionSec]
  /// is non-null).
  final int markCount;
}

/// A just-finished freediving table's contraction data, condensed for the
/// summary screen — built from a list of per-round [RoundContraction].
class RoundContractionSummary {
  const RoundContractionSummary({
    required this.averageFirstContractionSec,
    required this.roundsMarked,
    required this.totalRounds,
    required this.totalMarks,
  });

  /// Average, across only the rounds that got at least one tap, of seconds
  /// into the hold when the first tap landed.
  final int averageFirstContractionSec;
  final int roundsMarked;
  final int totalRounds;
  final int totalMarks;

  /// Null if nothing was ever marked this session — nothing to summarize.
  static RoundContractionSummary? fromRounds(List<RoundContraction> rounds) {
    final marked = rounds.where((r) => r.firstContractionSec != null).toList();
    if (marked.isEmpty) return null;
    final avg = marked.fold<int>(0, (sum, r) => sum + r.firstContractionSec!) ~/
        marked.length;
    return RoundContractionSummary(
      averageFirstContractionSec: avg,
      roundsMarked: marked.length,
      totalRounds: rounds.length,
      totalMarks: rounds.fold<int>(0, (sum, r) => sum + r.markCount),
    );
  }
}

/// Generates CO2 and O2 static-apnea tables from a Personal Best (PB) time.
///
/// CO2 tables build tolerance to carbon dioxide: apnea time is held constant
/// while rest between rounds shrinks each round, so CO2 builds up further with
/// each successive hold.
///
/// O2 tables build adaptation to low oxygen: rest is held constant (long
/// enough to fully clear CO2) while apnea time grows each round, pushing
/// closer to a real breath-hold without the confound of rising CO2.
///
/// Every method here is a pure function — no I/O, no Flutter dependency — so
/// the exact schedule generated for a session can be persisted verbatim
/// alongside its RPE rating for the next table's calculation.
abstract final class Co2O2TableGenerator {
  static const int defaultRounds = 8;

  static const double co2ApneaPct = 0.60;
  static const int co2InitialRestSec = 90;
  static const int co2RestFloorSec = 20;

  static const int o2RestSec = 120;
  static const double o2StartPct = 0.55;
  static const double o2MaxPct = 0.92;

  /// Lowest PB (seconds) treated as plausible input; below this, tables would
  /// be too short to be meaningful and likely indicate a mis-typed value.
  static const int minPlausiblePbSec = 20;

  /// Highest PB (seconds) accepted without a "please double-check" warning —
  /// comfortably above current elite static-apnea records (~11-12 minutes),
  /// so it only flags likely mistakes (e.g. a stopwatch left running).
  static const int maxPlausiblePbSec = 900;

  /// Returns a validation error message key, or null if [pbSeconds] is
  /// plausible. Callers should show the corresponding localized string.
  static String? validatePb(int pbSeconds) {
    if (pbSeconds < minPlausiblePbSec) return 'freediving_pb_too_low';
    if (pbSeconds > maxPlausiblePbSec) return 'freediving_pb_too_high';
    return null;
  }

  static List<BreathHoldRound> generateCo2Table(
    int pbSeconds, {
    int rounds = defaultRounds,
  }) {
    // `assert` alone is stripped in release builds — a `rounds < 2` value
    // slipping through (e.g. a synced custom preset saved before the UI's
    // own `min: 2` stepper existed) would divide by `rounds - 1 == 0` below,
    // producing Infinity, and `Infinity.round()` throws.
    assert(rounds >= 2, 'A table needs at least 2 rounds to show progression.');
    final safeRounds = rounds < 2 ? 2 : rounds;
    // validatePb only *warns* below minPlausiblePbSec, it doesn't block —
    // without this floor, a PB under ~17s makes the min:10 bound exceed
    // max:pbSeconds below, and _roundTo5Bounded's clamp-up-then-down nets
    // out at apnea == pbSeconds: a CO2 table (meant to hold at a fixed 60%
    // of PB) would instead ask for the user's *entire* max breath-hold,
    // repeated 8 times with shrinking rest.
    final safePb = pbSeconds < minPlausiblePbSec ? minPlausiblePbSec : pbSeconds;
    final apnea = _roundTo5Bounded(safePb * co2ApneaPct, min: 10, max: safePb);
    final decrement = (co2InitialRestSec - co2RestFloorSec) / (safeRounds - 1);

    return List.generate(safeRounds, (i) {
      final raw = co2InitialRestSec - decrement * i;
      // Never round below the floor; round5 alone could undershoot a value
      // just above the floor down to a lower multiple of 5.
      final rest = _roundTo5Bounded(raw, min: co2RestFloorSec, max: co2InitialRestSec);
      return BreathHoldRound(index: i + 1, apneaSec: apnea, restSec: rest);
    });
  }

  static List<BreathHoldRound> generateO2Table(
    int pbSeconds, {
    int rounds = defaultRounds,
  }) {
    assert(rounds >= 2, 'A table needs at least 2 rounds to show progression.');
    final safeRounds = rounds < 2 ? 2 : rounds;
    // Same floor CO2's generator already applies (see its own comment) —
    // without it, a PB under a few seconds pushes startApnea/maxApnea close
    // enough together that _roundTo5Bounded's 5-second granularity has no
    // real room to work with.
    final safePb = pbSeconds < minPlausiblePbSec ? minPlausiblePbSec : pbSeconds;
    final startApnea = safePb * o2StartPct;
    final maxApnea = safePb * o2MaxPct;
    final increment = (maxApnea - startApnea) / (safeRounds - 1);

    return List.generate(safeRounds, (i) {
      final raw = startApnea + increment * i;
      // Bounded rounding: nearest-5 rounding on its own can push the final
      // round's target a few seconds *past* maxApnea (this is exactly the
      // rounding error in the original hand-worked spec, which listed a final
      // round of 130s against an intended 85% ceiling of 127.5s) — round down
      // instead whenever plain rounding would exceed the safety ceiling.
      final apnea = _roundTo5Bounded(raw, min: startApnea, max: maxApnea);
      return BreathHoldRound(index: i + 1, apneaSec: apnea, restSec: o2RestSec);
    });
  }

  /// Generates a table from explicit start/end apnea and rest bounds (linear
  /// interpolation across rounds), for the user-defined custom table builder
  /// — no PB or safety cap involved, since it's entirely user-specified.
  static List<BreathHoldRound> generateCustomTable({
    required int startApneaSec,
    required int endApneaSec,
    required int startRestSec,
    required int endRestSec,
    required int rounds,
  }) {
    assert(rounds >= 2, 'A table needs at least 2 rounds to show progression.');
    final safeRounds = rounds < 2 ? 2 : rounds;
    final apneaStep = (endApneaSec - startApneaSec) / (safeRounds - 1);
    final restStep = (endRestSec - startRestSec) / (safeRounds - 1);

    return List.generate(safeRounds, (i) {
      final apnea = (startApneaSec + apneaStep * i).round();
      final rest = (startRestSec + restStep * i).round();
      return BreathHoldRound(index: i + 1, apneaSec: apnea, restSec: rest);
    });
  }

  /// Rounds [seconds] to the nearest multiple of 5, then clamps the *rounded*
  /// result into [min, max] — clamping the raw value beforehand isn't enough,
  /// since rounding itself can still push a boundary value past the limit.
  static int _roundTo5Bounded(double seconds, {required num min, required num max}) {
    var rounded = (seconds / 5).round() * 5;
    final minInt = min.floor();
    final maxInt = max.floor();
    if (rounded < minInt) rounded = minInt;
    if (rounded > maxInt) rounded = maxInt;
    // A hard floor of 5s (nothing shorter is a meaningful hold) — but this
    // must never re-violate the max bound just clamped above, or a `max`
    // under 5 (e.g. an O2 table built from a very low PB) would return
    // something longer than the caller's own safety ceiling.
    if (rounded < 5) rounded = 5;
    if (rounded > maxInt) rounded = maxInt;
    return rounded;
  }
}

/// Applies RPE (Rate of Perceived Exertion, 1-10) feedback to a working
/// "virtual" PB, safety-capped relative to the last verified test so
/// consecutive "too easy" ratings can never drift the working PB into
/// dangerous territory without a real re-test.
abstract final class RpeProgression {
  static const double increaseFactor = 1.05;
  static const double decreaseFactor = 0.95;

  /// Hard ceiling: the virtual PB can never exceed this fraction of the last
  /// verified real test, however many "too easy" ratings accumulate.
  static const double maxRatioOfVerified = 1.15;

  /// Floor to match: repeated "brutal" ratings can't spiral the working PB
  /// down into an unrealistically low, unhelpful table either.
  static const double minRatioOfVerified = 0.5;

  static int nextVirtualPb({
    required int currentVirtualPbSec,
    required int verifiedPbSec,
    required int rpeScore,
  }) {
    assert(rpeScore >= 1 && rpeScore <= 10, 'RPE must be 1-10');

    double factor = 1.0;
    if (rpeScore <= 4) {
      factor = increaseFactor;
    } else if (rpeScore >= 9) {
      factor = decreaseFactor;
    }

    final adjusted = (currentVirtualPbSec * factor).round();
    final ceiling = (verifiedPbSec * maxRatioOfVerified).round();
    final floor = (verifiedPbSec * minRatioOfVerified).round();
    return adjusted.clamp(floor, ceiling);
  }
}
