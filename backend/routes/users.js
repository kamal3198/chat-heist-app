const express = require('express');
const router = express.Router();

const auth = require('../middleware/auth');
const authMiddleware = require('../middleware/authMiddleware');
const upload = require('../middleware/upload');
const {
  searchUsers,
  listRequestsBySender,
  listRequestsByReceiver,
  listBlocksInvolvingUser,
  getUserById,
  updateUser,
  sanitizeUser,
} = require('../services/store');

router.get('/search', authMiddleware, async (req, res) => {
  try {
    const username = String(req.query.username || '').trim();
    const currentUserId = req.user?.uid || req.userId;
    const normalized = username.toLowerCase();

    if (!normalized || normalized.length < 2) {
      return res.json({ users: [] });
    }

    console.log('[users/search] normalized query:', normalized);

    const [users, sent, received, blocked] = await Promise.all([
      searchUsers(normalized, currentUserId, 20),
      listRequestsBySender(currentUserId),
      listRequestsByReceiver(currentUserId),
      listBlocksInvolvingUser(currentUserId),
    ]);

    const requestByOtherUser = new Map();
    [...sent, ...received].forEach((request) => {
      const otherId = request.sender === currentUserId ? request.receiver : request.sender;
      requestByOtherUser.set(otherId, request);
    });

    const blockedIds = new Set(
      blocked.map((entry) => (entry.blocker === currentUserId ? entry.blocked : entry.blocker))
    );

    const usersWithStatus = users.map((user) => {
      const userId = String(user._id);

      if (blockedIds.has(userId)) {
        return {
          _id: userId,
          id: userId,
          uid: userId,
          username: user.username || '',
          displayName: user.displayName || user.username || '',
          avatar: user.avatar || '',
          photoUrl: user.avatar || '',
          requestStatus: 'blocked',
          requestId: null,
        };
      }

      const request = requestByOtherUser.get(userId);
      let status = 'none';

      if (request) {
        if (request.status === 'accepted') {
          status = 'accepted';
        } else if (request.status === 'pending') {
          status = request.sender === currentUserId ? 'sent' : 'received';
        }
      }

      return {
        _id: userId,
        id: userId,
        uid: userId,
        username: user.username || '',
        displayName: user.displayName || user.username || '',
        avatar: user.avatar || '',
        photoUrl: user.avatar || '',
        requestStatus: status,
        requestId: request?._id || null,
      };
    });

    console.log('[users/search] result size:', usersWithStatus.length);
    console.log('[users/search] user ids:', usersWithStatus.map((u) => u.uid));

    return res.json({ users: usersWithStatus });
  } catch (error) {
    console.error('User search error:', error?.message || error);
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/me', auth, async (req, res) => {
  return res.json({ user: req.user });
});

router.put('/me', auth, upload.single('avatar'), async (req, res) => {
  try {
    const user = await getUserById(req.userId, true);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const patch = {};
    const { username, about } = req.body;

    if (typeof username === 'string') {
      patch.username = username;
    }

    if (typeof about === 'string') {
      patch.about = about.trim().substring(0, 140);
    }

    if (req.file) {
      patch.avatar = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }

    const updated = await updateUser(req.userId, patch);
    return res.json({
      message: 'Profile updated',
      user: sanitizeUser(updated),
    });
  } catch (error) {
    if (error?.statusCode && error?.code?.startsWith('USERNAME_')) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/me/ai-settings', auth, async (req, res) => {
  try {
    const user = await getUserById(req.userId, true);
    return res.json({ aiSettings: user?.aiSettings || { enabled: false, mode: 'off', customReply: '' } });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.put('/me/ai-settings', auth, async (req, res) => {
  try {
    const { enabled, mode, customReply } = req.body || {};
    const user = await getUserById(req.userId, true);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const aiSettings = {
      ...(user.aiSettings || { enabled: false, mode: 'off', customReply: '' }),
    };

    if (typeof enabled === 'boolean') aiSettings.enabled = enabled;
    if (typeof mode === 'string' && ['off', 'away', 'busy', 'custom'].includes(mode)) {
      aiSettings.mode = mode;
    }
    if (typeof customReply === 'string') {
      aiSettings.customReply = customReply.trim().substring(0, 500);
    }

    const updated = await updateUser(req.userId, { aiSettings });
    return res.json({ aiSettings: updated.aiSettings });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const user = await getUserById(req.params.id, false);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({ user });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
