import { Router } from 'express';
import { z } from 'zod';
import { AuthedRequest, requireAuth } from '../middleware/auth';
import { prisma } from '../prismaClient';

const router = Router();
router.use(requireAuth);

const feedbackSchema = z.object({
  category: z.string().trim().max(40).optional(),
  message: z.string().trim().min(1).max(2000),
});

/// The only inbox for in-app "report a problem / feedback" submissions —
/// reviewed and resolved from the /admin panel, there is no other channel.
router.post('/', async (req: AuthedRequest, res) => {
  const parsed = feedbackSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input', details: parsed.error.flatten() });
    return;
  }
  await prisma.feedback.create({
    data: { userId: req.userId!, category: parsed.data.category || null, message: parsed.data.message },
  });
  res.status(201).json({ ok: true });
});

export default router;
