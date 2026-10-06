import { CanActivate, ExecutionContext, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import type { Redis } from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.module.js';
import { isAccountDeleted } from './deleted-accounts.js';

export interface AuthedRequest extends Request {
  userId: string;
}

/** First REST-side auth guard in this app — the existing auth endpoints are
 * all public (they're how you *get* a token); anything that reads a specific
 * user's data needs this. Verifies the same JWT issued at login/signup, and
 * refuses tokens of accounts that have since been deleted. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const header = request.headers.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token) throw new UnauthorizedException('Missing token');

    let userId: string;
    try {
      userId = this.jwtService.verify<{ sub: string }>(token).sub;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
    if (await isAccountDeleted(this.redis, userId)) throw new UnauthorizedException('This account was deleted');
    request.userId = userId;
    return true;
  }
}
