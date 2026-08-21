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

/// Every real token is exactly this shape (`randomToken()`'s own output —
/// 32 random bytes as hex). Rejecting anything else *before* it ever
/// reaches a DB lookup or an HTML response means a query-string value that
/// isn't a real token can never contain characters that matter to HTML/JS,
/// which is what actually closes off the XSS class of bug below — treating
/// this as a defense mechanism, not just a shape check.
const TOKEN_PATTERN = /^[0-9a-f]{64}$/;

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

/// Minimal, self-contained HTML page — no template engine in this project,
/// and one isn't worth adding for two small pages.
function htmlPage(title: string, bodyHtml: string): string {
  return `<!doctype html><html lang="pl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
body{background:#040D14;color:#F5F5F5;font-family:system-ui,-apple-system,sans-serif;
display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:24px;box-sizing:border-box}
.card{max-width:400px;text-align:center}
h1{font-size:20px;font-weight:600;margin-bottom:12px}
p{color:#B0BEC5;font-size:14px;line-height:1.5}
input{width:100%;padding:12px;margin:8px 0;border-radius:8px;border:1px solid #444;
background:#111;color:#F5F5F5;box-sizing:border-box;font-size:14px}
button{width:100%;padding:12px;margin-top:8px;border-radius:8px;border:none;
background:#81C784;color:#000;font-weight:700;font-size:14px;cursor:pointer}
.err{color:#E57373}
</style></head><body><div class="card">${bodyHtml}</div></body></html>`;
}

/// The email link is a plain hyperlink, so email clients/browsers always
/// open it as a GET — the token is verified immediately and a plain
/// confirmation page is shown, with no app installation or deep-link
/// handling required.
router.get('/verify-email', async (req, res) => {
  const token = typeof req.query.token === 'string' ? req.query.token : '';
  const user = TOKEN_PATTERN.test(token)
    ? await prisma.user.findUnique({ where: { emailVerificationToken: token } })
    : null;
  if (!user || !user.emailVerificationExpiresAt || user.emailVerificationExpiresAt < new Date()) {
    res.status(400).type('html').send(htmlPage('Link nieprawidłowy',
      '<h1>Link jest nieprawidłowy lub wygasł</h1><p>Wróć do aplikacji i wyślij weryfikację ponownie.</p>'));
    return;
  }
  await prisma.user.update({
    where: { id: user.id },
    data: { emailVerified: true, emailVerificationToken: null, emailVerificationExpiresAt: null },
  });
  res.type('html').send(htmlPage('E-mail potwierdzony',
    '<h1>E-mail potwierdzony ✓</h1><p>Możesz zamknąć tę stronę i wrócić do aplikacji.</p>'));
});

/// JSON equivalent of the GET route above — same verification logic,
/// for a client that already has the token in hand (e.g. a future in-app
/// "enter the code from your email" flow) rather than following a link.
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

router.post('/resend-verification', authRateLimiter, requireAuth, async (req: AuthedRequest, res) => {
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

/// Same reasoning as GET /verify-email — the emailed link is a plain
/// hyperlink, so it needs a browser-renderable page. Unlike verification
/// this needs the user's input (a new password), so it renders a small
/// form whose submit handler calls the existing POST /reset-password JSON
/// endpoint via fetch — no new server-side submission logic, no HTML
/// form-encoding middleware to add.
router.get('/reset-password', (req, res) => {
  const token = typeof req.query.token === 'string' ? req.query.token : '';
  // Validated *before* it's ever interpolated into the page below — see
  // TOKEN_PATTERN's comment. A token that fails this can never carry `<`,
  // `>`, quotes, or `/`, closing off the injection this used to allow via
  // a crafted ?token= value (JSON.stringify alone doesn't escape `/`, so a
  // token containing `</script>` could break out of the inline <script>
  // block and inject arbitrary markup).
  if (!TOKEN_PATTERN.test(token)) {
    res.status(400).type('html').send(htmlPage('Link nieprawidłowy',
      '<h1>Link jest nieprawidłowy</h1><p>Wróć do aplikacji i wyślij prośbę o reset ponownie.</p>'));
    return;
  }
  res.type('html').send(htmlPage('Reset hasła', `
    <h1>Ustaw nowe hasło</h1>
    <form id="f">
      <input type="password" id="pw" placeholder="Nowe hasło (min. 8 znaków)" minlength="8" required>
      <button type="submit">ZAPISZ</button>
    </form>
    <p id="msg"></p>
    <script>
      document.getElementById('f').addEventListener('submit', async (e) => {
        e.preventDefault();
        const msg = document.getElementById('msg');
        msg.textContent = '...';
        msg.className = '';
        try {
          const res = await fetch('/auth/reset-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: ${JSON.stringify(token)}, newPassword: document.getElementById('pw').value }),
          });
          if (res.ok) {
            msg.textContent = 'Hasło zmienione. Możesz zamknąć tę stronę i zalogować się w aplikacji.';
          } else {
            msg.textContent = 'Link jest nieprawidłowy lub wygasł. Wróć do aplikacji i wyślij prośbę ponownie.';
            msg.className = 'err';
          }
        } catch {
          msg.textContent = 'Nie udało się połączyć z serwerem. Spróbuj ponownie.';
          msg.className = 'err';
        }
      });
    </script>
  `));
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

/// Lets the client re-check account state that can change out-of-band from
/// this device — chiefly `emailVerified`, which the GET /verify-email link
/// above flips server-side with no way to notify a signed-in client on its
/// own. The client's cached copy (read at login/register time) would
/// otherwise show "unverified" forever after a real, successful
/// verification, until the next full re-login.
router.get('/me', requireAuth, async (req: AuthedRequest, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.userId! },
    select: { email: true, emailVerified: true },
  });
  if (!user) {
    res.status(404).json({ error: 'not_found' });
    return;
  }
  res.json({ email: user.email, emailVerified: user.emailVerified });
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
