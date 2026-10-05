import { existsSync } from 'node:fs';
import { DataSource } from 'typeorm';

// For the TypeORM CLI (migration:generate / migration:run), which runs outside
// Nest — so it reads .env itself. Runs from dist/, after `pnpm build`.
if (!process.env.DATABASE_URL && existsSync('.env')) process.loadEnvFile('.env');

export default new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [new URL('./**/*.entity.js', import.meta.url).pathname],
  migrations: [new URL('./migrations/*.js', import.meta.url).pathname],
});
