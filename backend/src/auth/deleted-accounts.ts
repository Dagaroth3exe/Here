import type { Redis } from 'ioredis';

// Sign-in tokens stay valid for 7 days (auth.module.ts) and aren't stored
// anywhere, so a deleted account's token can't be revoked directly. Instead
// its id is remembered here a little longer than any token can live, and the
// REST guard and the realtime gateway refuse it.
const KEEP_FOR_SECONDS = 8 * 24 * 60 * 60;

const key = (userId: string) => `account:deleted:${userId}`;

export async function markAccountDeleted(redis: Redis, userId: string): Promise<void> {
  await redis.set(key(userId), '1', 'EX', KEEP_FOR_SECONDS);
}

export async function isAccountDeleted(redis: Redis, userId: string): Promise<boolean> {
  return (await redis.exists(key(userId))) === 1;
}
