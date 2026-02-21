const path = require('path');
const dotenv = require('dotenv');

const cwdEnvPath = path.resolve(process.cwd(), '.env');
const localEnvPath = path.resolve(__dirname, '..', '.env');
const loaded = dotenv.config({ path: cwdEnvPath });
if (loaded.error) {
  dotenv.config({ path: localEnvPath });
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  mongoUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/chatheist',
  jwtSecret: process.env.JWT_SECRET || 'change_this_in_production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  corsOrigins: (process.env.CORS_ORIGINS || 'http://localhost:3000,http://localhost:8080')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || 300),
  stunUrls: (process.env.STUN_URLS || 'stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302')
    .split(',')
    .map((url) => url.trim())
    .filter(Boolean),
  turnUrls: (process.env.TURN_URLS || '')
    .split(',')
    .map((url) => url.trim())
    .filter(Boolean),
  turnUsername: process.env.TURN_USERNAME || '',
  turnCredential: process.env.TURN_CREDENTIAL || '',
};

module.exports = env;
