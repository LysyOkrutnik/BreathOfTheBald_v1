import cron from 'node-cron';
import { prisma } from '../prismaClient';
import { env } from '../env';
import { pickNotificationForUser } from './rules';
import { sendPushNotification } from './fcm';

async function runDailyNotifications(): Promise<void> {
  if (!env.firebaseServiceAccountPath) {
    console.log('[notifications] skipped — FIREBASE_SERVICE_ACCOUNT_PATH not configured');
    return;
  }

  const users = await prisma.user.findMany({
    where: { fcmToken: { not: null } },
    select: { id: true, fcmToken: true },
  });

  let sent = 0;
  for (const user of users) {
    const candidate = await pickNotificationForUser(user.id);
    if (!candidate) continue;

    const result = await sendPushNotification(user.fcmToken!, candidate.title, candidate.body);
    if (result.ok) {
      sent += 1;
    } else if (result.invalidToken) {
      await prisma.user.update({ where: { id: user.id }, data: { fcmToken: null } });
    } else {
      console.error(`[notifications] send failed for user ${user.id}:`, result.error);
    }
  }
  console.log(`[notifications] daily run complete — sent ${sent}/${users.length}`);
}

export function scheduleNotificationsCron(): void {
  const hour = env.notificationsCronHour;
  // Runs once a day at the configured hour, server-local time.
  cron.schedule(`0 ${hour} * * *`, () => {
    runDailyNotifications().catch((err) => console.error('[notifications] run threw:', err));
  });
  console.log(`[notifications] cron scheduled for ${hour}:00 daily`);
}
