import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { env } from '../env';
import { passwordResetEmailBody, sendMail, verificationEmailBody } from '../mailer';
import { AuthedRequest, requireAuth, signToken } from '../middleware/auth';
import { prisma } from '../prismaClient';

const router = Router();

// Applied only to the two endpoints that let someone test a
// password/credential guess — everything else needs a valid JWT already,
// which rate limiting doesn't meaningfully protect further.
const authRateLimiter = rateLimit({
  windowMs: env.authRateLimitWindowMinutes * 60 * 1000,
  limit: env.authRateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_attempts' },
});

const credentialsSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(8).max(128),
});

const VERIFICATION_TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const RESET_TOKEN_TTL_MS = 60 * 60 * 1000;

function randomToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

router.post('/register', authRateLimiter, async (req, res) => {
  const parsed = credentialsSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input', details: parsed.error.flatten() });
    return;
  }
  const { email, password } = parsed.data;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    res.status(409).json({ error: 'email_taken' });
    return;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const emailVerificationToken = randomToken();
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      emailVerificationToken,
      emailVerificationExpiresAt: new Date(Date.now() + VERIFICATION_TOKEN_TTL_MS),
    },
  });

  const { subject, text } = verificationEmailBody(emailVerificationToken);
  // Best-effort — a slow/broken mail provider must never block registration
  // itself; the user can request another verification email later.
  sendMail(email, subject, text).catch((err) => console.error('[auth] verification email failed:', err));

  res.status(201).json({
    token: signToken(user.id, user.tokenVersion),
    userId: user.id,
    emailVerified: false,
  });
});

router.post('/login', authRateLimiter, async (req, res) => {
  const parsed = credentialsSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  const { email, password } = parsed.data;

  const user = await prisma.user.findUnique({ where: { email } });
  // Same error for "no such user" and "wrong password" — don't leak which
  // one it was.
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    res.status(401).json({ error: 'invalid_credentials' });
    return;
  }

  res.json({
    token: signToken(user.id, user.tokenVersion),
    userId: user.id,
    emailVerified: user.emailVerified,
  });
});

/// The verification link (mailer.ts's `verificationEmailBody`) points at an
/// app deep link, not a browser page — the Flutter app intercepts it and
/// POSTs the token here itself, so this only ever needs a JSON API, not an
/// HTML confirmation page.
router.post('/verify-email', async (req, res) => {
  const parsed = z.object({ token: z.string().min(1) }).safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  const user = await prisma.user.findUnique({
    where: { emailVerificationToken: parsed.data.token },
  });
  if (!user || !user.emailVerificationExpiresAt || user.emailVerificationExpiresAt < new Date()) {
    res.status(400).json({ error: 'invalid_or_expired_token' });
    return;
  }
  await prisma.user.update({
    where: { id: user.id },
    data: { emailVerified: true, emailVerificationToken: null, emailVerificationExpiresAt: null },
  });
  res.status(204).end();
});

router.post('/resend-verification', requireAuth, async (req: AuthedRequest, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user) {
    res.status(404).json({ error: 'not_found' });
    return;
  }
  if (user.emailVerified) {
    res.status(204).end();
    return;
  }
  const emailVerificationToken = randomToken();
  await prisma.user.update({
    where: { id: user.id },
    data: {
      emailVerificationToken,
      emailVerificationExpiresAt: new Date(Date.now() + VERIFICATION_TOKEN_TTL_MS),
    },
  });
  const { subject, text } = verificationEmailBody(emailVerificationToken);
  sendMail(user.email, subject, text).catch((err) =>
    console.error('[auth] resend verification email failed:', err));
  res.status(204).end();
});

/// Always responds 204 whether or not the email exists — telling the caller
/// which emails are registered is its own information leak.
router.post('/forgot-password', authRateLimiter, async (req, res) => {
  const parsed = z.object({ email: z.string().trim().toLowerCase().email() }).safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
  if (user) {
    const passwordResetToken = randomToken();
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken,
        passwordResetExpiresAt: new Date(Date.now() + RESET_TOKEN_TTL_MS),
      },
    });
    const { subject, text } = passwordResetEmailBody(passwordResetToken);
    sendMail(user.email, subject, text).catch((err) =>
      console.error('[auth] password reset email failed:', err));
  }
  res.status(204).end();
});

router.post('/reset-password', authRateLimiter, async (req, res) => {
  const parsed = z
    .object({ token: z.string().min(1), newPassword: z.string().min(8).max(128) })
    .safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  const user = await prisma.user.findUnique({
    where: { passwordResetToken: parsed.data.token },
  });
  if (!user || !user.passwordResetExpiresAt || user.passwordResetExpiresAt < new Date()) {
    res.status(400).json({ error: 'invalid_or_expired_token' });
    return;
  }
  const passwordHash = await bcrypt.hash(parsed.data.newPassword, 12);
  const updated = await prisma.user.update({
    where: { id: user.id },
    data: {
      passwordHash,
      passwordResetToken: null,
      passwordResetExpiresAt: null,
      // A password reset is exactly the situation where every existing
      // session (including a possible attacker's) should be logged out.
      tokenVersion: { increment: 1 },
    },
  });
  res.json({ token: signToken(updated.id, updated.tokenVersion), userId: updated.id });
});

router.post('/change-password', requireAuth, async (req: AuthedRequest, res) => {
  const parsed = z
    .object({ currentPassword: z.string().min(1), newPassword: z.string().min(8).max(128) })
    .safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_input' });
    return;
  }
  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user || !(await bcrypt.compare(parsed.data.currentPassword, user.passwordHash))) {
    res.status(401).json({ error: 'invalid_credentials' });
    return;
  }
  const passwordHash = await bcrypt.hash(parsed.data.newPassword, 12);
  const updated = await prisma.user.update({
    where: { id: user.id },
    data: { passwordHash, tokenVersion: { increment: 1 } },
  });
  // Re-issue a token for *this* request's session so the user who just
  // changed their password isn't immediately logged out by their own
  // action — every *other* previously-issued token is now invalid.
  res.json({ token: signToken(updated.id, updated.tokenVersion) });
});

/// Sliding session: exchanges a still-valid token for a fresh one with a
/// new 90-day expiry, so an active user is never surprised by a hard
/// logout — only someone who stops opening the app for 90+ days is.
router.post('/refresh', requireAuth, async (req: AuthedRequest, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user) {
    res.status(404).json({ error: 'not_found' });
    return;
  }
  res.json({ token: signToken(user.id, user.tokenVersion) });
});

/// Invalidates every token ever issued for this account, including the one
/// used to make this request — the client is expected to also clear its
/// own stored token and show the login screen.
router.post('/logout-all', requireAuth, async (req: AuthedRequest, res) => {
  await prisma.user.update({
    where: { id: req.userId! },
    data: { tokenVersion: { increment: 1 } },
  });
  res.status(204).end();
});

/// Cascades to every owned row via the `onDelete: Cascade` relations in
/// schema.prisma — sessions, freediving logs, presets, profile state,
/// challenge participation, and devices all go with it.
router.delete('/me', requireAuth, async (req: AuthedRequest, res) => {
  await prisma.user.delete({ where: { id: req.userId! } });
  res.status(204).end();
});

export default router;
