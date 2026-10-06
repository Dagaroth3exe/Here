import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { SafetyModule } from '../safety/safety.module.js';
import { UsersModule } from '../users/users.module.js';
import { EmergencyController } from './emergency.controller.js';
import { Emergency } from './emergency.entity.js';
import { EmergencyService } from './emergency.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Emergency]),
    RealtimeModule,
    SafetyModule,
    UsersModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [EmergencyController],
  providers: [EmergencyService, JwtAuthGuard],
  exports: [EmergencyService],
})
export class EmergencyModule {}
