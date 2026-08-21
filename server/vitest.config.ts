import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    // bcrypt (cost 12) plus a real DB round-trip per test adds up —
    // vitest's 5s default was too tight even for a handful of these.
    testTimeout: 15000,
    env: {
      JWT_SECRET: 'test-secret-not-for-production-use-0123456789abcdef',
      // The auth endpoints' rate limiter is tuned for real credential
      // guessing, not a test suite that registers/logs in a dozen times in
      // a few seconds — without this override, later tests start failing
      // with 429s depending on run order.
      AUTH_RATE_LIMIT_MAX: '1000',
      AUTH_RATE_LIMIT_WINDOW_MIN: '60',
      // DATABASE_URL is intentionally NOT set here — it must come from the
      // real environment (CI's postgres service, or a local override), so
      // a missing one fails with env.ts's own clear "Missing required env
      // var" message instead of a fake connection string masking it.
    },
  },
});
