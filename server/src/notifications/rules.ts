import { prisma } from '../prismaClient';

export interface NotificationCandidate {
  type: 'streak_at_risk' | 'inactivity' | 'rpe_trending_up';
  title: string;
  body: string;
}

const DAY_MS = 86_400_000;
const dayKey = (d: Date) => d.toISOString().slice(0, 10);

/// Longest run of consecutive calendar days (up to and including the most
/// recent day trained) with at least one training logged — an all-time
/// version of the streak metric used for challenge leaderboards. Used only
/// to decide whether a reminder is warranted, so it doesn't need to match
/// the on-device streak/grace logic exactly.
function currentStreakLength(days: Set<string>, asOf: Date): number {
  let streak = 0;
  let cursor = new Date(`${dayKey(asOf)}T00:00:00Z`);
  while (days.has(dayKey(cursor))) {
    streak += 1;
    cursor = new Date(cursor.getTime() - DAY_MS);
  }
  return streak;
}

/// Picks at most one notification per user per day, in priority order, so a
/// user is never sent more than a single push in a single cron run.
export async function pickNotificationForUser(userId: string): Promise<NotificationCandidate | null> {
  const now = new Date();
  const today = dayKey(now);
  const lookback = new Date(now.getTime() - 30 * DAY_MS);

  const [sessions, freedivingLogs] = await Promise.all([
    prisma.session.findMany({
      where: { userId, timestamp: { gte: lookback } },
      orderBy: { timestamp: 'desc' },
      select: { timestamp: true, rpeScore: true },
    }),
    prisma.freedivingLog.findMany({
      where: { userId, timestamp: { gte: lookback } },
      orderBy: { timestamp: 'desc' },
      select: { timestamp: true, rpeScore: true },
    }),
  ]);

  const allTrainings = [...sessions, ...freedivingLogs].sort(
    (a, b) => b.timestamp.getTime() - a.timestamp.getTime(),
  );
  if (allTrainings.length === 0) return null;

  const trainedToday = allTrainings.some((t) => dayKey(t.timestamp) === today);
  const days = new Set(allTrainings.map((t) => dayKey(t.timestamp)));

  // 1. Streak at risk: a run of 2+ days ending yesterday, nothing logged yet
  // today. Highest priority — losing an active streak is the single most
  // motivating thing a reminder can prevent.
  if (!trainedToday) {
    const yesterday = new Date(now.getTime() - DAY_MS);
    const streakThroughYesterday = currentStreakLength(days, yesterday);
    if (streakThroughYesterday >= 2) {
      return {
        type: 'streak_at_risk',
        title: 'Twoja passa czeka!',
        body: `Masz ${streakThroughYesterday}-dniową passę. Krótki trening dziś ją utrzyma.`,
      };
    }
  }

  // 2. Inactivity: nothing logged in 3+ days — re-engagement nudge.
  const daysSinceLast = Math.floor((now.getTime() - allTrainings[0].timestamp.getTime()) / DAY_MS);
  if (daysSinceLast >= 3) {
    return {
      type: 'inactivity',
      title: 'Dawno Cię nie było',
      body: `Minęło ${daysSinceLast} dni od ostatniego treningu. Wróć na kilka minut oddechu.`,
    };
  }

  // 3. RPE trending up: the last 3 rated sessions average noticeably harder
  // than the 3 before them — suggest easing off rather than pushing through.
  const rated = allTrainings.filter((t) => t.rpeScore != null).map((t) => t.rpeScore as number);
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
