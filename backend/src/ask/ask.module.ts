import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { UsersModule } from '../users/users.module.js';
import { AskAnswer } from './ask-answer.entity.js';
import { AskCommunityService } from './ask-community.service.js';
import { AskQuestion } from './ask-question.entity.js';
import { AskController } from './ask.controller.js';
import { AskService } from './ask.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([AskQuestion, AskAnswer]),
    UsersModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [AskController],
  providers: [AskService, AskCommunityService, JwtAuthGuard],
})
export class AskModule {}
