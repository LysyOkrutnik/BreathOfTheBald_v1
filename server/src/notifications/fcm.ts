import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { env } from '../env';

/// Lazily initialized so the server can still start (auth/sync/challenges
/// all work) even before the user has created a Firebase project and set
/// FIREBASE_SERVICE_ACCOUNT_PATH/FIREBASE_SERVICE_ACCOUNT_JSON — only push
/// notifications need this.
function messaging() {
  if (getApps().length === 0) {
    let serviceAccount: object;
    if (env.firebaseServiceAccountPath) {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      serviceAccount = require(env.firebaseServiceAccountPath);
    } else if (env.firebaseServiceAccountJson) {
      try {
        serviceAccount = JSON.parse(env.firebaseServiceAccountJson);
      } catch (err) {
        throw new Error(`FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: ${String(err)}`);
      }
    } else {
      throw new Error(
        'Neither FIREBASE_SERVICE_ACCOUNT_PATH nor FIREBASE_SERVICE_ACCOUNT_JSON is set — push notifications are disabled',
      );
    }
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
