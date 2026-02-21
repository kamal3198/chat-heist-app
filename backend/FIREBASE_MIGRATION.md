# Firebase Migration Guide

## 1) What changed
- Database: MongoDB/Mongoose removed from runtime path.
- Database layer: Firestore service added at `backend/services/store.js`.
- Auth: Firebase Authentication added.
  - Email/password: `/auth/register`, `/auth/login`
  - Google login: `/auth/google` (expects Firebase ID token)
  - Protected routes verify Firebase ID token via `Authorization: Bearer <token>`
- Realtime/socket persistence now writes to Firestore.

## 2) Folder structure changes
- Added `backend/config/firebase.js`
- Added `backend/services/store.js`
- Added `backend/firestore.rules`
- Added `backend/firestore.indexes.json`
- Added `backend/FIREBASE_MIGRATION.md`
- Updated all backend routes and `backend/socket.js`

## 3) Firebase project setup
1. Create/select Firebase project in console.
2. Enable Firestore (Native mode).
3. Enable Authentication providers:
   - Email/Password
   - Google
4. Create service account key (Project Settings > Service accounts > Generate new private key).
5. Copy service account values into backend `.env`:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_PRIVATE_KEY`
6. Get web API key (Project Settings > General > Web API Key) and set `FIREBASE_WEB_API_KEY`.

## 4) Environment variables
Use `backend/.env`:
- `PORT`
- `NODE_ENV`
- `CORS_ORIGINS`
- `RATE_LIMIT_WINDOW_MS`
- `RATE_LIMIT_MAX`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_WEB_API_KEY`
- `STUN_URLS`, `TURN_URLS`, `TURN_USERNAME`, `TURN_CREDENTIAL`

## 5) Firestore collections used
- `users`
- `device_sessions`
- `contact_requests`
- `blocked_users`
- `messages`
- `groups`
- `channels`
- `statuses`
- `ai_settings`
- `call_logs`

## 6) Schema logic mapping
- IDs are Firestore doc IDs and returned as both `_id` and `id`.
- Contact request identity is pair-based (`userA__userB`) to prevent duplicates.
- Message query optimized with `conversationKey`.
- Block entries are directional (`blocker__blocked`) but checks evaluate both directions.
- Status expiry uses Firestore TTL (`expiresAt`).

## 7) Security rules
Apply rules from `backend/firestore.rules`.

Deploy:
```bash
firebase deploy --only firestore:rules
```

## 8) Indexes and scalability
Suggested indexes are in `backend/firestore.indexes.json`.

Deploy:
```bash
firebase deploy --only firestore:indexes
```

## 9) Deployment instructions (backend)
1. Install deps:
```bash
cd backend
npm install
```
2. Set environment variables in your host (Render/Railway/Vercel server/etc.).
3. Start service:
```bash
npm start
```
4. Ensure frontend sends Firebase ID token in `Authorization` header.

## 10) Frontend auth integration note
- For Google sign-in, do client-side Firebase sign-in, then call:
  - `POST /auth/google` with `{ "idToken": "<firebase-id-token>" }`
- For email/password, backend endpoints call Firebase Auth REST API.

## 11) Cleanup recommendation
- Remove MongoDB docs/scripts references from root README/checklists once rollout is complete.
- Regenerate `package-lock.json` after running `npm install` with the new dependency set.
