import express from 'express';
import authRouter from './routes/auth';
import challengesRouter from './routes/challenges';
import devicesRouter from './routes/devices';
import syncRouter from './routes/sync';
import { prisma } from './prismaClient';

export const app = express();

// Sits behind Nginx Proxy Manager on the same Docker network — every request
// carries an X-Forwarded-For header from that one hop. Without this,
// express-rate-limit refuses to trust that header (ERR_ERL_UNEXPECTED_X_FORWARDED_FOR)
// and throws on every rate-limited request, breaking login/register/sync entirely.
app.set('trust proxy', 1);

// No CORS middleware at all, deliberately — this API has no browser-based
// client (only the Flutter app's plain HTTP requests, which aren't subject
// to CORS in the first place). Enabling `cors()` here would only ever have
// widened the attack surface for no benefit.
app.use(express.json());

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
