import nodemailer from 'nodemailer';
import { env } from './env';

/// Lazily initialized, same pattern as notifications/fcm.ts — the server
/// must keep working (register/login, everything else) even before SMTP is
/// configured. When unset, emails are logged to the console instead of
/// sent, so verification/reset links are still usable during development.
let transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter | null {
  if (!env.smtpHost || !env.smtpUser || !env.smtpPassword) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.smtpHost,
      port: env.smtpPort,
      secure: env.smtpPort === 465,
      auth: { user: env.smtpUser, pass: env.smtpPassword },
    });
  }
  return transporter;
}

export async function sendMail(to: string, subject: string, text: string): Promise<void> {
  const t = getTransporter();
  if (!t) {
    console.log(`[mailer] SMTP not configured — would send to ${to}:\n[${subject}]\n${text}`);
    return;
  }
  await t.sendMail({ from: env.mailFrom, to, subject, text });
}

export function verificationEmailBody(token: string): { subject: string; text: string } {
  const link = `${env.appPublicUrl}/verify-email?token=${token}`;
  return {
    subject: 'Potwierdź adres e-mail — Breath of the Bald',
    text: `Potwierdź swój adres e-mail, otwierając ten link w aplikacji:\n${link}\n\nLink wygasa po 24 godzinach.`,
  };
}

export function passwordResetEmailBody(token: string): { subject: string; text: string } {
  const link = `${env.appPublicUrl}/reset-password?token=${token}`;
  return {
    subject: 'Reset hasła — Breath of the Bald',
    text: `Zresetuj hasło, otwierając ten link w aplikacji:\n${link}\n\nLink wygasa po 1 godzinie. Jeśli to nie Ty, zignoruj tę wiadomość.`,
  };
}
