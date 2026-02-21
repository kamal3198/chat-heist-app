const express = require('express');
const router = express.Router();
const User = require('../models/User');
const ContactRequest = require('../models/ContactRequest');
const BlockedUser = require('../models/BlockedUser');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/search', auth, async (req, res) => {
  try {
    const { username } = req.query;
    const currentUserId = req.userId;

    if (!username || username.length < 2) {
      return res.json({ users: [] });
    }

    const users = await User.find({
      username: { $regex: username, $options: 'i' },
      _id: { $ne: currentUserId }
    }).select('-password').limit(20);

    const requests = await ContactRequest.find({
      $or: [
        { sender: currentUserId },
        { receiver: currentUserId }
      ]
    });

    const blockedUsers = await BlockedUser.find({
      $or: [
        { blocker: currentUserId },
        { blocked: currentUserId }
      ]
    });

    const blockedIds = blockedUsers.map(b =>
      b.blocker.toString() === currentUserId.toString()
        ? b.blocked.toString()
        : b.blocker.toString()
    );

    const usersWithStatus = users.map(user => {
      const userId = user._id.toString();

      if (blockedIds.includes(userId)) {
        return {
          ...user.toJSON(),
          requestStatus: 'blocked'
        };
      }

      const request = requests.find(r =>
        r.sender.toString() === userId || r.receiver.toString() === userId
      );

      let status = 'none';
      if (request) {
        if (request.status === 'accepted') {
          status = 'accepted';
        } else if (request.status === 'pending') {
          status = request.sender.toString() === currentUserId.toString()
            ? 'sent'
            : 'received';
        }
      }

      return {
        ...user.toJSON(),
        requestStatus: status,
        requestId: request?._id ?? null,
      };
    });

    res.json({ users: usersWithStatus });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/me', auth, async (req, res) => {
  try {
    res.json({ user: req.user.toJSON() });
  } catch (error) {
    console.error('Get current profile error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.put('/me', auth, upload.single('avatar'), async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const { username, about } = req.body;

    if (typeof username === 'string') {
      const normalizedUsername = username.trim().toLowerCase();
      if (normalizedUsername.length < 3) {
        return res.status(400).json({ error: 'Username must be at least 3 characters' });
      }

      const existing = await User.findOne({
        _id: { $ne: req.userId },
        username: normalizedUsername,
      });

      if (existing) {
        return res.status(400).json({ error: 'Username already exists' });
      }

      user.username = normalizedUsername;
    }

    if (typeof about === 'string') {
      user.about = about.trim().substring(0, 140);
    }

    if (req.file) {
      user.avatar = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }

    await user.save();
    res.json({
      message: 'Profile updated',
      user: user.toJSON(),
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/me/ai-settings', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('aiSettings');
    res.json({ aiSettings: user?.aiSettings || { enabled: false, mode: 'off', customReply: '' } });
  } catch (error) {
    console.error('Get AI settings error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.put('/me/ai-settings', auth, async (req, res) => {
  try {
    const { enabled, mode, customReply } = req.body || {};
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (typeof enabled === 'boolean') user.aiSettings.enabled = enabled;
    if (typeof mode === 'string' && ['off', 'away', 'busy', 'custom'].includes(mode)) {
      user.aiSettings.mode = mode;
    }
    if (typeof customReply === 'string') {
      user.aiSettings.customReply = customReply.trim().substring(0, 500);
    }

    await user.save();
    res.json({ aiSettings: user.aiSettings });
  } catch (error) {
    console.error('Update AI settings error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: user.toJSON() });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

