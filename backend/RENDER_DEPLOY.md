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
- `FIREBASE_SERVICE_ACCOUNT_JSON=<entire service account JSON as one line>`
- `FIREBASE_STORAGE_BUCKET=<your-project.appspot.com>`

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
  - `chats.participants (array-contains) + chats.createdAt (desc)`
  - `messages.timestamp (asc)` for collection group queries
