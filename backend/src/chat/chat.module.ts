import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { UsersModule } from '../users/users.module.js';
import { ChatEvents } from './chat-events.js';
import { ChatController } from './chat.controller.js';
import { ChatService } from './chat.service.js';
import { Message } from './message.entity.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Message]),
    UsersModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [ChatController],
  providers: [ChatService, ChatEvents, JwtAuthGuard],
  exports: [ChatService, ChatEvents],
})
export class ChatModule {}
