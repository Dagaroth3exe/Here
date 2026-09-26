import { Global, Module } from '@nestjs/common';
import { UserEvents } from './user-events.js';

@Global()
@Module({
  providers: [UserEvents],
  exports: [UserEvents],
})
export class EventsModule {}
