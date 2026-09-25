import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { WsAdapter } from '@nestjs/platform-ws';
import pg from 'pg';
import { AppModule } from './app.module.js';

// `created_at` columns are `timestamp without time zone`, filled by Postgres
// in UTC, but node-pg parses that type as *server-local* time — on an IST
// machine every timestamp came back 5.5h early. Read them as the UTC they
// are. (Converting the columns to `timestamptz` is the real fix; this parser
// only affects the zone-less type, so it's harmless once that's done.)
const TIMESTAMP_WITHOUT_TZ_OID = 1114;
pg.types.setTypeParser(TIMESTAMP_WITHOUT_TZ_OID, (value) => new Date(`${value.replace(' ', 'T')}Z`));

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors();
  app.useWebSocketAdapter(new WsAdapter(app));
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
