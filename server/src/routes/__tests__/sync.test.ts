import crypto from 'node:crypto';
import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../../app';

async function registerAndGetToken(prefix: string): Promise<string> {
  const email = `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
  const res = await request(app)
    .post('/auth/register')
    .send({ email, password: 'password123', acceptedTerms: true });
  return res.body.token as string;
}

function sessionRow(timestamp: string) {
  return {
    id: crypto.randomUUID(),
    levelKey: 'box_breathing',
    timestamp,
    durationSec: 60,
    rounds: 1,
    retentionSec: 0,
    xpEarned: 10,
  };
}

describe('POST /sync', () => {
  // This is the exact shape of the bug that broke sync in production:
  // Dart's DateTime.toIso8601String() omits the "Z" suffix for a
  // non-UTC DateTime, and zod's .datetime() requires it — every push
  // containing real (non-UTC-normalized) data was silently rejected.
  it('rejects a session timestamp without a UTC "Z" suffix', async () => {
    const token = await registerAndGetToken('sync-no-z');
    const res = await request(app)
      .post('/sync')
      .set('Authorization', `Bearer ${token}`)
      .send({ sessions: [sessionRow('2026-08-21T10:00:00')] });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_input');
  });

  it('accepts a session timestamp with a UTC "Z" suffix', async () => {
    const token = await registerAndGetToken('sync-with-z');
    const res = await request(app)
      .post('/sync')
      .set('Authorization', `Bearer ${token}`)
      .send({ sessions: [sessionRow('2026-08-21T10:00:00.000Z')] });
    expect(res.status).toBe(200);
    expect(res.body.sessions).toEqual({ updated: 0, created: 1, skipped: 0 });
  });

  it('rejects a request with no Authorization header', async () => {
    const res = await request(app)
      .post('/sync')
      .send({ sessions: [sessionRow('2026-08-21T10:00:00.000Z')] });
    expect(res.status).toBe(401);
  });
});
