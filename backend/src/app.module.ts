import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AskModule } from './ask/ask.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ChatModule } from './chat/chat.module.js';
import { EventsModule } from './events/events.module.js';
import { RealtimeModule } from './realtime/realtime.module.js';
import { PushModule } from './push/push.module.js';
import { RedisModule } from './redis/redis.module.js';
import { SafetyModule } from './safety/safety.module.js';
import { UsersModule } from './users/users.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.getOrThrow<string>('DATABASE_URL'),
        autoLoadEntities: true,
        synchronize: config.get('NODE_ENV') !== 'production',
      }),
    }),
    EventsModule,
    RedisModule,
    UsersModule,
    SafetyModule,
    AuthModule,
    ChatModule,
    RealtimeModule,
    AskModule,
    PushModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
