# KINSAEP POS

KINSAEP POS is an offline-first Flutter point-of-sale system with an optional cloud mode.

## Runtime Model

- `Offline POS`: install the APK, complete local setup, and start selling without a server.
- `Cloud POS`: connect the same APK to your VPS, log in with a store account, and enable sync per device after admin activation.

The app keeps selling offline even when a cloud subscription is blocked or expired. Cloud sync is the only feature that is disabled in that state.

## Project Structure

- `lib/`: Flutter mobile app
- `backend/`: Express + Prisma API
- `admin/`: Next.js super-admin dashboard
- `docker-compose.yml`: VPS deployment for `postgres + api + admin + nginx`

## Local Development

### Flutter app

```bash
flutter pub get
flutter run
```

### Backend API

```bash
cd backend
cp .env.example .env
npm install
npm run db:generate
npm run db:migrate
npm run db:seed
npm run dev
```

### Admin dashboard

```bash
cd admin
cp .env.example .env
npm install
npm run dev
```

## VPS Deployment

1. Copy `.env.example` to `.env` at the repository root and replace every secret.
2. Point your domain to the VPS.
3. Start the stack:

```bash
cp .env.example .env
docker compose up -d --build
```

Default routing:

- `http://your-domain/` -> admin dashboard
- `http://your-domain/api/` -> backend API

For Android production builds, create `android/key.properties` from `android/key.properties.example` and point it to your real keystore before building the release APK.
