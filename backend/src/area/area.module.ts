import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { Emergency } from '../emergency/emergency.entity.js';
import { AreaController } from './area.controller.js';
import { AreaPreference } from './area-preference.entity.js';
import { AreaService } from './area.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Emergency, AreaPreference]),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [AreaController],
  providers: [AreaService, JwtAuthGuard],
  // The realtime gateway feeds it location updates.
  exports: [AreaService],
})
export class AreaModule {}
