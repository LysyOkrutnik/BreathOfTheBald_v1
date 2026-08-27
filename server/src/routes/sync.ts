import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prismaClient';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

// A user with an unbounded history would otherwise get every row back in
// one response (no `take`); this caps each pull, and the client keeps
// pulling with an updated `since` (the last row's own updatedAt) until a
// page comes back under the limit.
const PAGE_SIZE = 500;

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
  symptomTag: z.string().nullable().optional(),
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
  verifiedPbCo2Sec: z.number().int().nullable().optional(),
  verifiedPbCo2At: z.string().datetime().nullable().optional(),
  safetyAcknowledgedAt: z.string().datetime().nullable().optional(),
  wimHofCurrentLevelKey: z.string().nullable().optional(),
  wimHofCurrentLevelSetAt: z.string().datetime().nullable().optional(),
  availableWeekdaysMask: z.number().int().nullable().optional(),
  availableHourStart: z.number().int().nullable().optional(),
  availableHourEnd: z.number().int().nullable().optional(),
  allowMultiplePerDay: z.boolean().nullable().optional(),
  dailyReminderEnabled: z.boolean().nullable().optional(),
  // IANA name (e.g. "Europe/Warsaw") — see the matching schema.prisma doc
  // comment on ProfileState.timezone for what this is used for.
  timezone: z.string().max(64).nullable().optional(),
  clientUpdatedAt: z.string().datetime(),
});

// A push this large from one real device in one request would already be
// unusual (offline for a very long time); the cap exists to bound how many
// concurrent per-row DB round-trips a single request can trigger (see
// `Promise.all` below), not because a genuine backlog this size is expected.
const MAX_PUSH_BATCH = 1000;

const pushSchema = z.object({
  sessions: z.array(sessionSchema).max(MAX_PUSH_BATCH).default([]),
  freedivingLogs: z.array(freedivingLogSchema).max(MAX_PUSH_BATCH).default([]),
  customPresets: z.array(customPresetSchema).max(MAX_PUSH_BATCH).default([]),
  customFreedivingPresets: z.array(customFreedivingPresetSchema).max(MAX_PUSH_BATCH).default([]),
  profileState: profileStateSchema.nullable().optional(),
});

/// For append-only rows (Session, FreedivingLog): creates the row on first
/// sight, but an update only ever writes [mutableData] — the couple of
/// fields that can legitimately change after creation (rpeScore,
/// symptomTag) — never the whole row. A full-row overwrite here would let a
/// device pushing a stale local copy silently clobber a field another
/// device already set (e.g. an RPE rating attached after this row last
/// synced elsewhere).
async function upsertAppendOnly<T extends { id: string }>(
  model: { updateMany: Function; create: Function },
  userId: string,
  row: T,
  fullData: (row: T) => Record<string, unknown>,
  mutableData: (row: T) => Record<string, unknown>,
): Promise<'updated' | 'created' | 'skipped'> {
  const updated = await model.updateMany({ where: { id: row.id, userId }, data: mutableData(row) });
  if (updated.count > 0) return 'updated';
  try {
    await model.create({ data: { ...fullData(row), id: row.id, userId } });
    return 'created';
  } catch {
    return 'skipped';
  }
}

/// For presets: real CRUD, but with no "edit" flow on the client at all —
/// the only two things that can happen to an existing row are (a) nothing,
/// it's immutable once created, or (b) a soft-delete. So an update here
/// only ever touches [deletedAt], and only to set it (never to clear it —
/// a stale push from a device that doesn't yet know about a deletion must
/// never resurrect a preset another device already deleted).
async function upsertPreset<T extends { id: string; deletedAt?: string | null }>(
  model: { updateMany: Function; create: Function },
  userId: string,
  row: T,
  fullData: (row: T) => Record<string, unknown>,
): Promise<'updated' | 'created' | 'skipped'> {
  if (row.deletedAt) {
    const updated = await model.updateMany({
      where: { id: row.id, userId },
      data: { deletedAt: new Date(row.deletedAt) },
    });
    if (updated.count > 0) return 'updated';
  }
  try {
    await model.create({ data: { ...fullData(row), id: row.id, userId } });
    return 'created';
  } catch {
    return 'skipped';
  }
}

/// Atomically applies [data] to the user's ProfileState only if
/// [incomingClientUpdatedAt] is newer than whatever's already stored — the
/// `WHERE clientUpdatedAt < incoming` guard is a single atomic SQL UPDATE,
/// so two concurrent pushes from different devices can never both believe
/// they "won" a stale check-then-act read.
async function upsertProfileStateIfNewer(
  userId: string,
  data: Record<string, unknown>,
  incomingClientUpdatedAt: Date,
): Promise<void> {
  const updated = await prisma.profileState.updateMany({
    where: { userId, clientUpdatedAt: { lt: incomingClientUpdatedAt } },
    data: { ...data, clientUpdatedAt: incomingClientUpdatedAt },
  });
  if (updated.count > 0) return;

  const existing = await prisma.profileState.findUnique({ where: { userId } });
  if (existing) return; // Existing row is already >= incoming — it wins, nothing to do.

  try {
    await prisma.profileState.create({
      data: { userId, ...data, clientUpdatedAt: incomingClientUpdatedAt },
    });
  } catch {
    // Lost a create race to a concurrent first push — a row exists now,
    // so the conditional update path applies.
    await prisma.profileState.updateMany({
      where: { userId, clientUpdatedAt: { lt: incomingClientUpdatedAt } },
      data: { ...data, clientUpdatedAt: incomingClientUpdatedAt },
    });
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

  // These 4 batches touch different tables with no data dependency between
  // them — an outer Promise.all lets them run concurrently instead of one
  // fully finishing before the next starts, so a routine push (a frequent
  // operation) pays roughly 1 round-trip's worth of latency instead of 4.
  const [sessionResults, freedivingResults, customPresetResults, customFreedivingPresetResults] =
    await Promise.all([
      Promise.all(
        body.sessions.map((row) =>
          upsertAppendOnly(
            prisma.session,
            userId,
            row,
            (r) => ({
              levelKey: r.levelKey,
              timestamp: new Date(r.timestamp),
              durationSec: r.durationSec,
              rounds: r.rounds,
              retentionSec: r.retentionSec,
              rpeScore: r.rpeScore ?? null,
              xpEarned: r.xpEarned,
            }),
            (r) => ({ rpeScore: r.rpeScore ?? null }),
          ),
        ),
      ),
      Promise.all(
        body.freedivingLogs.map((row) =>
          upsertAppendOnly(
            prisma.freedivingLog,
            userId,
            row,
            (r) => ({
              tableType: r.tableType,
              pbUsedSec: r.pbUsedSec,
              roundsJson: r.roundsJson,
              roundsCompleted: r.roundsCompleted,
              durationSec: r.durationSec,
              timestamp: new Date(r.timestamp),
              rpeScore: r.rpeScore ?? null,
              symptomTag: r.symptomTag ?? null,
            }),
            (r) => ({ rpeScore: r.rpeScore ?? null, symptomTag: r.symptomTag ?? null }),
          ),
        ),
      ),
      Promise.all(
        body.customPresets.map((row) =>
          upsertPreset(prisma.customPreset, userId, row, (r) => ({
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
      ),
      Promise.all(
        body.customFreedivingPresets.map((row) =>
          upsertPreset(prisma.customFreedivingPreset, userId, row, (r) => ({
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
      ),
    ]);

  if (body.profileState) {
    const { clientUpdatedAt, ...rest } = body.profileState;
    const incomingClientUpdatedAt = new Date(clientUpdatedAt);
    await upsertProfileStateIfNewer(
      userId,
      {
        ...rest,
        verifiedPbAt: rest.verifiedPbAt ? new Date(rest.verifiedPbAt) : null,
        verifiedPbCo2At: rest.verifiedPbCo2At ? new Date(rest.verifiedPbCo2At) : null,
        safetyAcknowledgedAt: rest.safetyAcknowledgedAt ? new Date(rest.safetyAcknowledgedAt) : null,
        wimHofCurrentLevelSetAt: rest.wimHofCurrentLevelSetAt
          ? new Date(rest.wimHofCurrentLevelSetAt)
          : null,
      },
      incomingClientUpdatedAt,
    );
  }
  // Always return the current authoritative row — whichever push actually
  // won (this one, an earlier one, or a concurrent one), the client should
  // adopt it.
  const profileState = await prisma.profileState.findUnique({ where: { userId } });

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
  const whereSince = since ? { updatedAt: { gt: since } } : {};

  const [sessions, freedivingLogs, customPresets, customFreedivingPresets, profileState] = await Promise.all([
    prisma.session.findMany({
      where: { userId, ...whereSince },
      orderBy: { updatedAt: 'asc' },
      take: PAGE_SIZE,
    }),
    prisma.freedivingLog.findMany({
      where: { userId, ...whereSince },
      orderBy: { updatedAt: 'asc' },
      take: PAGE_SIZE,
    }),
    prisma.customPreset.findMany({
      where: { userId, ...whereSince },
      orderBy: { updatedAt: 'asc' },
      take: PAGE_SIZE,
    }),
    prisma.customFreedivingPreset.findMany({
      where: { userId, ...whereSince },
      orderBy: { updatedAt: 'asc' },
      take: PAGE_SIZE,
    }),
    prisma.profileState.findUnique({ where: { userId } }),
  ]);

  // True if any table hit the page cap — the client should pull again with
  // `since` set to this response's own `serverTime` (well, more precisely:
  // to the max updatedAt actually seen) rather than assuming this was the
  // last page.
  const hasMore =
    sessions.length === PAGE_SIZE ||
    freedivingLogs.length === PAGE_SIZE ||
    customPresets.length === PAGE_SIZE ||
    customFreedivingPresets.length === PAGE_SIZE;

  res.json({
    sessions,
    freedivingLogs,
    customPresets,
    customFreedivingPresets,
    // Omit if it hasn't changed since `since` — an unconditional include
    // would make every incremental pull look like a settings change.
    profileState: !since || (profileState && profileState.updatedAt > since) ? profileState : null,
    hasMore,
    serverTime: new Date().toISOString(),
  });
});

export default router;
