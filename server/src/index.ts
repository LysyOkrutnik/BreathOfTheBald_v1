import { app } from './app';
import { env } from './env';
import { scheduleNotificationsCron } from './notifications/cron';

app.listen(env.port, () => {
  console.log(`okrutnik-breath-server listening on port ${env.port}`);
});

scheduleNotificationsCron();
