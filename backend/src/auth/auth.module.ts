import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from '../users/users.module.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { SmsService } from './sms.service.js';
import { SocialAuthService } from './social-auth.service.js';
import { TotpCredential } from './totp-credential.entity.js';
import { TotpCrypto } from './totp-crypto.js';
import { WebauthnCredential } from './webauthn-credential.entity.js';

@Module({
  imports: [
    UsersModule,
    TypeOrmModule.forFeature([WebauthnCredential, TotpCredential]),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: { expiresIn: '7d' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, TotpCrypto, SmsService, SocialAuthService],
})
export class AuthModule {}
