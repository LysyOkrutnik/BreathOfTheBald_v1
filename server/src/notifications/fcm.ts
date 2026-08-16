import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { env } from '../env';

/// Lazily initialized so the server can still start (auth/sync/challenges
/// all work) even before the user has created a Firebase project and set
/// FIREBASE_SERVICE_ACCOUNT_PATH — only the notifications cron needs this.
function messaging() {
  if (!env.firebaseServiceAccountPath) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_PATH is not set — push notifications are disabled');
  }
  if (getApps().length === 0) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const serviceAccount = require(env.firebaseServiceAccountPath);
    initializeApp({ credential: cert(serviceAccount) });
  }
  return getMessaging();
}

export async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
): Promise<{ ok: true } | { ok: false; error: string; invalidToken: boolean }> {
  try {
    await messaging().send({ token: fcmToken, notification: { title, body } });
    return { ok: true };
  } catch (err) {
    const code = (err as { code?: string }).code ?? '';
    const invalidToken =
      code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token';
    return { ok: false, error: String(err), invalidToken };
  }
}
