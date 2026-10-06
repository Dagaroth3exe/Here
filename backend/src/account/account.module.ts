import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { EmergencyModule } from '../emergency/emergency.module.js';
import { AccountController } from './account.controller.js';
import { AccountService } from './account.service.js';

// Its own module: deleting an account reaches into most others (emergencies
// already depend on users, so this can't live in UsersModule).
@Module({
  imports: [
    EmergencyModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [AccountController],
  providers: [AccountService, JwtAuthGuard],
})
export class AccountModule {}
