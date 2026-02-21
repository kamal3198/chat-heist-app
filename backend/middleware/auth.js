const jwt = require('jsonwebtoken');
const User = require('../models/User');
const DeviceSession = require('../models/DeviceSession');
const env = require('../config/env');

const auth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const decoded = jwt.verify(token, env.jwtSecret);

    if (decoded.sid) {
      const activeSession = await DeviceSession.findOne({
        _id: decoded.sid,
        user: decoded.userId,
        isActive: true,
      });

      if (!activeSession) {
        return res.status(401).json({ error: 'Session expired or revoked' });
      }

      activeSession.lastActiveAt = new Date();
      await activeSession.save();
      req.sessionId = activeSession._id.toString();
    }

    const user = await User.findById(decoded.userId);

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = user;
    req.userId = user._id;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

module.exports = auth;

