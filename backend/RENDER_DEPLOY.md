# Render Deployment Guide

## 1) Create Web Service
- Root directory: `backend`
- Environment: `Node`
- Build command: `npm install`
- Start command: `npm start`

## 2) Required Environment Variables
- `NODE_ENV=production`
- `PORT=10000` (Render sets this automatically, but setting is harmless)
- `CORS_ORIGINS=https://your-frontend-domain.com`
- `RATE_LIMIT_WINDOW_MS=900000`
- `RATE_LIMIT_MAX=500`
- `LOG_LEVEL=info`
- `FIREBASE_WEB_API_KEY=<firebase web api key>`
- `FIREBASE_SERVICE_ACCOUNT_JSON=<entire service account JSON as one line>`
- `FIREBASE_STORAGE_BUCKET=<your-project.appspot.com>`
- `SERVER_REQUEST_TIMEOUT_MS=60000`
- `SERVER_HEADERS_TIMEOUT_MS=65000`
- `SERVER_KEEP_ALIVE_TIMEOUT_MS=60000`

## 3) Secure Firebase Key on Render
- Open Render service settings.
- Add `FIREBASE_SERVICE_ACCOUNT_JSON` as a secret environment variable.
- Paste the full JSON from your Firebase service account file.
- Do not commit service-account JSON files to Git.
- Keep `config/serviceAccountKey.json` only for local development if needed.

## 4) Local Development
- Copy `.env.example` to `.env`.
- Put your key at `config/serviceAccountKey.json`, or set `FIREBASE_SERVICE_ACCOUNT_JSON`.
- Run `npm start`.

## 5) Firestore Indexes
- Deploy indexes from `firestore.indexes.json`:
  - `users.username_search` (single-field asc/desc)
  - `users.usernameLower` (single-field asc/desc)
  - `users.username` (single-field asc/desc)
  - `chats.participants (array-contains) + chats.createdAt (desc)`
  - `messages.timestamp (asc)` for collection group queries

## 6) Firestore Rules
- Deploy rules from `firestore.rules`:
  - Clients cannot list `/users`
  - Clients cannot write `/usernames/*` or `/reserved_usernames/*`
  - Clients cannot mutate username reservation fields directly

## 7) Preflight + Live Verification
Run from `backend/`:

```bash
npm run preflight:render
```

To check deployed endpoints, set:

```bash
RENDER_PUBLIC_URL=https://chat-heist-app.onrender.com npm run preflight:render
```

## 8) Legacy Backfill (Required)
Dry run first:

```bash
npm run backfill:usernames:dry
```

Apply writes:

```bash
npm run backfill:usernames:apply
```

If output shows `collisionCount > 0`, resolve collisions before go-live.

## 9) Concurrency / Abuse Simulation
Run 50 concurrent claims:

```bash
RACE_ATTEMPTS=50 RACE_USERNAME=race_test_user npm run test:username-race
```

Expected: exactly one successful owner claim for `usernames/{username}`.
