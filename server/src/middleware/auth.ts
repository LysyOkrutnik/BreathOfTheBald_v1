import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../env';

export interface AuthedRequest extends Request {
  userId?: string;
}

/// Signs a token carrying only the user id — kept minimal so rotating
/// anything else about the account (email, name) never invalidates
/// existing sessions.
export function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, env.jwtSecret, { expiresIn: '90d' });
}

/// Rejects the request with 401 unless a valid `Authorization: Bearer <jwt>`
/// header is present; otherwise attaches `userId` for downstream handlers.
export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.header('authorization') ?? req.header('Authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'missing_token' });
    return;
  }
  try {
    const payload = jwt.verify(token, env.jwtSecret) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: 'invalid_token' });
  }
}
