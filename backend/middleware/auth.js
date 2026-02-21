const { getAuth } = require('../config/firebase');
const {
  getUserById,
  getDeviceSessionById,
  touchDeviceSession,
} = require('../services/store');

const auth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '').trim();
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const decoded = await getAuth().verifyIdToken(token);
    const userId = String(decoded.uid);

    const sessionIdHeader = req.header('x-session-id') || req.header('X-Session-Id') || null;
    if (sessionIdHeader) {
      const session = await getDeviceSessionById(sessionIdHeader);
      if (!session || !session.isActive || String(session.user) !== userId) {
        return res.status(401).json({ error: 'Session expired or revoked' });
      }
      await touchDeviceSession(sessionIdHeader);
      req.sessionId = sessionIdHeader;
    } else {
      req.sessionId = null;
    }

    const user = await getUserById(userId, false);
    if (!user) {
      return res.status(401).json({ error: 'User profile not found' });
    }

    req.userId = userId;
    req.user = user;
    req.firebaseUser = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

module.exports = auth;
