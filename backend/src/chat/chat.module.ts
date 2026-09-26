import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { SafetyModule } from '../safety/safety.module.js';
import { UsersModule } from '../users/users.module.js';
import { ChatConnection } from './chat-connection.entity.js';
import { ChatRead } from './chat-read.entity.js';
import { ChatController } from './chat.controller.js';
import { ChatService } from './chat.service.js';
import { Message } from './message.entity.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Message, ChatConnection, ChatRead]),
    UsersModule,
    SafetyModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [ChatController],
  providers: [ChatService, JwtAuthGuard],
  exports: [ChatService],
})
export class ChatModule {}
