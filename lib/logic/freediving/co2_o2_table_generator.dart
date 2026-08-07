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

  static const double co2ApneaPct = 0.50;
  static const int co2InitialRestSec = 120;
  static const int co2RestFloorSec = 30;

  static const int o2RestSec = 120;
  static const double o2StartPct = 0.40;
  static const double o2MaxPct = 0.85;

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
    assert(rounds >= 2, 'A table needs at least 2 rounds to show progression.');
    final apnea = _roundTo5Bounded(pbSeconds * co2ApneaPct, min: 10, max: pbSeconds);
    final decrement = (co2InitialRestSec - co2RestFloorSec) / (rounds - 1);

    return List.generate(rounds, (i) {
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
    final startApnea = pbSeconds * o2StartPct;
    final maxApnea = pbSeconds * o2MaxPct;
    final increment = (maxApnea - startApnea) / (rounds - 1);

    return List.generate(rounds, (i) {
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

  /// Rounds [seconds] to the nearest multiple of 5, then clamps the *rounded*
  /// result into [min, max] — clamping the raw value beforehand isn't enough,
  /// since rounding itself can still push a boundary value past the limit.
  static int _roundTo5Bounded(double seconds, {required num min, required num max}) {
    var rounded = (seconds / 5).round() * 5;
    final minInt = min.floor();
    final maxInt = max.floor();
    if (rounded < minInt) rounded = minInt;
    if (rounded > maxInt) rounded = maxInt;
    return rounded < 5 ? 5 : rounded;
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
