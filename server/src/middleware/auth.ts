import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../env';
import { prisma } from '../prismaClient';

export interface AuthedRequest extends Request {
  userId?: string;
}

export const ADMIN_COOKIE_NAME = 'admin_token';

export interface AdminRequest extends Request {
  adminUserId?: string;
  adminToken?: string;
}

/// No `cookie-parser` dependency for the sake of reading one cookie —
/// `req.headers.cookie` is the raw `"a=1; b=2"` header string.
function readCookie(req: Request, name: string): string | null {
  const header = req.headers.cookie;
  if (!header) return null;
  for (const part of header.split(';')) {
    const eq = part.indexOf('=');
    if (eq === -1) continue;
    if (part.slice(0, eq).trim() === name) {
      try {
        return decodeURIComponent(part.slice(eq + 1).trim());
      } catch {
        // Malformed percent-encoding — treat exactly like "no cookie sent"
        // rather than letting a URIError escape as an unhandled rejection.
        // requireAdmin below depends on this: every failure mode must reach
        // its own generic 404, not fall through to app.ts's 500 handler,
        // which would let a malformed cookie distinguish /admin/* from an
        // unknown route by status code alone.
        return null;
      }
    }
  }
  return null;
}

/// Signs a token carrying the user id and their current [tokenVersion] —
/// bumping tokenVersion in the DB (on "log out everywhere" or a password
/// change) makes every previously-issued token fail the check in
/// [requireAuth] below, which is otherwise impossible for a stateless JWT.
export function signToken(userId: string, tokenVersion: number): string {
  return jwt.sign({ sub: userId, tv: tokenVersion }, env.jwtSecret, { expiresIn: '90d' });
}

/// Rejects the request with 401 unless a valid, non-revoked
/// `Authorization: Bearer <jwt>` header is present; otherwise attaches
/// `userId` for downstream handlers. The extra DB read (vs. a pure
/// signature check) is what makes revocation possible at all.
export async function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.header('authorization') ?? req.header('Authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'missing_token' });
    return;
  }
  try {
    const payload = jwt.verify(token, env.jwtSecret) as { sub: string; tv: number };
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { tokenVersion: true, disabledAt: true },
    });
    if (!user || user.tokenVersion !== payload.tv || user.disabledAt) {
      res.status(401).json({ error: 'invalid_token' });
      return;
    }
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: 'invalid_token' });
  }
}

/// Authenticates the separate /admin web panel via an HttpOnly cookie
/// instead of the mobile API's `Authorization: Bearer` header — a browser
/// session, not a stateless API client. Every failure mode returns the
/// same generic 404 as an unknown route (not 401): a non-admin — or a
/// logged-out browser — should not be able to tell /admin/* exists at all.
export async function requireAdmin(req: AdminRequest, res: Response, next: NextFunction) {
  const token = readCookie(req, ADMIN_COOKIE_NAME);
  if (!token) {
    res.status(404).json({ error: 'not_found' });
    return;
  }
  try {
    const payload = jwt.verify(token, env.jwtSecret) as { sub: string; tv: number };
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { tokenVersion: true, isAdmin: true, disabledAt: true },
    });
    if (!user || user.tokenVersion !== payload.tv || !user.isAdmin || user.disabledAt) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    req.adminUserId = payload.sub;
    req.adminToken = token;
    next();
  } catch {
    res.status(404).json({ error: 'not_found' });
  }
}

/// Double-submit CSRF check for state-changing /admin/* form posts: the
/// HttpOnly admin cookie's value must be echoed back by the submitted form
/// (see `csrfField` in admin.ts). A cross-site page can make the browser
/// send the cookie automatically, but has no way to read its value to put
/// in the hidden field, so a forged submission fails this comparison.
export function requireCsrf(req: AdminRequest, res: Response, next: NextFunction) {
  const submitted = typeof req.body?.csrf === 'string' ? req.body.csrf : null;
  if (!submitted || submitted !== req.adminToken) {
    res.status(403).send('CSRF check failed — go back and try again.');
    return;
  }
  next();
}
