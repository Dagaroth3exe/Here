# Deploying HERE

## Backend (one Linux server with Docker)

1. Point two DNS records at the server, e.g. `api.example.com` and `push.example.com`.
2. Copy the repo to the server, then:

   ```sh
   cd backend/deploy
   cp .env.production.example .env   # fill in every value; secrets: openssl rand -base64 48
   docker compose -f docker-compose.prod.yml up -d --build
   ```

3. Caddy gets HTTPS certificates on first start. Check `https://api.example.com/` responds.

The backend applies pending database migrations on startup. To update, pull
the new code and rerun the `up -d --build` command.

**Back up the database** — e.g. a nightly cron job:

```sh
docker compose -f docker-compose.prod.yml exec -T postgres pg_dump -U here here | gzip > here-$(date +%F).sql.gz
```

Copy the dumps off the server.

### Schema changes

Production never syncs the schema from the entities. After changing an entity,
with the dev database up to date:

```sh
pnpm migration:generate src/migrations/<DescriptiveName>
```

Review the generated file and commit it with the entity change.

## Android app

1. Create the upload key once and keep it (and its passwords) safe — losing it
   means you can't ship updates without Play support:

   ```sh
   keytool -genkey -v -keystore ~/here-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `app/android/key.properties` (git-ignored):

   ```properties
   storeFile=/home/you/here-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

3. Build the Play bundle against the real server:

   ```sh
   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
   ```

4. Google Sign-In: register Android OAuth clients for the SHA-1 of the upload
   key (`keytool -list -v -keystore ~/here-upload.jks`) and of Play App
   Signing's key (Play Console → App integrity).

Debug builds still talk to the local backend over plain http; release builds
are HTTPS only.
