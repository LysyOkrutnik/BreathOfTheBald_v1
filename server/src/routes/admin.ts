import bcrypt from 'bcryptjs';
import express, { Router } from 'express';
import { z } from 'zod';
import { htmlPage } from '../htmlPage';
import { ADMIN_COOKIE_NAME, AdminRequest, requireAdmin, requireCsrf, signToken } from '../middleware/auth';
import { sendPushNotification } from '../notifications/fcm';
import { prisma } from '../prismaClient';
import { authRateLimiter } from './auth';

const router = Router();

// Classic server-rendered forms (application/x-www-form-urlencoded), scoped
// to this router only — the rest of the API is JSON-only (see app.ts).
router.use(express.urlencoded({ extended: false }));

/// Any value that came from outside this file (emails, feedback text,
/// challenge copy an admin typed) gets escaped before it's ever
/// interpolated into a page — the same principle as the auth routes'
/// TOKEN_PATTERN check, applied here to free-text instead of tokens.
function esc(value: string): string {
  return value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

function fmt(d: Date | null | undefined): string {
  return d ? d.toISOString().replace('T', ' ').slice(0, 16) : '—';
}

function nav(active: string): string {
  const items: [string, string][] = [
    ['/admin', 'Dashboard'],
    ['/admin/users', 'Użytkownicy'],
    ['/admin/challenges', 'Wyzwania'],
    ['/admin/feedback', 'Zgłoszenia'],
    ['/admin/announcements', 'Ogłoszenia'],
  ];
  const links = items
    .map(([href, label]) => `<a href="${href}" class="${active === href ? 'active' : ''}">${label}</a>`)
    .join('');
  return `<nav>${links}<form class="inline" method="post" action="/admin/logout" style="margin-left:auto">
    <input type="hidden" name="csrf" value="__CSRF__">
    <button type="submit" class="btn secondary">Wyloguj</button>
  </form></nav>`;
}

/// Wraps body content with the nav bar and the shared dark-theme page shell,
/// substituting the real CSRF token (every admin page carries one, ready to
/// drop into any form on it — see requireCsrf's double-submit comment).
function page(title: string, active: string, token: string, bodyHtml: string): string {
  const withNav = nav(active).replace('__CSRF__', esc(token)) + bodyHtml;
  return htmlPage(title, withNav, { wide: true });
}

function csrfField(token: string): string {
  return `<input type="hidden" name="csrf" value="${esc(token)}">`;
}

// ---------------------------------------------------------------------------
// Login — the only /admin route reachable without an existing admin cookie.
// ---------------------------------------------------------------------------

router.get('/login', (req: AdminRequest, res) => {
  const error = req.query.error === '1';
  res.type('html').send(
    htmlPage(
      'Panel admina — logowanie',
      `<h1>Panel administracyjny</h1>
      <form method="post" action="/admin/login">
        <input type="email" name="email" placeholder="E-mail" required autofocus>
        <input type="password" name="password" placeholder="Hasło" required>
        <button type="submit">ZALOGUJ</button>
      </form>
      ${error ? '<p class="err">Nieprawidłowe dane logowania.</p>' : ''}`,
    ),
  );
});

router.post('/login', authRateLimiter, async (req, res) => {
  const parsed = z.object({ email: z.string().trim().toLowerCase(), password: z.string().min(1) }).safeParse(req.body);
  if (!parsed.success) {
    res.redirect('/admin/login?error=1');
    return;
  }
  const user = await prisma.user.findUnique({ where: { email: parsed.data.email } });
  // Same generic failure for "no such user", "wrong password", "not an
  // admin", and "disabled" — this page's existence is already the least
  // sensitive part of the security story here, but no reason to leak more.
  const ok =
    user && !user.disabledAt && user.isAdmin && (await bcrypt.compare(parsed.data.password, user.passwordHash));
  if (!ok) {
    res.redirect('/admin/login?error=1');
    return;
  }
  const token = signToken(user.id, user.tokenVersion);
  res.cookie(ADMIN_COOKIE_NAME, token, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 12 * 60 * 60 * 1000,
  });
  res.redirect('/admin');
});

router.use(requireAdmin);

router.post('/logout', requireCsrf, (req: AdminRequest, res) => {
  res.clearCookie(ADMIN_COOKIE_NAME);
  res.redirect('/admin/login');
});

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

async function distinctActiveUserIds(since: Date): Promise<number> {
  const [sessions, logs] = await Promise.all([
    prisma.session.findMany({ where: { timestamp: { gte: since } }, select: { userId: true }, distinct: ['userId'] }),
    prisma.freedivingLog.findMany({
      where: { timestamp: { gte: since } },
      select: { userId: true },
      distinct: ['userId'],
    }),
  ]);
  return new Set([...sessions.map((s) => s.userId), ...logs.map((l) => l.userId)]).size;
}

router.get('/', async (req: AdminRequest, res) => {
  const since7 = new Date(Date.now() - 7 * 86_400_000);
  const since30 = new Date(Date.now() - 30 * 86_400_000);
  const [totalUsers, active7, active30, totalSessions, totalFreedivingLogs, openFeedback, popularLevels] =
    await Promise.all([
      prisma.user.count(),
      distinctActiveUserIds(since7),
      distinctActiveUserIds(since30),
      prisma.session.count(),
      prisma.freedivingLog.count(),
      prisma.feedback.count({ where: { resolvedAt: null } }),
      prisma.session.groupBy({
        by: ['levelKey'],
        _count: { levelKey: true },
        orderBy: { _count: { levelKey: 'desc' } },
        take: 5,
      }),
    ]);

  const stat = (label: string, value: number | string) =>
    `<div style="flex:1;min-width:140px"><div class="muted">${label}</div><div style="font-size:28px;font-weight:700">${value}</div></div>`;

  res.type('html').send(
    page(
      'Dashboard',
      '/admin',
      req.adminToken!,
      `<h1>Dashboard</h1>
      <div style="display:flex;gap:24px;flex-wrap:wrap;margin:24px 0">
        ${stat('Użytkownicy', totalUsers)}
        ${stat('Aktywni (7 dni)', active7)}
        ${stat('Aktywni (30 dni)', active30)}
        ${stat('Sesje oddechowe', totalSessions)}
        ${stat('Sesje freedivingu', totalFreedivingLogs)}
        ${stat('Otwarte zgłoszenia', openFeedback)}
      </div>
      <h2>Najpopularniejsze poziomy</h2>
      <table><tr><th>Poziom</th><th>Liczba sesji</th></tr>
        ${popularLevels.map((l) => `<tr><td>${esc(l.levelKey)}</td><td>${l._count.levelKey}</td></tr>`).join('') || '<tr><td colspan="2" class="muted">Brak danych</td></tr>'}
      </table>`,
    ),
  );
});

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

router.get('/users', async (req: AdminRequest, res) => {
  const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  // No pagination in this first version — a `take` cap instead, which is
  // enough for the scale this app runs at today; revisit if the user list
  // ever actually reaches this limit.
  const users = await prisma.user.findMany({
    where: q ? { email: { contains: q, mode: 'insensitive' } } : undefined,
    orderBy: { createdAt: 'desc' },
    take: 200,
  });
  res.type('html').send(
    page(
      'Użytkownicy',
      '/admin/users',
      req.adminToken!,
      `<h1>Użytkownicy</h1>
      <form method="get" action="/admin/users">
        <input type="text" name="q" placeholder="Szukaj po e-mailu" value="${esc(q)}">
      </form>
      <table><tr><th>E-mail</th><th>Zarejestrowano</th><th>Zweryfikowany</th><th>Status</th><th></th></tr>
        ${users
          .map(
            (u) => `<tr>
          <td>${esc(u.email)}</td>
          <td>${fmt(u.createdAt)}</td>
          <td>${u.emailVerified ? 'Tak' : 'Nie'}</td>
          <td>${u.isAdmin ? 'Admin · ' : ''}${u.disabledAt ? 'Zablokowany' : 'Aktywny'}</td>
          <td><a href="/admin/users/${u.id}">Szczegóły</a></td>
        </tr>`,
          )
          .join('') || '<tr><td colspan="5" class="muted">Brak wyników</td></tr>'}
      </table>`,
    ),
  );
});

router.get('/users/:id', async (req: AdminRequest, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.params.id as string } });
  if (!user) {
    res.status(404).type('html').send(page('Nie znaleziono', '/admin/users', req.adminToken!, '<h1>Nie znaleziono użytkownika</h1>'));
    return;
  }
  const [sessionCount, freedivingCount] = await Promise.all([
    prisma.session.count({ where: { userId: user.id } }),
    prisma.freedivingLog.count({ where: { userId: user.id } }),
  ]);
  const isSelf = user.id === req.adminUserId;
  res.type('html').send(
    page(
      esc(user.email),
      '/admin/users',
      req.adminToken!,
      `<h1>${esc(user.email)}</h1>
      <p class="muted">Zarejestrowano: ${fmt(user.createdAt)} · E-mail zweryfikowany: ${user.emailVerified ? 'Tak' : 'Nie'}</p>
      <p class="muted">Sesje oddechowe: ${sessionCount} · Sesje freedivingu: ${freedivingCount}</p>
      <p>Status: <strong>${user.disabledAt ? 'Zablokowany od ' + fmt(user.disabledAt) : 'Aktywny'}</strong></p>
      ${
        isSelf
          ? '<p class="muted">To Twoje własne konto — blokowanie/usuwanie własnego konta jest wyłączone tutaj.</p>'
          : `<form method="post" action="/admin/users/${user.id}/toggle-disabled" class="inline">
              ${csrfField(req.adminToken!)}
              <button type="submit" class="btn secondary">${user.disabledAt ? 'Odblokuj konto' : 'Zablokuj konto'}</button>
            </form>
            <form method="post" action="/admin/users/${user.id}/delete" class="inline" onsubmit="return confirm('Usunąć to konto i wszystkie jego dane bezpowrotnie?')">
              ${csrfField(req.adminToken!)}
              <button type="submit" class="btn danger">Usuń konto</button>
            </form>`
      }`,
    ),
  );
});

router.post('/users/:id/toggle-disabled', requireCsrf, async (req: AdminRequest, res) => {
  const id = req.params.id as string;
  if (id === req.adminUserId) {
    res.redirect(`/admin/users/${id}`);
    return;
  }
  const user = await prisma.user.findUnique({ where: { id } });
  if (user) {
    await prisma.user.update({ where: { id }, data: { disabledAt: user.disabledAt ? null : new Date() } });
  }
  res.redirect(`/admin/users/${id}`);
});

router.post('/users/:id/delete', requireCsrf, async (req: AdminRequest, res) => {
  const id = req.params.id as string;
  if (id !== req.adminUserId) {
    await prisma.user.delete({ where: { id } }).catch(() => {});
  }
  res.redirect('/admin/users');
});

// ---------------------------------------------------------------------------
// Challenges — full CRUD; today these only exist as hand-seeded rows.
// ---------------------------------------------------------------------------

const challengeSchema = z.object({
  key: z.string().trim().min(1).max(64),
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().min(1).max(500),
  metric: z.enum(['STREAK', 'TOTAL_RETENTION_SEC', 'SESSION_COUNT']),
  startsAt: z.string().min(1),
  endsAt: z.string().min(1),
});

function challengeForm(token: string, action: string, values?: Partial<Record<keyof typeof challengeSchema.shape, string>>) {
  const v = values ?? {};
  const metrics = ['STREAK', 'TOTAL_RETENTION_SEC', 'SESSION_COUNT'];
  return `<form method="post" action="${action}">
    ${csrfField(token)}
    <input type="text" name="key" placeholder="Klucz (np. sierpien-streak)" value="${esc(v.key ?? '')}" required>
    <input type="text" name="title" placeholder="Tytuł" value="${esc(v.title ?? '')}" required>
    <textarea name="description" placeholder="Opis" required>${esc(v.description ?? '')}</textarea>
    <select name="metric">
      ${metrics.map((m) => `<option value="${m}" ${v.metric === m ? 'selected' : ''}>${m}</option>`).join('')}
    </select>
    <label class="muted">Start<input type="datetime-local" name="startsAt" value="${esc(v.startsAt ?? '')}" required></label>
    <label class="muted">Koniec<input type="datetime-local" name="endsAt" value="${esc(v.endsAt ?? '')}" required></label>
    <button type="submit">ZAPISZ</button>
  </form>`;
}

router.get('/challenges', async (req: AdminRequest, res) => {
  const challenges = await prisma.challenge.findMany({ orderBy: { startsAt: 'desc' } });
  res.type('html').send(
    page(
      'Wyzwania',
      '/admin/challenges',
      req.adminToken!,
      `<h1>Wyzwania</h1>
      <h2>Nowe wyzwanie</h2>
      ${challengeForm(req.adminToken!, '/admin/challenges')}
      <h2>Istniejące</h2>
      <table><tr><th>Tytuł</th><th>Metryka</th><th>Start</th><th>Koniec</th><th></th></tr>
        ${challenges
          .map(
            (c) => `<tr>
          <td>${esc(c.title)}</td><td>${c.metric}</td><td>${fmt(c.startsAt)}</td><td>${fmt(c.endsAt)}</td>
          <td>
            <a href="/admin/challenges/${c.id}/edit">Edytuj</a> ·
            <form class="inline" method="post" action="/admin/challenges/${c.id}/delete" onsubmit="return confirm('Usunąć to wyzwanie?')">
              ${csrfField(req.adminToken!)}<button type="submit" class="btn danger" style="padding:4px 10px">Usuń</button>
            </form>
          </td>
        </tr>`,
          )
          .join('') || '<tr><td colspan="5" class="muted">Brak wyzwań</td></tr>'}
      </table>`,
    ),
  );
});

router.post('/challenges', requireCsrf, async (req: AdminRequest, res) => {
  const parsed = challengeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).send('Nieprawidłowe dane formularza.');
    return;
  }
  const { startsAt, endsAt, ...rest } = parsed.data;
  await prisma.challenge.create({ data: { ...rest, startsAt: new Date(startsAt), endsAt: new Date(endsAt) } });
  res.redirect('/admin/challenges');
});

router.get('/challenges/:id/edit', async (req: AdminRequest, res) => {
  const challenge = await prisma.challenge.findUnique({ where: { id: req.params.id as string } });
  if (!challenge) {
    res.status(404).type('html').send(page('Nie znaleziono', '/admin/challenges', req.adminToken!, '<h1>Nie znaleziono wyzwania</h1>'));
    return;
  }
  res.type('html').send(
    page(
      'Edytuj wyzwanie',
      '/admin/challenges',
      req.adminToken!,
      `<h1>Edytuj wyzwanie</h1>
      ${challengeForm(req.adminToken!, `/admin/challenges/${challenge.id}`, {
        key: challenge.key,
        title: challenge.title,
        description: challenge.description,
        metric: challenge.metric,
        startsAt: challenge.startsAt.toISOString().slice(0, 16),
        endsAt: challenge.endsAt.toISOString().slice(0, 16),
      })}`,
    ),
  );
});

router.post('/challenges/:id', requireCsrf, async (req: AdminRequest, res) => {
  const parsed = challengeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).send('Nieprawidłowe dane formularza.');
    return;
  }
  const { startsAt, endsAt, ...rest } = parsed.data;
  await prisma.challenge
    .update({
      where: { id: req.params.id as string },
      data: { ...rest, startsAt: new Date(startsAt), endsAt: new Date(endsAt) },
    })
    .catch(() => {});
  res.redirect('/admin/challenges');
});

router.post('/challenges/:id/delete', requireCsrf, async (req: AdminRequest, res) => {
  await prisma.challenge.delete({ where: { id: req.params.id as string } }).catch(() => {});
  res.redirect('/admin/challenges');
});

// ---------------------------------------------------------------------------
// Feedback inbox
// ---------------------------------------------------------------------------

router.get('/feedback', async (req: AdminRequest, res) => {
  const items = await prisma.feedback.findMany({
    orderBy: [{ resolvedAt: 'asc' }, { createdAt: 'desc' }],
    include: { user: { select: { email: true } } },
    take: 200,
  });
  res.type('html').send(
    page(
      'Zgłoszenia',
      '/admin/feedback',
      req.adminToken!,
      `<h1>Zgłoszenia</h1>
      <table><tr><th>Od</th><th>Kategoria</th><th>Treść</th><th>Kiedy</th><th>Status</th><th></th></tr>
        ${items
          .map(
            (f) => `<tr>
          <td>${esc(f.user.email)}</td>
          <td>${esc(f.category ?? '—')}</td>
          <td style="max-width:360px">${esc(f.message)}</td>
          <td>${fmt(f.createdAt)}</td>
          <td>${f.resolvedAt ? 'Rozwiązane ' + fmt(f.resolvedAt) : 'Otwarte'}</td>
          <td>${
            f.resolvedAt
              ? ''
              : `<form method="post" action="/admin/feedback/${f.id}/resolve">${csrfField(req.adminToken!)}<button type="submit" class="btn secondary" style="padding:4px 10px">Rozwiąż</button></form>`
          }</td>
        </tr>`,
          )
          .join('') || '<tr><td colspan="6" class="muted">Brak zgłoszeń</td></tr>'}
      </table>`,
    ),
  );
});

router.post('/feedback/:id/resolve', requireCsrf, async (req: AdminRequest, res) => {
  await prisma.feedback.update({ where: { id: req.params.id as string }, data: { resolvedAt: new Date() } }).catch(() => {});
  res.redirect('/admin/feedback');
});

// ---------------------------------------------------------------------------
// Announcements — one-off push broadcast to every registered device, reusing
// the same FCM path as the daily notifications cron.
// ---------------------------------------------------------------------------

router.get('/announcements', async (req: AdminRequest, res) => {
  const sent = req.query.sent === '1';
  const history = await prisma.announcement.findMany({
    orderBy: { sentAt: 'desc' },
    include: { sentBy: { select: { email: true } } },
    take: 50,
  });
  res.type('html').send(
    page(
      'Ogłoszenia',
      '/admin/announcements',
      req.adminToken!,
      `<h1>Ogłoszenia</h1>
      ${sent ? '<p>Wysłano.</p>' : ''}
      <form method="post" action="/admin/announcements">
        ${csrfField(req.adminToken!)}
        <input type="text" name="title" placeholder="Tytuł" maxlength="100" required>
        <textarea name="body" placeholder="Treść" maxlength="500" required></textarea>
        <button type="submit">WYŚLIJ DO WSZYSTKICH URZĄDZEŃ</button>
      </form>
      <h2>Historia</h2>
      <table><tr><th>Tytuł</th><th>Wysłał</th><th>Kiedy</th></tr>
        ${history.map((a) => `<tr><td>${esc(a.title)}</td><td>${esc(a.sentBy.email)}</td><td>${fmt(a.sentAt)}</td></tr>`).join('') || '<tr><td colspan="3" class="muted">Brak wysłanych ogłoszeń</td></tr>'}
      </table>`,
    ),
  );
});

router.post('/announcements', requireCsrf, async (req: AdminRequest, res) => {
  const parsed = z
    .object({ title: z.string().trim().min(1).max(100), body: z.string().trim().min(1).max(500) })
    .safeParse(req.body);
  if (!parsed.success) {
    res.status(400).send('Nieprawidłowe dane formularza.');
    return;
  }
  const { title, body } = parsed.data;
  const devices = await prisma.device.findMany({ select: { id: true, fcmToken: true } });
  for (const device of devices) {
    const result = await sendPushNotification(device.fcmToken, title, body);
    if (!result.ok && result.invalidToken) {
      await prisma.device.delete({ where: { id: device.id } }).catch(() => {});
    }
  }
  await prisma.announcement.create({ data: { title, body, sentById: req.adminUserId! } });
  res.redirect('/admin/announcements?sent=1');
});

export default router;
