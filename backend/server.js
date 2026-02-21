const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const env = require('./config/env');
const logger = require('./config/logger');
const { getFirebaseApp } = require('./config/firebase');
const userRoutes = require('./routes/userRoutes');
const chatRoutes = require('./routes/chatRoutes');
const notFound = require('./middleware/not-found');
const errorHandler = require('./middleware/error-handler');

const app = express();
const PORT = Number(process.env.PORT || env.port || 3000);

function isAllowedOrigin(origin) {
  if (env.corsOrigins.includes('*')) return true;
  if (!origin) return true;
  return env.corsOrigins.includes(origin);
}

app.set('trust proxy', 1);
app.use(helmet());
app.use(compression());
app.use(
  cors({
    origin(origin, callback) {
      if (isAllowedOrigin(origin)) return callback(null, true);
      return callback(new Error('Not allowed by CORS'));
    },
  })
);
app.use(
  rateLimit({
    windowMs: env.rateLimitWindowMs,
    max: env.rateLimitMax,
    standardHeaders: true,
    legacyHeaders: false,
  })
);
app.use(express.json({ limit: '1mb' }));
app.use(
  morgan('combined', {
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'chat-backend',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/users', userRoutes);
app.use('/api/chats', chatRoutes);

app.use(notFound);
app.use(errorHandler);

async function start() {
  getFirebaseApp();
  app.listen(PORT, () => {
    logger.info(`Server is running on port ${PORT}`);
  });
}

start().catch((error) => {
  logger.error('Startup failed', error);
  process.exit(1);
});
