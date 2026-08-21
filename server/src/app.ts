import express from 'express';
import adminRouter from './routes/admin';
import authRouter from './routes/auth';
import challengesRouter from './routes/challenges';
import devicesRouter from './routes/devices';
import feedbackRouter from './routes/feedback';
import syncRouter from './routes/sync';
import { prisma } from './prismaClient';
import { AuthedRequest } from './middleware/auth';

export const app = express();

// Sits behind Nginx Proxy Manager on the same Docker network — every request
// carries an X-Forwarded-For header from that one hop. Without this,
// express-rate-limit refuses to trust that header (ERR_ERL_UNEXPECTED_X_FORWARDED_FOR)
// and throws on every rate-limited request, breaking login/register/sync entirely.
app.set('trust proxy', 1);

// No CORS middleware at all, deliberately — the mobile app's plain HTTP
// requests aren't subject to CORS in the first place, and the /admin panel
// below is a same-origin, server-rendered page (no fetch() calls to worry
// about). Enabling `cors()` here would only ever have widened the attack
// surface for no benefit.
app.use(express.json());

// Structured one-line-per-request log to stdout (captured by Docker/Portainer
// container logs) — previously nothing at all was logged per-request, which
// made a real production bug (broken sync/verification links) far harder to
// diagnose than it needed to be. `res.on('finish')` runs after the route
// handler, so status/duration are always the real outcome, not a guess.
app.use((req: AuthedRequest, res, next) => {
  const startedAt = Date.now();
  res.on('finish', () => {
    console.log(
      JSON.stringify({
        method: req.method,
        path: req.path,
        status: res.statusCode,
        ms: Date.now() - startedAt,
        userId: req.userId ?? null,
      }),
    );
  });
  next();
});

app.get('/health', async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ ok: true, db: true });
  } catch (err) {
    console.error('[health] database check failed:', err);
    res.status(503).json({ ok: false, db: false });
  }
});

app.use('/auth', authRouter);
app.use('/sync', syncRouter);
app.use('/devices', devicesRouter);
app.use('/challenges', challengesRouter);
app.use('/feedback', feedbackRouter);
// Never linked from, or checked by, anything in the mobile app — this is
// the entire admin surface, reachable only by someone who already knows
// this exact path and holds an admin account (see requireAdmin).
app.use('/admin', adminRouter);

app.use((_req, res) => {
  res.status(404).json({ error: 'not_found' });
});

// Express 5 forwards rejected async handlers here automatically. Without
// this, the default handler returns an HTML page with the raw stack trace —
// useless to the Flutter client and a needless leak of internals.
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[app] unhandled error:', err);
  res.status(500).json({ error: 'internal_error' });
});
