import cors from 'cors';
import express from 'express';
import authRouter from './routes/auth';
import challengesRouter from './routes/challenges';
import devicesRouter from './routes/devices';
import syncRouter from './routes/sync';

export const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));

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
