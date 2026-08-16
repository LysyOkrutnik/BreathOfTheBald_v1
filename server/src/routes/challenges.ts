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
    include: { participants: { include: { user: { select: { id: true, profileName: true, email: true } } } } },
  });
  if (!challenge) {
    res.status(404).json({ error: 'not_found' });
    return;
  }

  const window = { gte: challenge.startsAt, lte: challenge.endsAt };
  const entries = await Promise.all(
    challenge.participants.map(async (p) => {
      const value = await computeMetricValue(p.userId, challenge.metric, window);
      return {
        userId: p.userId,
        displayName: p.user.profileName ?? p.user.email.split('@')[0],
        value,
      };
    }),
  );

  entries.sort((a, b) => b.value - a.value);
  res.json({
    challengeId: challenge.id,
    metric: challenge.metric,
    leaderboard: entries.map((e, i) => ({ rank: i + 1, ...e })),
  });
});

async function computeMetricValue(
  userId: string,
  metric: 'STREAK' | 'TOTAL_RETENTION_SEC' | 'SESSION_COUNT',
  window: { gte: Date; lte: Date },
): Promise<number> {
  if (metric === 'TOTAL_RETENTION_SEC') {
    const agg = await prisma.session.aggregate({
      where: { userId, timestamp: window },
      _sum: { retentionSec: true },
    });
    return agg._sum.retentionSec ?? 0;
  }

  const [sessions, freedivingLogs] = await Promise.all([
    prisma.session.findMany({ where: { userId, timestamp: window }, select: { timestamp: true } }),
    prisma.freedivingLog.findMany({ where: { userId, timestamp: window }, select: { timestamp: true } }),
  ]);

  if (metric === 'SESSION_COUNT') {
    return sessions.length + freedivingLogs.length;
  }

  // STREAK: longest run of consecutive calendar days with at least one
  // training logged inside the challenge window. This is a simplified,
  // self-contained metric distinct from the app's local day-gap/grace
  // streak — it only needs to be fair across participants, not identical
  // to the on-device definition.
  const days = new Set(
    [...sessions, ...freedivingLogs].map((r) => r.timestamp.toISOString().slice(0, 10)),
  );
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
