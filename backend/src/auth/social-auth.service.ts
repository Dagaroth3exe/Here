import { Injectable, InternalServerErrorException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';
import { createRemoteJWKSet, jwtVerify } from 'jose';

export interface GoogleTokenPayload {
  subject: string;
  email: string | null;
  emailVerified: boolean;
  name: string | null;
}

export interface AppleTokenPayload {
  subject: string;
  email: string | null;
}

const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

@Injectable()
export class SocialAuthService {
  constructor(private readonly configService: ConfigService) {}

  async verifyGoogleToken(idToken: string): Promise<GoogleTokenPayload> {
    const clientId = this.configService.get<string>('GOOGLE_CLIENT_ID');
    if (!clientId) {
      throw new InternalServerErrorException('Google sign-in is not configured on this server');
    }

    const client = new OAuth2Client(clientId);
    const ticket = await client.verifyIdToken({ idToken, audience: clientId });
    const payload = ticket.getPayload();
    if (!payload?.sub) {
      throw new UnauthorizedException('Invalid Google token');
    }

    return {
      subject: payload.sub,
      email: payload.email ?? null,
      emailVerified: payload.email_verified ?? false,
      name: payload.name ?? null,
    };
  }

  async verifyAppleToken(idToken: string): Promise<AppleTokenPayload> {
    const clientId = this.configService.get<string>('APPLE_CLIENT_ID');
    if (!clientId) {
      throw new InternalServerErrorException('Apple sign-in is not configured on this server');
    }

    const { payload } = await jwtVerify(idToken, APPLE_JWKS, {
      issuer: 'https://appleid.apple.com',
      audience: clientId,
    }).catch(() => {
      throw new UnauthorizedException('Invalid Apple token');
    });

    if (typeof payload.sub !== 'string') {
      throw new UnauthorizedException('Invalid Apple token');
    }

    return {
      subject: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : null,
    };
  }
}
