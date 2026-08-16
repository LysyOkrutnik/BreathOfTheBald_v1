import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prismaClient';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

const sessionSchema = z.object({
  id: z.string().min(1),
  levelKey: z.string(),
  timestamp: z.string().datetime(),
  durationSec: z.number().int(),
  rounds: z.number().int(),
  retentionSec: z.number().int(),
  rpeScore: z.number().int().nullable().optional(),
  xpEarned: z.number().int(),
});

const freedivingLogSchema = z.object({
  id: z.string().min(1),
  tableType: z.string(),
  pbUsedSec: z.number().int(),
  roundsJson: z.string(),
  roundsCompleted: z.number().int(),
  durationSec: z.number().int(),
  timestamp: z.string().datetime(),
  rpeScore: z.number().int().nullable().optional(),
});

const customPresetSchema = z.object({
  id: z.string().min(1),
  name: z.string(),
  inhaleSec: z.number().int(),
  holdInSec: z.number().int(),
  exhaleSec: z.number().int(),
  holdOutSec: z.number().int(),
  cycles: z.number().int(),
  rounds: z.number().int(),
  createdAt: z.string().datetime(),
  deletedAt: z.string().datetime().nullable().optional(),
});

const customFreedivingPresetSchema = z.object({
  id: z.string().min(1),
  name: z.string(),
  startApneaSec: z.number().int(),
  endApneaSec: z.number().int(),
  startRestSec: z.number().int(),
  endRestSec: z.number().int(),
  rounds: z.number().int(),
  createdAt: z.string().datetime(),
  deletedAt: z.string().datetime().nullable().optional(),
});

const profileStateSchema = z.object({
  verifiedPbSec: z.number().int().nullable().optional(),
  verifiedPbAt: z.string().datetime().nullable().optional(),
  safetyAcknowledgedAt: z.string().datetime().nullable().optional(),
  wimHofCurrentLevelKey: z.string().nullable().optional(),
  wimHofCurrentLevelSetAt: z.string().datetime().nullable().optional(),
  availableWeekdaysMask: z.number().int().nullable().optional(),
  availableHourStart: z.number().int().nullable().optional(),
  availableHourEnd: z.number().int().nullable().optional(),
  allowMultiplePerDay: z.boolean().nullable().optional(),
  dailyReminderEnabled: z.boolean().nullable().optional(),
  clientUpdatedAt: z.string().datetime(),
});

const pushSchema = z.object({
  sessions: z.array(sessionSchema).default([]),
  freedivingLogs: z.array(freedivingLogSchema).default([]),
  customPresets: z.array(customPresetSchema).default([]),
  customFreedivingPresets: z.array(customFreedivingPresetSchema).default([]),
  profileState: profileStateSchema.nullable().optional(),
});

/// Append-only rows (Session, FreedivingLog) are owned by whoever created
/// them and never move between users. A client-generated [id] could in
/// theory collide with another user's row; `updateMany` scoped to
/// `{ id, userId }` only ever touches the caller's own data, and a create
/// that hits a foreign id throws a unique-constraint error we simply skip
/// rather than surface, since it's not something the client can act on.
async function upsertOwnedById<T extends { id: string }>(
  model: { updateMany: Function; create: Function },
  userId: string,
  row: T,
  toData: (row: T) => Record<string, unknown>,
): Promise<'updated' | 'created' | 'skipped'> {
  const data = toData(row);
  const updated = await model.updateMany({ where: { id: row.id, userId }, data });
  if (updated.count > 0) return 'updated';
  try {
    await model.create({ data: { ...data, id: row.id, userId } });
    return 'created';
  } catch {
    return 'skipped';
  }
}

router.post('/', async (req: AuthedRequest, res) => {
  const parsed = pushSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input', details: parsed.error.flatten() });
    return;
  }
  const userId = req.userId!;
  const body = parsed.data;

  const sessionResults = await Promise.all(
    body.sessions.map((row) =>
      upsertOwnedById(prisma.session, userId, row, (r) => ({
        levelKey: r.levelKey,
        timestamp: new Date(r.timestamp),
        durationSec: r.durationSec,
        rounds: r.rounds,
        retentionSec: r.retentionSec,
        rpeScore: r.rpeScore ?? null,
        xpEarned: r.xpEarned,
      })),
    ),
  );

  const freedivingResults = await Promise.all(
    body.freedivingLogs.map((row) =>
      upsertOwnedById(prisma.freedivingLog, userId, row, (r) => ({
        tableType: r.tableType,
        pbUsedSec: r.pbUsedSec,
        roundsJson: r.roundsJson,
        roundsCompleted: r.roundsCompleted,
        durationSec: r.durationSec,
        timestamp: new Date(r.timestamp),
        rpeScore: r.rpeScore ?? null,
      })),
    ),
  );

  const customPresetResults = await Promise.all(
    body.customPresets.map((row) =>
      upsertOwnedById(prisma.customPreset, userId, row, (r) => ({
        name: r.name,
        inhaleSec: r.inhaleSec,
        holdInSec: r.holdInSec,
        exhaleSec: r.exhaleSec,
        holdOutSec: r.holdOutSec,
        cycles: r.cycles,
        rounds: r.rounds,
        createdAt: new Date(r.createdAt),
        deletedAt: r.deletedAt ? new Date(r.deletedAt) : null,
      })),
    ),
  );

  const customFreedivingPresetResults = await Promise.all(
    body.customFreedivingPresets.map((row) =>
      upsertOwnedById(prisma.customFreedivingPreset, userId, row, (r) => ({
        name: r.name,
        startApneaSec: r.startApneaSec,
        endApneaSec: r.endApneaSec,
        startRestSec: r.startRestSec,
        endRestSec: r.endRestSec,
        rounds: r.rounds,
        createdAt: new Date(r.createdAt),
        deletedAt: r.deletedAt ? new Date(r.deletedAt) : null,
      })),
    ),
  );

  let profileState = await prisma.profileState.findUnique({ where: { userId } });
  if (body.profileState) {
    const incomingClientUpdatedAt = new Date(body.profileState.clientUpdatedAt);
    const isNewer = !profileState || incomingClientUpdatedAt > profileState.clientUpdatedAt;
    if (isNewer) {
      const { clientUpdatedAt, ...rest } = body.profileState;
      profileState = await prisma.profileState.upsert({
        where: { userId },
        create: {
          userId,
          ...rest,
          verifiedPbAt: rest.verifiedPbAt ? new Date(rest.verifiedPbAt) : null,
          safetyAcknowledgedAt: rest.safetyAcknowledgedAt ? new Date(rest.safetyAcknowledgedAt) : null,
          wimHofCurrentLevelSetAt: rest.wimHofCurrentLevelSetAt ? new Date(rest.wimHofCurrentLevelSetAt) : null,
          clientUpdatedAt: incomingClientUpdatedAt,
        },
        update: {
          ...rest,
          verifiedPbAt: rest.verifiedPbAt ? new Date(rest.verifiedPbAt) : null,
          safetyAcknowledgedAt: rest.safetyAcknowledgedAt ? new Date(rest.safetyAcknowledgedAt) : null,
          wimHofCurrentLevelSetAt: rest.wimHofCurrentLevelSetAt ? new Date(rest.wimHofCurrentLevelSetAt) : null,
          clientUpdatedAt: incomingClientUpdatedAt,
        },
      });
    }
    // If not newer, `profileState` already holds the authoritative (newer)
    // server row — returned as-is so the client can adopt it instead.
  }

  res.json({
    sessions: summarize(sessionResults),
    freedivingLogs: summarize(freedivingResults),
    customPresets: summarize(customPresetResults),
    customFreedivingPresets: summarize(customFreedivingPresetResults),
    profileState,
    serverTime: new Date().toISOString(),
  });
});

function summarize(results: Array<'updated' | 'created' | 'skipped'>) {
  return {
    updated: results.filter((r) => r === 'updated').length,
    created: results.filter((r) => r === 'created').length,
    skipped: results.filter((r) => r === 'skipped').length,
  };
}

router.get('/', async (req: AuthedRequest, res) => {
  const userId = req.userId!;
  const sinceRaw = typeof req.query.since === 'string' ? req.query.since : undefined;
  const since = sinceRaw && !Number.isNaN(Date.parse(sinceRaw)) ? new Date(sinceRaw) : undefined;

  const [sessions, freedivingLogs, customPresets, customFreedivingPresets, profileState] = await Promise.all([
    prisma.session.findMany({ where: { userId, ...(since && { updatedAt: { gt: since } }) } }),
    prisma.freedivingLog.findMany({ where: { userId, ...(since && { updatedAt: { gt: since } }) } }),
    prisma.customPreset.findMany({ where: { userId, ...(since && { updatedAt: { gt: since } }) } }),
    prisma.customFreedivingPreset.findMany({ where: { userId, ...(since && { updatedAt: { gt: since } }) } }),
    prisma.profileState.findUnique({ where: { userId } }),
  ]);

  res.json({
    sessions,
    freedivingLogs,
    customPresets,
    customFreedivingPresets,
    // Omit if it hasn't changed since `since` — an unconditional include
    // would make every incremental pull look like a settings change.
    profileState: !since || (profileState && profileState.updatedAt > since) ? profileState : null,
    serverTime: new Date().toISOString(),
  });
});

export default router;
