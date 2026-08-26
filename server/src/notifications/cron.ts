import cron from 'node-cron';
import { prisma } from '../prismaClient';
import { env } from '../env';
import { pickNotificationForUser } from './rules';
import { sendPushNotification } from './fcm';

async function runDailyNotifications(): Promise<void> {
  if (!env.firebaseServiceAccountPath && !env.firebaseServiceAccountJson) {
    console.log(
      '[notifications] skipped — neither FIREBASE_SERVICE_ACCOUNT_PATH nor FIREBASE_SERVICE_ACCOUNT_JSON is configured',
    );
    return;
  }

  // One user can have several registered devices (Device, not a single
  // fcmToken column on User) — the same daily pick is sent to every one of
  // them rather than just whichever device registered most recently.
  const users = await prisma.user.findMany({
    where: { devices: { some: {} } },
    select: { id: true, devices: { select: { id: true, fcmToken: true } } },
  });

  let sent = 0;
  let deviceCount = 0;
  for (const user of users) {
    const candidate = await pickNotificationForUser(user.id);
    if (!candidate) continue;

    for (const device of user.devices) {
      deviceCount += 1;
      const result = await sendPushNotification(device.fcmToken, candidate.title, candidate.body);
      if (result.ok) {
        sent += 1;
      } else if (result.invalidToken) {
        await prisma.device.delete({ where: { id: device.id } }).catch(() => {});
      } else {
        console.error(`[notifications] send failed for user ${user.id}, device ${device.id}:`, result.error);
      }
    }
  }
  console.log(`[notifications] daily run complete — sent ${sent}/${deviceCount} device(s) across ${users.length} user(s)`);
}

export function scheduleNotificationsCron(): void {
  const hour = env.notificationsCronHour;
  // Runs once a day at the configured hour, server-local time.
  cron.schedule(`0 ${hour} * * *`, () => {
    runDailyNotifications().catch((err) => console.error('[notifications] run threw:', err));
  });
  console.log(`[notifications] cron scheduled for ${hour}:00 daily`);
}
