import 'dotenv/config';

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

export const env = {
  port: Number(process.env.PORT ?? 8080),
  databaseUrl: required('DATABASE_URL'),
  jwtSecret: required('JWT_SECRET'),
  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
  notificationsCronHour: Number(process.env.NOTIFICATIONS_CRON_HOUR ?? 19),

  // SMTP is optional — when unset, the mailer logs the email content to the
  // console instead of sending it (dev-friendly fallback, same pattern as
  // Firebase push being optional). Set all four to actually deliver mail.
  smtpHost: process.env.SMTP_HOST,
  smtpPort: Number(process.env.SMTP_PORT ?? 587),
  smtpUser: process.env.SMTP_USER,
  smtpPassword: process.env.SMTP_PASSWORD,
  mailFrom: process.env.MAIL_FROM ?? 'no-reply@lysyweb.pl',

  // Base URL the verification/reset links point to — the Flutter app
  // intercepts these via an app link / deep link, not a browser page.
  appPublicUrl: process.env.APP_PUBLIC_URL ?? 'https://breath.lysyweb.pl',

  // Rate limiting — attempts allowed per IP within the window, for the
  // brute-force-prone auth endpoints.
  authRateLimitWindowMinutes: Number(process.env.AUTH_RATE_LIMIT_WINDOW_MIN ?? 15),
  authRateLimitMax: Number(process.env.AUTH_RATE_LIMIT_MAX ?? 10),
};
