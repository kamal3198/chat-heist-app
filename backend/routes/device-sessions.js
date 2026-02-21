const express = require('express');
const auth = require('../middleware/auth');
const DeviceSession = require('../models/DeviceSession');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const sessions = await DeviceSession.find({ user: req.userId, isActive: true }).sort({ lastActiveAt: -1 });
    res.json({ sessions, currentSessionId: req.sessionId || null });
  } catch (error) {
    console.error('List device sessions error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const session = await DeviceSession.findOne({ _id: req.params.id, user: req.userId });
    if (!session) return res.status(404).json({ error: 'Session not found' });

    session.isActive = false;
    await session.save();
    res.json({ message: 'Session removed' });
  } catch (error) {
    console.error('Remove device session error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

