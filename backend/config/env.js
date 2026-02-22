const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || 500),
  firebaseServiceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '',
  firebaseServiceAccountBase64: process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 || '',
  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
  firebasePrivateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
  firebaseStorageBucket: process.env.FIREBASE_STORAGE_BUCKET || '',
  firebaseWebApiKey: process.env.FIREBASE_WEB_API_KEY || '',
  serverRequestTimeoutMs: Number(process.env.SERVER_REQUEST_TIMEOUT_MS || 60_000),
  serverHeadersTimeoutMs: Number(process.env.SERVER_HEADERS_TIMEOUT_MS || 65_000),
  serverKeepAliveTimeoutMs: Number(process.env.SERVER_KEEP_ALIVE_TIMEOUT_MS || 60_000),
  logLevel: process.env.LOG_LEVEL || 'info',
};

module.exports = env;
