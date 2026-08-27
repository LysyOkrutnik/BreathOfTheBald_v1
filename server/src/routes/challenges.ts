import { Router } from 'express';
import { prisma } from '../prismaClient';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

router.get('/', async (req: AuthedRequest, res) => {
  const userId = req.userId!;
  const challenges = await prisma.challenge.findMany({
    where: { endsAt: { gt: new Date() } },
    orderBy: { startsAt: 'asc' },
    include: { participants: { where: { userId }, select: { userId: true } } },
  });
  res.json(
    challenges.map((c) => ({
      id: c.id,
      key: c.key,
      title: c.title,
      description: c.description,
      metric: c.metric,
      startsAt: c.startsAt,
      endsAt: c.endsAt,
      joined: c.participants.length > 0,
    })),
  );
});

router.post('/:id/join', async (req: AuthedRequest, res) => {
  const challenge = await prisma.challenge.findUnique({ where: { id: req.params.id as string } });
  if (!challenge) {
    res.status(404).json({ error: 'not_found' });
    return;
  }
  if (challenge.endsAt <= new Date()) {
    res.status(400).json({ error: 'challenge_ended' });
    return;
  }
  await prisma.challengeParticipant.upsert({
    where: { challengeId_userId: { challengeId: challenge.id, userId: req.userId! } },
    create: { challengeId: challenge.id, userId: req.userId! },
    update: {},
  });
  res.status(204).end();
});

router.delete('/:id/join', async (req: AuthedRequest, res) => {
  await prisma.challengeParticipant.deleteMany({
    where: { challengeId: req.params.id as string, userId: req.userId! },
  });
  res.status(204).end();
});

/// Leaderboards are computed on every request from participants' synced
/// session data — never stored — so they can't drift out of sync with the
/// underlying sessions the way a cached/pre-aggregated score could.
router.get('/:id/leaderboard', async (req: AuthedRequest, res) => {
  const challenge = await prisma.challenge.findUnique({
    where: { id: req.params.id as string },
    include: { participants: { include: { user: { select: { id: true, profileName: true } } } } },
  });
  if (!challenge) {
    res.status(404).json({ error: 'not_found' });
    return;
  }

  const window = { gte: challenge.startsAt, lte: challenge.endsAt };
  const participantIds = challenge.participants.map((p) => p.userId);
  const valueByUser = await computeMetricValuesForUsers(participantIds, challenge.metric, window);

  const entries = challenge.participants.map((p) => ({
    userId: p.userId,
    // Never derived from email — a participant who hasn't set a
    // profile name gets a stable anonymous label instead of leaking
    // part of their address to every other participant.
    displayName: p.user.profileName?.trim() || `Uczestnik ${p.userId.slice(0, 4)}`,
    value: valueByUser.get(p.userId) ?? 0,
  }));

  entries.sort((a, b) => b.value - a.value);
  res.json({
    challengeId: challenge.id,
    metric: challenge.metric,
    leaderboard: entries.map((e, i) => ({ rank: i + 1, ...e })),
  });
});

/// One (or two) queries scoped to every participant at once via
/// `userId: { in: userIds } }`, instead of the previous per-participant
/// `computeMetricValue` (1-2 queries each) — a challenge with P
/// participants used to issue up to 2P separate DB round-trips per
/// leaderboard view, computed fresh on every request with nothing cached.
async function computeMetricValuesForUsers(
  userIds: string[],
  metric: 'STREAK' | 'TOTAL_RETENTION_SEC' | 'SESSION_COUNT',
  window: { gte: Date; lte: Date },
): Promise<Map<string, number>> {
  if (userIds.length === 0) return new Map();

  if (metric === 'TOTAL_RETENTION_SEC') {
    const rows = await prisma.session.groupBy({
      by: ['userId'],
      where: { userId: { in: userIds }, timestamp: window },
      _sum: { retentionSec: true },
    });
    return new Map(rows.map((r) => [r.userId, r._sum.retentionSec ?? 0]));
  }

  const [sessions, freedivingLogs] = await Promise.all([
    prisma.session.findMany({
      where: { userId: { in: userIds }, timestamp: window },
      select: { userId: true, timestamp: true },
    }),
    prisma.freedivingLog.findMany({
      where: { userId: { in: userIds }, timestamp: window },
      select: { userId: true, timestamp: true },
    }),
  ]);
  const byUser = new Map<string, Date[]>();
  for (const row of [...sessions, ...freedivingLogs]) {
    const list = byUser.get(row.userId);
    if (list) {
      list.push(row.timestamp);
    } else {
      byUser.set(row.userId, [row.timestamp]);
    }
  }

  if (metric === 'SESSION_COUNT') {
    return new Map([...byUser.entries()].map(([userId, timestamps]) => [userId, timestamps.length]));
  }

  // STREAK: longest run of consecutive calendar days with at least one
  // training logged inside the challenge window, per participant. This is
  // a simplified, self-contained metric distinct from the app's local
  // day-gap/grace streak — it only needs to be fair across participants,
  // not identical to the on-device definition.
  return new Map([...byUser.entries()].map(([userId, timestamps]) => [userId, longestStreak(timestamps)]));
}

function longestStreak(timestamps: Date[]): number {
  const days = new Set(timestamps.map((t) => t.toISOString().slice(0, 10)));
  const sortedDays = [...days].sort();
  let longest = 0;
  let current = 0;
  let previous: Date | null = null;
  for (const day of sortedDays) {
    const date = new Date(`${day}T00:00:00Z`);
    if (previous && date.getTime() - previous.getTime() === 86_400_000) {
      current += 1;
    } else {
      current = 1;
    }
    longest = Math.max(longest, current);
    previous = date;
  }
  return longest;
}

export default router;
