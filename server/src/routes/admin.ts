import bcrypt from 'bcryptjs';
import express, { Router } from 'express';
import { z } from 'zod';
import { htmlPage } from '../htmlPage';
import { sendMail } from '../mailer';
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

/// Escapes a value for use inside `onsubmit="return confirm('...')"` — the
/// string has to survive two layers at once: the browser HTML-decodes the
/// attribute value before JS ever sees it, then the JS engine parses the
/// single-quoted string literal. Ordinary HTML-escaping (`esc`) would
/// entity-escape the apostrophe to `&#39;`, which decodes back to a literal
/// `'` and breaks out of the JS string — so apostrophes are backslash-escaped
/// for JS instead, while `&`/`<`/`>`/`"` still get the usual HTML treatment.
function escConfirmText(value: string): string {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function nav(active: string): string {
  const items: [string, string][] = [
    ['/admin', 'Panel główny'],
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

const ADMIN_PAGE_SIZE = 50;

function parsePage(raw: unknown): number {
  const n = parseInt(String(raw ?? '1'), 10);
  return Number.isFinite(n) && n > 0 ? n : 1;
}

/// Renders a "‹ Poprzednia / Następna ›" pager preserving every other query
/// param already on the page (search text, filters) — only `page` changes.
function pager(basePath: string, params: Record<string, string>, page: number, totalPages: number): string {
  if (totalPages <= 1) return '';
  const qs = (p: number) => {
    const merged = new URLSearchParams({ ...params, page: String(p) });
    return `${basePath}?${merged.toString()}`;
  };
  const prev = page > 1 ? `<a href="${qs(page - 1)}">‹ Poprzednia</a>` : '<span class="muted">‹ Poprzednia</span>';
  const next =
    page < totalPages ? `<a href="${qs(page + 1)}">Następna ›</a>` : '<span class="muted">Następna ›</span>';
  return `<div style="display:flex;justify-content:space-between;margin-top:12px">${prev}<span class="muted">Strona ${page} / ${totalPages}</span>${next}</div>`;
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
  const [
    totalUsers,
    active7,
    active30,
    newUsers7,
    newUsers30,
    totalSessions,
    totalFreedivingLogs,
    totalDevices,
    openFeedback,
    popularLevels,
  ] = await Promise.all([
    prisma.user.count(),
    distinctActiveUserIds(since7),
    distinctActiveUserIds(since30),
    prisma.user.count({ where: { createdAt: { gte: since7 } } }),
    prisma.user.count({ where: { createdAt: { gte: since30 } } }),
    prisma.session.count(),
    prisma.freedivingLog.count(),
    prisma.device.count(),
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
      'Panel główny',
      '/admin',
      req.adminToken!,
      `<h1>Panel główny</h1>
      <div style="display:flex;gap:24px;flex-wrap:wrap;margin:24px 0">
        ${stat('Użytkownicy', totalUsers)}
        ${stat('Aktywni (7 dni)', active7)}
        ${stat('Aktywni (30 dni)', active30)}
        ${stat('Nowe rejestracje (7 dni)', newUsers7)}
        ${stat('Nowe rejestracje (30 dni)', newUsers30)}
        ${stat('Zarejestrowane urządzenia', totalDevices)}
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
  const status = req.query.status === 'active' || req.query.status === 'disabled' ? req.query.status : 'all';
  const page_ = parsePage(req.query.page);
  const where = {
    ...(q ? { email: { contains: q, mode: 'insensitive' as const } } : {}),
    ...(status === 'active' ? { disabledAt: null } : status === 'disabled' ? { disabledAt: { not: null } } : {}),
  };
  const [users, total] = await Promise.all([
    prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page_ - 1) * ADMIN_PAGE_SIZE,
      take: ADMIN_PAGE_SIZE,
    }),
    prisma.user.count({ where }),
  ]);
  const totalPages = Math.max(1, Math.ceil(total / ADMIN_PAGE_SIZE));
  const statusOptions: [string, string][] = [
    ['all', 'Wszyscy'],
    ['active', 'Aktywni'],
    ['disabled', 'Zablokowani'],
  ];
  res.type('html').send(
    page(
      'Użytkownicy',
      '/admin/users',
      req.adminToken!,
      `<h1>Użytkownicy</h1>
      <form method="get" action="/admin/users">
        <input type="text" name="q" placeholder="Szukaj po e-mailu" value="${esc(q)}">
        <select name="status">
          ${statusOptions.map(([v, label]) => `<option value="${v}" ${status === v ? 'selected' : ''}>${label}</option>`).join('')}
        </select>
        <button type="submit">FILTRUJ</button>
      </form>
      <p class="muted">${total} użytkowników łącznie</p>
      <table><tr><th>E-mail</th><th>Zarejestrowano</th><th>E-mail zweryfikowany</th><th>Status</th><th></th></tr>
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
      </table>
      ${pager('/admin/users', { q, status }, page_, totalPages)}`,
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
          : `<form method="post" action="/admin/users/${user.id}/toggle-disabled" class="inline" onsubmit="return ${
              user.disabledAt ? 'true' : `confirm('Zablokować to konto? Użytkownik nie będzie mógł się zalogować.')`
            }">
              ${csrfField(req.adminToken!)}
              <button type="submit" class="btn secondary">${user.disabledAt ? 'Odblokuj konto' : 'Zablokuj konto'}</button>
            </form>
            <form method="post" action="/admin/users/${user.id}/delete" class="inline" onsubmit="return confirm('Usunąć to konto bezpowrotnie? Obejmie to ${sessionCount} sesji oddechowych i ${freedivingCount} sesji freedivingu.')">
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

const challengeObjectSchema = z.object({
  key: z.string().trim().min(1).max(64),
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().min(1).max(500),
  metric: z.enum(['STREAK', 'TOTAL_RETENTION_SEC', 'SESSION_COUNT']),
  startsAt: z.string().min(1),
  endsAt: z.string().min(1),
});
const challengeSchema = challengeObjectSchema.refine(
  (data) => new Date(data.startsAt) < new Date(data.endsAt),
  {
    message: 'Data początku musi być wcześniejsza niż data końca.',
    path: ['endsAt'],
  },
);

// Admins see these values directly (form select + table column) — always go
// through this map instead of printing the raw enum, which reads like a
// variable name lifted straight out of the source code.
const METRIC_LABELS: Record<string, string> = {
  STREAK: 'Passa (dni z rzędu)',
  TOTAL_RETENTION_SEC: 'Łączny czas bezdechu (s)',
  SESSION_COUNT: 'Liczba sesji',
};

function challengeForm(token: string, action: string, values?: Partial<Record<keyof typeof challengeObjectSchema.shape, string>>, isEdit = false) {
  const v = values ?? {};
  const metrics = Object.keys(METRIC_LABELS);
  return `<form method="post" action="${action}">
    ${csrfField(token)}
    <input type="text" name="key" placeholder="Klucz (np. sierpien-2026)" value="${esc(v.key ?? '')}" required>
    <input type="text" name="title" placeholder="Tytuł" value="${esc(v.title ?? '')}" required>
    <textarea name="description" placeholder="Opis" required>${esc(v.description ?? '')}</textarea>
    <select name="metric">
      ${metrics.map((m) => `<option value="${m}" ${v.metric === m ? 'selected' : ''}>${METRIC_LABELS[m]}</option>`).join('')}
    </select>
    <label class="muted">Start<input type="datetime-local" name="startsAt" value="${esc(v.startsAt ?? '')}" required></label>
    <label class="muted">Koniec<input type="datetime-local" name="endsAt" value="${esc(v.endsAt ?? '')}" required></label>
    <button type="submit">${isEdit ? 'ZAPISZ ZMIANY' : 'DODAJ WYZWANIE'}</button>
  </form>`;
}

router.get('/challenges', async (req: AdminRequest, res) => {
  const challenges = await prisma.challenge.findMany({ orderBy: { startsAt: 'desc' } });
  const deleteFailed = req.query.error === 'delete_failed';
  res.type('html').send(
    page(
      'Wyzwania',
      '/admin/challenges',
      req.adminToken!,
      `<h1>Wyzwania</h1>
      ${deleteFailed ? '<p class="err">Nie udało się usunąć wyzwania. Spróbuj ponownie.</p>' : ''}
      <h2>Nowe wyzwanie</h2>
      ${challengeForm(req.adminToken!, '/admin/challenges')}
      <h2>Istniejące</h2>
      <table><tr><th>Tytuł</th><th>Metryka</th><th>Start</th><th>Koniec</th><th></th></tr>
        ${challenges
          .map(
            (c) => `<tr>
          <td>${esc(c.title)}</td><td>${METRIC_LABELS[c.metric] ?? c.metric}</td><td>${fmt(c.startsAt)}</td><td>${fmt(c.endsAt)}</td>
          <td>
            <a href="/admin/challenges/${c.id}/edit">Edytuj</a> ·
            <form class="inline" method="post" action="/admin/challenges/${c.id}/delete" onsubmit="return confirm('Usunąć wyzwanie „${escConfirmText(c.title)}”? Uczestnicy stracą swój dotychczasowy postęp w nim.')">
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
    res.status(400).type('html').send(
      page(
        'Wyzwania',
        '/admin/challenges',
        req.adminToken!,
        `<h1>Nowe wyzwanie</h1>
        <p class="err">${esc(parsed.error.issues[0]?.message ?? 'Nieprawidłowe dane formularza.')}</p>
        ${challengeForm(req.adminToken!, '/admin/challenges', req.body)}`,
      ),
    );
    return;
  }
  const { startsAt, endsAt, ...rest } = parsed.data;
  try {
    await prisma.challenge.create({ data: { ...rest, startsAt: new Date(startsAt), endsAt: new Date(endsAt) } });
  } catch {
    res.status(400).type('html').send(
      page(
        'Wyzwania',
        '/admin/challenges',
        req.adminToken!,
        `<h1>Nowe wyzwanie</h1>
        <p class="err">Nie udało się zapisać wyzwania — sprawdź, czy klucz jest unikalny.</p>
        ${challengeForm(req.adminToken!, '/admin/challenges', parsed.data)}`,
      ),
    );
    return;
  }
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
      ${challengeForm(
        req.adminToken!,
        `/admin/challenges/${challenge.id}`,
        {
          key: challenge.key,
          title: challenge.title,
          description: challenge.description,
          metric: challenge.metric,
          startsAt: challenge.startsAt.toISOString().slice(0, 16),
          endsAt: challenge.endsAt.toISOString().slice(0, 16),
        },
        true,
      )}`,
    ),
  );
});

router.post('/challenges/:id', requireCsrf, async (req: AdminRequest, res) => {
  const parsed = challengeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).type('html').send(
      page(
        'Edytuj wyzwanie',
        '/admin/challenges',
        req.adminToken!,
        `<h1>Edytuj wyzwanie</h1>
        <p class="err">${esc(parsed.error.issues[0]?.message ?? 'Nieprawidłowe dane formularza.')}</p>
        ${challengeForm(req.adminToken!, `/admin/challenges/${req.params.id}`, req.body, true)}`,
      ),
    );
    return;
  }
  const { startsAt, endsAt, ...rest } = parsed.data;
  try {
    await prisma.challenge.update({
      where: { id: req.params.id as string },
      data: { ...rest, startsAt: new Date(startsAt), endsAt: new Date(endsAt) },
    });
  } catch {
    res.status(400).type('html').send(
      page(
        'Edytuj wyzwanie',
        '/admin/challenges',
        req.adminToken!,
        `<h1>Edytuj wyzwanie</h1>
        <p class="err">Nie udało się zapisać zmian — sprawdź, czy klucz jest unikalny.</p>
        ${challengeForm(req.adminToken!, `/admin/challenges/${req.params.id}`, parsed.data, true)}`,
      ),
    );
    return;
  }
  res.redirect('/admin/challenges');
});

router.post('/challenges/:id/delete', requireCsrf, async (req: AdminRequest, res) => {
  try {
    await prisma.challenge.delete({ where: { id: req.params.id as string } });
  } catch {
    res.redirect('/admin/challenges?error=delete_failed');
    return;
  }
  res.redirect('/admin/challenges');
});

// ---------------------------------------------------------------------------
// Feedback inbox
// ---------------------------------------------------------------------------

router.get('/feedback', async (req: AdminRequest, res) => {
  const status = req.query.status === 'open' || req.query.status === 'resolved' ? req.query.status : 'all';
  const category =
    req.query.category === 'bug' || req.query.category === 'opinion' || req.query.category === 'other'
      ? req.query.category
      : 'all';
  const page_ = parsePage(req.query.page);
  const where = {
    ...(status === 'open' ? { resolvedAt: null } : status === 'resolved' ? { resolvedAt: { not: null } } : {}),
    ...(category !== 'all' ? { category } : {}),
  };
  const [items, total] = await Promise.all([
    prisma.feedback.findMany({
      where,
      orderBy: [{ resolvedAt: 'asc' }, { createdAt: 'desc' }],
      include: { user: { select: { email: true } } },
      skip: (page_ - 1) * ADMIN_PAGE_SIZE,
      take: ADMIN_PAGE_SIZE,
    }),
    prisma.feedback.count({ where }),
  ]);
  const totalPages = Math.max(1, Math.ceil(total / ADMIN_PAGE_SIZE));
  const statusOptions: [string, string][] = [
    ['all', 'Wszystkie'],
    ['open', 'Otwarte'],
    ['resolved', 'Rozwiązane'],
  ];
  const categoryOptions: [string, string][] = [
    ['all', 'Wszystkie kategorie'],
    ['bug', 'Błąd'],
    ['opinion', 'Opinia'],
    ['other', 'Inne'],
  ];
  const categoryLabels = Object.fromEntries(categoryOptions);
  res.type('html').send(
    page(
      'Zgłoszenia',
      '/admin/feedback',
      req.adminToken!,
      `<h1>Zgłoszenia</h1>
      <form method="get" action="/admin/feedback">
        <select name="status">
          ${statusOptions.map(([v, label]) => `<option value="${v}" ${status === v ? 'selected' : ''}>${label}</option>`).join('')}
        </select>
        <select name="category">
          ${categoryOptions.map(([v, label]) => `<option value="${v}" ${category === v ? 'selected' : ''}>${label}</option>`).join('')}
        </select>
        <button type="submit">FILTRUJ</button>
      </form>
      <p class="muted">${total} zgłoszeń łącznie</p>
      <table><tr><th>Od</th><th>Kategoria</th><th>Treść</th><th>Kiedy</th><th>Status</th><th></th></tr>
        ${items
          .map(
            (f) => `<tr>
          <td>${esc(f.user.email)}</td>
          <td>${esc((f.category && categoryLabels[f.category]) ?? f.category ?? '—')}</td>
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
      </table>
      ${pager('/admin/feedback', { status, category }, page_, totalPages)}`,
    ),
  );
});

router.post('/feedback/:id/resolve', requireCsrf, async (req: AdminRequest, res) => {
  const feedback = await prisma.feedback
    .update({
      where: { id: req.params.id as string },
      data: { resolvedAt: new Date() },
      include: { user: { select: { email: true } } },
    })
    .catch(() => null);
  // Best-effort — a failed notification email must never block the admin
  // from having already marked the report resolved.
  if (feedback) {
    await sendMail(
      feedback.user.email,
      'Twoje zgłoszenie zostało rozwiązane',
      `Cześć,\n\nTwoje zgłoszenie ("${feedback.message.slice(0, 120)}") zostało oznaczone jako rozwiązane. Dziękujemy za pomoc w ulepszaniu aplikacji!\n\n— Breath of the Bald`,
    ).catch(() => {});
  }
  res.redirect('/admin/feedback');
});

// ---------------------------------------------------------------------------
// Announcements — one-off push broadcast to every registered device, reusing
// the same FCM path as the daily notifications cron.
// ---------------------------------------------------------------------------

// A broadcast to every device is easy to fat-finger (wrong audience, typo
// sent live) and easy to spam by repeated submit — this is a floor, not a
// real quota system, just enough to make an accidental double-send or a
// rapid-fire mistake impossible.
const ANNOUNCEMENT_MIN_INTERVAL_MS = 5 * 60_000;

router.get('/announcements', async (req: AdminRequest, res) => {
  const sentOk = Number(req.query.sent_ok ?? NaN);
  const sentFail = Number(req.query.sent_fail ?? NaN);
  const hasSentResult = Number.isFinite(sentOk) && Number.isFinite(sentFail);
  const rateLimited = req.query.error === 'rate_limited';
  const invalid = req.query.error === 'invalid';
  const [history, recipientCount] = await Promise.all([
    prisma.announcement.findMany({
      orderBy: { sentAt: 'desc' },
      include: { sentBy: { select: { email: true } } },
      take: 50,
    }),
    prisma.device.count(),
  ]);
  res.type('html').send(
    page(
      'Ogłoszenia',
      '/admin/announcements',
      req.adminToken!,
      `<h1>Ogłoszenia</h1>
      ${
        hasSentResult
          ? sentFail === 0
            ? `<p>Wysłano do ${sentOk} z ${sentOk + sentFail} urządzeń.</p>`
            : sentOk === 0
              ? `<p class="err">Nie udało się wysłać do żadnego z ${sentFail} urządzeń — sprawdź konfigurację Firebase (FIREBASE_SERVICE_ACCOUNT_PATH/FIREBASE_SERVICE_ACCOUNT_JSON) i logi serwera.</p>`
              : `<p class="err">Wysłano tylko do ${sentOk} z ${sentOk + sentFail} urządzeń — sprawdź logi serwera dla szczegółów błędów.</p>`
          : ''
      }
      ${rateLimited ? '<p class="err">Poczekaj chwilę — ogłoszenie zostało wysłane bardzo niedawno.</p>' : ''}
      ${invalid ? '<p class="err">Podaj tytuł i treść ogłoszenia (tytuł do 100 znaków, treść do 500).</p>' : ''}
      <p class="muted">Trafi do <strong>${recipientCount}</strong> zarejestrowanych urządzeń.</p>
      <form method="post" action="/admin/announcements" onsubmit="return confirm('Wysłać to ogłoszenie do ${recipientCount} urządzeń?')">
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
    res.redirect('/admin/announcements?error=invalid');
    return;
  }
  const lastAnnouncement = await prisma.announcement.findFirst({ orderBy: { sentAt: 'desc' } });
  if (lastAnnouncement && Date.now() - lastAnnouncement.sentAt.getTime() < ANNOUNCEMENT_MIN_INTERVAL_MS) {
    res.redirect('/admin/announcements?error=rate_limited');
    return;
  }
  const { title, body } = parsed.data;
  const devices = await prisma.device.findMany({ select: { id: true, fcmToken: true } });
  let okCount = 0;
  let failCount = 0;
  // Sent CONCURRENCY at a time rather than one-by-one (which made a
  // broadcast to N devices take N sequential FCM round-trips — a
  // multi-minute blocking admin request for a userbase in the thousands)
  // or fully unbounded (which could fan out an unbounded number of
  // concurrent FCM calls at once for a very large userbase).
  const CONCURRENCY = 50;
  for (let i = 0; i < devices.length; i += CONCURRENCY) {
    const chunk = devices.slice(i, i + CONCURRENCY);
    const results = await Promise.all(
      chunk.map((device) => sendPushNotification(device.fcmToken, title, body).then((result) => ({ device, result }))),
    );
    for (const { device, result } of results) {
      if (result.ok) {
        okCount++;
      } else {
        failCount++;
        // Was completely silent — an admin had no way to tell a broadcast
        // failed for every device (e.g. Firebase credentials missing/invalid)
        // from one that failed for a few stale tokens, since both looked
        // identical: a redirect to "?sent=1" regardless.
        console.error(`[announcements] send failed for device ${device.id}:`, result.error);
        if (result.invalidToken) {
          await prisma.device.delete({ where: { id: device.id } }).catch(() => {});
        }
      }
    }
  }
  await prisma.announcement.create({ data: { title, body, sentById: req.adminUserId! } });
  res.redirect(`/admin/announcements?sent_ok=${okCount}&sent_fail=${failCount}`);
});

export default router;
