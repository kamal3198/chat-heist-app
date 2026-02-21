const express = require('express');
const auth = require('../middleware/auth');
const CallLog = require('../models/CallLog');
const env = require('../config/env');

const router = express.Router();

router.get('/history', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const limit = Math.min(Number(req.query.limit || 100), 300);

    const logs = await CallLog.find({ participants: userId })
      .populate('caller participants endedBy', '-password')
      .sort({ startedAt: -1 })
      .limit(limit);

    res.json({ calls: logs });
  } catch (error) {
    console.error('Get call history error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/ice-servers', auth, async (req, res) => {
  try {
    const iceServers = [];

    if (env.stunUrls.length) {
      iceServers.push({ urls: env.stunUrls });
    }

    if (env.turnUrls.length && env.turnUsername && env.turnCredential) {
      iceServers.push({
        urls: env.turnUrls,
        username: env.turnUsername,
        credential: env.turnCredential,
      });
    }

    if (!iceServers.length) {
      iceServers.push({ urls: ['stun:stun.l.google.com:19302'] });
    }

    res.json({ iceServers });
  } catch (error) {
    console.error('Get ICE servers error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
