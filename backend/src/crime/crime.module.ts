import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { CrimeController } from './crime.controller.js';
import { CrimeDataService } from './crime-data.service.js';
import { CrimeService } from './crime.service.js';

@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [CrimeController],
  providers: [CrimeService, CrimeDataService, JwtAuthGuard],
})
export class CrimeModule {}
