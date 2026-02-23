const express = require('express');

const auth = require('../middleware/auth');
const env = require('../config/env');
const { listCallLogsForUser, populateByUserFields } = require('../services/store');

const router = express.Router();

router.get('/history', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const limit = Math.min(Number(req.query.limit || 100), 300);

    const logs = await listCallLogsForUser(userId, limit);
    const populated = await populateByUserFields(logs, ['caller', 'participants', 'endedBy']);

    return res.json({ calls: populated });
  } catch (error) {
    console.error('CALLS_HISTORY ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.get('/ice-servers', auth, async (req, res) => {
  try {
    const iceServers = [];
    const stunUrls = Array.isArray(env.stunUrls) ? env.stunUrls : [];
    const turnUrls = Array.isArray(env.turnUrls) ? env.turnUrls : [];

    if (stunUrls.length) {
      iceServers.push({ urls: stunUrls });
    }

    if (turnUrls.length && env.turnUsername && env.turnCredential) {
      iceServers.push({
        urls: turnUrls,
        username: env.turnUsername,
        credential: env.turnCredential,
      });
    }

    if (!iceServers.length) {
      iceServers.push({ urls: ['stun:stun.l.google.com:19302'] });
    }

    return res.json({ iceServers });
  } catch (error) {
    console.error('CALLS_ICE_SERVERS ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

module.exports = router;
