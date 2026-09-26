import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { UsersModule } from '../users/users.module.js';
import { Block } from './block.entity.js';
import { Report } from './report.entity.js';
import { SafetyController } from './safety.controller.js';
import { SafetyService } from './safety.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Block, Report]),
    UsersModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [SafetyController],
  providers: [SafetyService, JwtAuthGuard],
  exports: [SafetyService],
})
export class SafetyModule {}
