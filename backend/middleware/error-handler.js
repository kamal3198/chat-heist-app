const logger = require('../config/logger');

function errorHandler(err, req, res, next) {
  logger.error({
    message: err.message,
    stack: err.stack,
    path: req.originalUrl,
    method: req.method,
  });

  let statusCode = err.statusCode || 500;
  if (err.code === 'LIMIT_FILE_SIZE') statusCode = 400;
  if (err.name === 'MulterError' && !err.statusCode) statusCode = 400;
  res.status(statusCode).json({
    error: statusCode === 500 ? 'Internal server error' : err.message,
  });
}

module.exports = errorHandler;
