import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../../app';

function uniqueEmail(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
}

describe('POST /auth/register', () => {
  it('registers with a valid payload and accepted terms', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ email: uniqueEmail('reg-ok'), password: 'password123', acceptedTerms: true });
    expect(res.status).toBe(201);
    expect(res.body.token).toBeTypeOf('string');
    expect(res.body.emailVerified).toBe(false);
  });

  // The server must not trust a client-side checkbox alone for something
  // with this much legal weight — this is the whole point of making
  // acceptedTerms a required, server-validated field.
  it('rejects registration without acceptedTerms', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ email: uniqueEmail('reg-no-terms'), password: 'password123' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_input');
  });

  it('rejects a duplicate email', async () => {
    const email = uniqueEmail('reg-dup');
    await request(app)
      .post('/auth/register')
      .send({ email, password: 'password123', acceptedTerms: true });
    const res = await request(app)
      .post('/auth/register')
      .send({ email, password: 'password123', acceptedTerms: true });
    expect(res.status).toBe(409);
    expect(res.body.error).toBe('email_taken');
  });
});

describe('POST /auth/login', () => {
  it('logs in with correct credentials', async () => {
    const email = uniqueEmail('login-ok');
    await request(app)
      .post('/auth/register')
      .send({ email, password: 'password123', acceptedTerms: true });
    const res = await request(app).post('/auth/login').send({ email, password: 'password123' });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeTypeOf('string');
  });

  // Same error for "no such user" and "wrong password" — a status/error
  // regression here would start leaking which emails are registered.
  it('rejects a wrong password with the generic invalid_credentials error', async () => {
    const email = uniqueEmail('login-wrong');
    await request(app)
      .post('/auth/register')
      .send({ email, password: 'password123', acceptedTerms: true });
    const res = await request(app).post('/auth/login').send({ email, password: 'wrongpassword' });
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('invalid_credentials');
  });
});

describe('GET /auth/verify-email', () => {
  // Regression test for the reflected-XSS fix: a token that doesn't match
  // the 64-char hex shape must be rejected before it ever reaches a DB
  // lookup or gets interpolated into the response page.
  it('rejects a token that is not a 64-char hex string', async () => {
    const res = await request(app)
      .get('/auth/verify-email')
      .query({ token: '<script>not-a-real-token</script>' });
    expect(res.status).toBe(400);
  });
});
