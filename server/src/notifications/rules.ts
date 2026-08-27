export interface NotificationCandidate {
  type: 'streak_at_risk' | 'inactivity' | 'rpe_trending_up';
  title: string;
  body: string;
}

export interface TrainingRecord {
  timestamp: Date;
  rpeScore: number | null;
}

const DAY_MS = 86_400_000;

/// Calendar-day key for [d] in [timezone] (an IANA name, e.g.
/// "Europe/Warsaw"), or in UTC when [timezone] is null/unknown — this used
/// to always use UTC regardless of the user, which meant "trained today"/
/// streak/inactivity could be wrong by a day right around the UTC
/// boundary for any user not near UTC+0 (the same class of local-vs-UTC
/// bug already fixed once for sync). `Intl.DateTimeFormat` handles the
/// zone conversion with no extra dependency; `en-CA` formats as
/// `YYYY-MM-DD`, the exact sortable/comparable shape the rest of this file
/// already assumes.
function dayKey(d: Date, timezone: string | null): string {
  if (!timezone) return d.toISOString().slice(0, 10);
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(d);
  } catch {
    // Unknown/invalid IANA name (a malformed value from an old client) —
    // fall back to UTC rather than throwing and dropping this user's
    // notification for the day.
    return d.toISOString().slice(0, 10);
  }
}

/// Longest run of consecutive calendar days (up to and including [asOf]'s
/// own local day) with at least one training logged — an all-time version
/// of the streak metric used for challenge leaderboards. Used only to
/// decide whether a reminder is warranted, so it doesn't need to match the
/// on-device streak/grace logic exactly.
///
/// Walks backward in pure date-only arithmetic after the *one* zone
/// conversion that establishes the starting day — re-applying
/// `dayKey(cursor, timezone)` on every step would convert an already
/// zone-corrected, synthetic UTC-midnight value through the zone a second
/// time, which can shift the computed date by a day depending on the
/// offset. [days] is itself already a set of zone-correct calendar keys
/// (produced once per training record by the caller), so comparing against
/// a plain UTC-sliced cursor here is the part that must stay zone-naive.
function currentStreakLength(days: Set<string>, asOf: Date, timezone: string | null): number {
  let streak = 0;
  let cursor = new Date(`${dayKey(asOf, timezone)}T00:00:00Z`);
  while (days.has(cursor.toISOString().slice(0, 10))) {
    streak += 1;
    cursor = new Date(cursor.getTime() - DAY_MS);
  }
  return streak;
}

/// Pure decision function — picks at most one notification, in priority
/// order, from a user's already-fetched training history. Split out from
/// the DB-querying wrapper below so the cron job can batch-fetch every
/// user's history in a couple of queries instead of two per user.
export function pickNotification(
  trainings: TrainingRecord[],
  now: Date,
  timezone: string | null,
): NotificationCandidate | null {
  if (trainings.length === 0) return null;
  const sorted = [...trainings].sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

  const today = dayKey(now, timezone);
  const trainedToday = sorted.some((t) => dayKey(t.timestamp, timezone) === today);
  const days = new Set(sorted.map((t) => dayKey(t.timestamp, timezone)));

  // 1. Streak at risk: a run of 2+ days ending yesterday, nothing logged yet
  // today. Highest priority — losing an active streak is the single most
  // motivating thing a reminder can prevent.
  if (!trainedToday) {
    const yesterday = new Date(now.getTime() - DAY_MS);
    const streakThroughYesterday = currentStreakLength(days, yesterday, timezone);
    if (streakThroughYesterday >= 2) {
      return {
        type: 'streak_at_risk',
        title: 'Twoja passa czeka!',
        body: `Masz ${streakThroughYesterday}-dniową passę. Krótki trening dziś ją utrzyma.`,
      };
    }
  }

  // 2. Inactivity: nothing logged in 3+ days — re-engagement nudge.
  const daysSinceLast = Math.floor((now.getTime() - sorted[0].timestamp.getTime()) / DAY_MS);
  if (daysSinceLast >= 3) {
    return {
      type: 'inactivity',
      title: 'Dawno Cię nie było',
      body: `Minęło ${daysSinceLast} dni od ostatniego treningu. Wróć na kilka minut oddechu.`,
    };
  }

  // 3. RPE trending up: the last 3 rated sessions average noticeably harder
  // than the 3 before them — suggest easing off rather than pushing through.
  const rated = sorted.filter((t) => t.rpeScore != null).map((t) => t.rpeScore as number);
  if (rated.length >= 6) {
    const recent = average(rated.slice(0, 3));
    const prior = average(rated.slice(3, 6));
    if (recent - prior >= 1.5) {
      return {
        type: 'rpe_trending_up',
        title: 'Zwolnij na chwilę',
        body: 'Twoje ostatnie treningi są coraz cięższe. Rozważ dziś lżejszą sesję lub odpoczynek.',
      };
    }
  }

  return null;
}

function average(values: number[]): number {
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}
