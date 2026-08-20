import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../env';
import { prisma } from '../prismaClient';

export interface AuthedRequest extends Request {
  userId?: string;
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
      select: { tokenVersion: true },
    });
    if (!user || user.tokenVersion !== payload.tv) {
      res.status(401).json({ error: 'invalid_token' });
      return;
    }
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: 'invalid_token' });
  }
}
