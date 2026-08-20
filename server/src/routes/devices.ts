import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prismaClient';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

const registerSchema = z.object({
  fcmToken: z.string().min(1),
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
    create: { userId: req.userId!, fcmToken: parsed.data.fcmToken },
    update: { userId: req.userId! },
  });
  res.status(204).end();
});

/// Unregisters only the calling device's token, not every device on the
/// account.
router.delete('/register', async (req: AuthedRequest, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  await prisma.device.deleteMany({
    where: { userId: req.userId!, fcmToken: parsed.data.fcmToken },
  });
  res.status(204).end();
});

export default router;
