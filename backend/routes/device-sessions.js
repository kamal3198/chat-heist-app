const express = require('express');

const auth = require('../middleware/auth');
const {
  listActiveDeviceSessions,
  getDeviceSessionById,
  deactivateDeviceSession,
} = require('../services/store');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const sessions = await listActiveDeviceSessions(req.userId);
    return res.json({ sessions, currentSessionId: req.sessionId || null });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const session = await getDeviceSessionById(req.params.id);
    if (!session || String(session.user) !== String(req.userId)) {
      return res.status(404).json({ error: 'Session not found' });
    }

    await deactivateDeviceSession(req.params.id);
    return res.json({ message: 'Session removed' });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
