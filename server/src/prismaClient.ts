import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { env } from './env';

// Prisma 7 requires an explicit driver adapter — schema.prisma no longer
// carries a `url`, so this is the only place the connection string is used
// at runtime (prisma.config.ts is the equivalent for the CLI/migrate).
const adapter = new PrismaPg({ connectionString: env.databaseUrl });

// Single shared instance — Prisma manages its own connection pool, a new
// client per request would exhaust Postgres connections under load.
export const prisma = new PrismaClient({ adapter });
