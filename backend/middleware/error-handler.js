const logger = require('../config/logger');
const env = require('../config/env');

function errorHandler(err, req, res, next) {
  void next;
  logger.error({
    message: err.message,
    stack: err.stack,
    path: req.originalUrl,
    method: req.method,
  });

  let statusCode = err.statusCode || 500;
  if (err.code === 'LIMIT_FILE_SIZE') statusCode = 400;
  if (err.name === 'MulterError' && !err.statusCode) statusCode = 400;

  const payload = {
    error: statusCode === 500 ? 'Internal server error' : err.message,
  };

  if (env.nodeEnv !== 'production' && err.stack) {
    payload.stack = err.stack;
  }

  res.status(statusCode).json(payload);
}

module.exports = errorHandler;
