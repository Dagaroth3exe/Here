import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AreaModule } from '../area/area.module.js';
import { ChatModule } from '../chat/chat.module.js';
import { SafetyModule } from '../safety/safety.module.js';
import { UsersModule } from '../users/users.module.js';
import { RealtimeGateway } from './realtime.gateway.js';

@Module({
  imports: [
    AreaModule,
    ChatModule,
    SafetyModule,
    UsersModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  providers: [RealtimeGateway],
  // Emergency alerts ask it who's Reachable nearby.
  exports: [RealtimeGateway],
})
export class RealtimeModule {}
