import cron from 'node-cron';
import { prisma } from '../prismaClient';
import { env } from '../env';
import { pickNotification, TrainingRecord } from './rules';
import { sendPushNotification } from './fcm';

const LOOKBACK_MS = 30 * 86_400_000;

async function runDailyNotifications(): Promise<void> {
  if (!env.firebaseServiceAccountPath && !env.firebaseServiceAccountJson) {
    console.log(
      '[notifications] skipped — neither FIREBASE_SERVICE_ACCOUNT_PATH nor FIREBASE_SERVICE_ACCOUNT_JSON is configured',
    );
    return;
  }

  const now = new Date();
  const lookback = new Date(now.getTime() - LOOKBACK_MS);

  // One user can have several registered devices (Device, not a single
  // fcmToken column on User) — the same daily pick is sent to every one of
  // them rather than just whichever device registered most recently.
  const users = await prisma.user.findMany({
    where: { devices: { some: {} } },
    select: {
      id: true,
      devices: { select: { id: true, fcmToken: true } },
      profileState: { select: { timezone: true } },
    },
  });
  if (users.length === 0) return;
  const userIds = users.map((u) => u.id);

  // Previously one pair of queries *per user* (`pickNotificationForUser`
  // did its own `prisma.session.findMany`/`freedivingLog.findMany` scoped
  // to a single userId, awaited in a loop) — classic N+1, serializing the
  // whole run's DB time with user count. Two queries total, grouped by
  // user in memory, does the same work regardless of how many users there
  // are.
  const [allSessions, allFreedivingLogs] = await Promise.all([
    prisma.session.findMany({
      where: { userId: { in: userIds }, timestamp: { gte: lookback } },
      select: { userId: true, timestamp: true, rpeScore: true },
    }),
    prisma.freedivingLog.findMany({
      where: { userId: { in: userIds }, timestamp: { gte: lookback } },
      select: { userId: true, timestamp: true, rpeScore: true },
    }),
  ]);

  const trainingsByUser = new Map<string, TrainingRecord[]>();
  for (const row of [...allSessions, ...allFreedivingLogs]) {
    const list = trainingsByUser.get(row.userId);
    if (list) {
      list.push(row);
    } else {
      trainingsByUser.set(row.userId, [row]);
    }
  }

  let sent = 0;
  let deviceCount = 0;
  // Every user's own send-to-their-devices work is independent of every
  // other user's — no shared mutable state except the plain counters
  // above, so this runs concurrently instead of one user fully finishing
  // (including every one of their devices) before the next user starts.
  await Promise.all(
    users.map(async (user) => {
      const candidate = pickNotification(
        trainingsByUser.get(user.id) ?? [],
        now,
        user.profileState?.timezone ?? null,
      );
      if (!candidate) return;

      const results = await Promise.all(
        user.devices.map((device) =>
          sendPushNotification(device.fcmToken, candidate.title, candidate.body).then((result) => ({
            device,
            result,
          })),
        ),
      );
      for (const { device, result } of results) {
        deviceCount += 1;
        if (result.ok) {
          sent += 1;
        } else if (result.invalidToken) {
          await prisma.device.delete({ where: { id: device.id } }).catch(() => {});
        } else {
          console.error(`[notifications] send failed for user ${user.id}, device ${device.id}:`, result.error);
        }
      }
    }),
  );
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
