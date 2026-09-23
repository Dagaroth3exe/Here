import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { ChatModule } from '../chat/chat.module.js';
import { UsersModule } from '../users/users.module.js';
import { RealtimeGateway } from './realtime.gateway.js';

@Module({
  imports: [
    ChatModule,
    UsersModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  providers: [RealtimeGateway],
})
export class RealtimeModule {}
