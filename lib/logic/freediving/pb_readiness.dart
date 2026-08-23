import 'package:okrutnik_breath/data/db/database.dart';

/// How many days after a verified Max PB Test before it's considered stale
/// for gating purposes — past this, CO2/O2 tables and the Wim Hof ladder's
/// climb past `mild` lock back down until the user retests, the same as if
/// no test had ever been done. Deliberately separate from and larger than
/// [FreedivingRepository.kFreedivingDetrainingDays] (21 days), which only
/// eases the *pacing* of a table, not this harder, more visible reset.
const int kPbRetestRequiredDays = 30;

/// A soft "retest coming up" reminder starts this many days before the hard
/// deadline above — a week's notice instead of the gate closing outright.
const int kPbRetestReminderLeadDays = 7;

/// Inhale-hold PB thresholds (seconds) for the three readiness tiers — the
/// same PB [FreedivingProfileData.verifiedPbSec] the Freediving tab's own
/// `hasPb` already keys off. Deliberately conservative defaults for
/// recreational breath-hold training, not a medical standard — exposed in
/// Settings → Advanced so they can be retuned without a code change.
const int kReadinessIntermediateSec = 90;
const int kReadinessAdvancedSec = 180;

/// Where the user stands relative to the retest requirement above.
enum PbReadinessStatus {
  /// No Max PB Test has ever been completed.
  notStarted,

  /// A test was completed once, but it's past [kPbRetestRequiredDays] old.
  stale,

  /// A test was completed and is still within the retest window.
  active,
}

/// A coarse difficulty bucket derived from the verified inhale-hold PB —
/// the shared "how far along is this person" signal that lets Wim Hof and
/// the cold shower's suggested exposure reflect the same underlying test
/// CO2/O2 pacing already reflects, instead of each discipline reading its
/// own disconnected signal.
enum PbReadinessTier { beginner, intermediate, advanced }

/// The result of evaluating a [FreedivingProfileData] against the retest
/// window and tier thresholds — the single source of truth every
/// PB-dependent gate (CO2/O2 unlock, Wim Hof's climb past `mild`, the
/// cold-shower hint) reads from, so "connected to the PB test" means the
/// same thing everywhere instead of each call site re-deriving its own
/// notion of "has PB".
class PbReadiness {
  const PbReadiness({
    required this.status,
    required this.tier,
    this.daysUntilStale,
    this.daysSinceStale,
  });

  final PbReadinessStatus status;
  final PbReadinessTier tier;

  /// Set only when [status] is `active` and within [kPbRetestReminderLeadDays]
  /// of going stale — days left before the gate closes, for a "retest soon"
  /// nudge with a concrete number instead of a vague warning.
  final int? daysUntilStale;

  /// Set only when [status] is `stale` — days past the retest deadline, for
  /// an "expired N days ago" message.
  final int? daysSinceStale;

  bool get isActive => status == PbReadinessStatus.active;

  static PbReadiness compute({
    required FreedivingProfileData? profile,
    DateTime? now,
    int retestRequiredDays = kPbRetestRequiredDays,
    int reminderLeadDays = kPbRetestReminderLeadDays,
    int intermediateSec = kReadinessIntermediateSec,
    int advancedSec = kReadinessAdvancedSec,
  }) {
    now ??= DateTime.now();
    final verifiedAt = profile?.verifiedPbAt;
    final verifiedSec = profile?.verifiedPbSec;

    final tier = verifiedSec == null
        ? PbReadinessTier.beginner
        : verifiedSec >= advancedSec
            ? PbReadinessTier.advanced
            : verifiedSec >= intermediateSec
                ? PbReadinessTier.intermediate
                : PbReadinessTier.beginner;

    if (verifiedAt == null) {
      return PbReadiness(status: PbReadinessStatus.notStarted, tier: tier);
    }

    final daysSince = now.difference(verifiedAt).inDays;
    if (daysSince > retestRequiredDays) {
      return PbReadiness(
        status: PbReadinessStatus.stale,
        tier: tier,
        daysSinceStale: daysSince - retestRequiredDays,
      );
    }

    final daysLeft = retestRequiredDays - daysSince;
    return PbReadiness(
      status: PbReadinessStatus.active,
      tier: tier,
      daysUntilStale: daysLeft <= reminderLeadDays ? daysLeft : null,
    );
  }
}
