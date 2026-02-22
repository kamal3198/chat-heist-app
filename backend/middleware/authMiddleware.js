const { auth } = require('../firebaseAdmin');

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.header('Authorization') || req.header('authorization');
    if (!authHeader) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const [scheme, token] = authHeader.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'Invalid authorization header format' });
    }

    const decodedToken = await auth.verifyIdToken(token);
    req.user = decodedToken;
    req.userId = decodedToken.uid;
    return next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = authMiddleware;

