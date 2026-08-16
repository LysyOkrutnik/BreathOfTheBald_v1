import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prismaClient';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

const registerSchema = z.object({
  fcmToken: z.string().min(1),
});

// One token per user, not per device — the app is single-account/single-
// active-device from FCM's point of view, so the latest registration simply
// replaces the previous one.
router.post('/register', async (req: AuthedRequest, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  await prisma.user.update({
    where: { id: req.userId! },
    data: { fcmToken: parsed.data.fcmToken },
  });
  res.status(204).end();
});

router.delete('/register', async (req: AuthedRequest, res) => {
  await prisma.user.update({ where: { id: req.userId! }, data: { fcmToken: null } });
  res.status(204).end();
});

export default router;
