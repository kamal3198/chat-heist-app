const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');

const env = require('./config/env');
const logger = require('./config/logger');
const errorHandler = require('./middleware/error-handler');
const notFound = require('./middleware/not-found');

const app = express();
const server = http.createServer(app);
const PORT = Number(process.env.PORT || env.port || 3000);

function isAllowedOrigin(origin) {
  if (env.corsOrigins.includes('*')) return true;
  if (!origin) return true;
  if (env.corsOrigins.includes(origin)) return true;
  if (
    env.nodeEnv !== 'production' &&
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)
  ) {
    return true;
  }
  return false;
}

const io = new Server(server, {
  cors: {
    origin: (origin, callback) => {
      callback(null, isAllowedOrigin(origin));
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    credentials: true,
  },
});

mongoose.set('strictQuery', true);

const corsOptions = {
  origin(origin, callback) {
    if (isAllowedOrigin(origin)) {
      return callback(null, true);
    }
    return callback(null, false);
  },
  credentials: true,
};

const limiter = rateLimit({
  windowMs: env.rateLimitWindowMs,
  max: env.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
});

// Important for reverse proxies used by Render/Railway/Heroku.
app.set('trust proxy', 1);
app.use(helmet());
app.use(compression());
app.use(cors(corsOptions));
app.use(limiter);
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));
app.use(
  morgan('combined', {
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.set('io', io);

const authRoutes = require('./routes/auth');
const contactsRoutes = require('./routes/contacts');
const blockedRoutes = require('./routes/blocked');
const usersRoutes = require('./routes/users');
const messagesRoutes = require('./routes/messages');
const groupsRoutes = require('./routes/groups');
const statusRoutes = require('./routes/status');
const channelsRoutes = require('./routes/channels');
const deviceSessionsRoutes = require('./routes/device-sessions');
const callsRoutes = require('./routes/calls');

app.use('/auth', authRoutes);
app.use('/contacts', contactsRoutes);
app.use('/blocked', blockedRoutes);
app.use('/users', usersRoutes);
app.use('/messages', messagesRoutes);
app.use('/groups', groupsRoutes);
app.use('/status', statusRoutes);
app.use('/channels', channelsRoutes);
app.use('/devices', deviceSessionsRoutes);
app.use('/calls', callsRoutes);

app.get('/', (req, res) => {
  res.json({
    message: 'ChatHeist API',
    version: '1.0.0',
    status: 'running',
    environment: env.nodeEnv,
  });
});

const setupSocket = require('./socket');
setupSocket(io);

app.use(notFound);
app.use(errorHandler);

async function startServer() {
  try {
    await mongoose.connect(env.mongoUri);
    logger.info('Connected to MongoDB');

    server.listen(PORT, () => {
      logger.info(`Server running on port ${PORT}`);
    });
  } catch (error) {
    logger.error('MongoDB connection error', error);
    process.exit(1);
  }
}

async function shutdown(signal) {
  logger.info(`Received ${signal}. Starting graceful shutdown...`);
  try {
    await new Promise((resolve, reject) => {
      server.close((err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    await mongoose.connection.close();
    logger.info('Graceful shutdown complete');
    process.exit(0);
  } catch (error) {
    logger.error('Graceful shutdown failed', error);
    process.exit(1);
  }
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', error);
  process.exit(1);
});
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection', reason);
  process.exit(1);
});

startServer();

module.exports = app;
