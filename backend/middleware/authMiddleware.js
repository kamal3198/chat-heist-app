const { auth } = require('../firebaseAdmin');

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.header('Authorization') || req.header('authorization');
    if (!authHeader) {
      console.warn('[authMiddleware] Missing Authorization header');
      return res.status(401).json({ error: 'Authentication required' });
    }

    const [scheme, ...tokenParts] = String(authHeader).trim().split(/\s+/);
    const token = tokenParts.join(' ');
    if (scheme !== 'Bearer' || !token) {
      console.warn('[authMiddleware] Invalid authorization header format');
      return res.status(401).json({ error: 'Invalid authorization header format' });
    }

    const decodedToken = await auth.verifyIdToken(token);
    console.info('[authMiddleware] verified uid:', decodedToken?.uid);
    req.user = decodedToken;
    req.userId = decodedToken.uid;
    return next();
  } catch (error) {
    console.error('[authMiddleware] verifyIdToken failed:', error?.message || error);
    if (error?.stack) {
      console.error(error.stack);
    }
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = authMiddleware;
