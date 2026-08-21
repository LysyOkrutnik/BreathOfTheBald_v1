import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prismaClient';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

const registerSchema = z.object({
  fcmToken: z.string().min(1),
  // Short human-readable description ("SM-A546B, Android 14") — purely so
  // the device-management list in Settings shows something more useful
  // than a bare registration date. Never required: older clients (and any
  // future platform that can't produce one) just register without it.
  label: z.string().trim().min(1).max(80).optional(),
});

/// One row per device — a user with two phones stays registered on both;
/// logging in on a second device no longer silently kills push on the
/// first (which a single `fcmToken` column on User used to do). `fcmToken`
/// is globally unique, so re-registering the same token (e.g. the app
/// re-registering on every cold start) just re-points it at this user
/// instead of erroring.
router.post('/register', async (req: AuthedRequest, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  await prisma.device.upsert({
    where: { fcmToken: parsed.data.fcmToken },
    create: { userId: req.userId!, fcmToken: parsed.data.fcmToken, label: parsed.data.label },
    update: { userId: req.userId!, label: parsed.data.label },
  });
  res.status(204).end();
});

/// Unregisters only the calling device's token, not every device on the
/// account.
router.delete('/register', async (req: AuthedRequest, res) => {
  const parsed = registerSchema.pick({ fcmToken: true }).safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  await prisma.device.deleteMany({
    where: { userId: req.userId!, fcmToken: parsed.data.fcmToken },
  });
  res.status(204).end();
});

/// Backs the "manage devices" list in Settings — deliberately never
/// returns `fcmToken` itself, there's no reason for the client to see the
/// raw push token for a device it isn't currently running on.
router.get('/', async (req: AuthedRequest, res) => {
  const devices = await prisma.device.findMany({
    where: { userId: req.userId! },
    orderBy: { createdAt: 'desc' },
    select: { id: true, label: true, createdAt: true },
  });
  res.json(devices);
});

/// Removing a device here only stops push to it — it does not log it out
/// (that's still only "Wyloguj wszędzie", which revokes every token via
/// `tokenVersion`; there's no per-device session to revoke individually).
router.delete('/:id', async (req: AuthedRequest, res) => {
  await prisma.device.deleteMany({
    where: { id: req.params.id as string, userId: req.userId! },
  });
  res.status(204).end();
});

export default router;
