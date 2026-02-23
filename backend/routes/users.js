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
    const currentUserId = String(req.user?.uid || req.userId || '');
    if (!currentUserId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const normalized = username.toLowerCase();
    const includeSelf = String(req.query.includeSelf || '').toLowerCase() === 'true' ||
      String(req.query.includeSelf || '') === '1';

    if (!normalized || normalized.length < 2) {
      return res.json({ users: [] });
    }

    console.log('[users/search] uid:', currentUserId, 'normalized query:', normalized);

    const users = await searchUsers(normalized, includeSelf ? null : currentUserId, 20);

    let sent = [];
    let received = [];
    let blocked = [];
    let acceptedContactIds = new Set();
    try {
      const [currentUser, sentRequests, receivedRequests, blockEntries] = await Promise.all([
        getUserById(currentUserId, true),
        listRequestsBySender(currentUserId),
        listRequestsByReceiver(currentUserId),
        listBlocksInvolvingUser(currentUserId),
      ]);
      sent = sentRequests;
      received = receivedRequests;
      blocked = blockEntries;
      acceptedContactIds = new Set(
        (Array.isArray(currentUser?.contacts) ? currentUser.contacts : [])
          .map((id) => String(id))
          .filter(Boolean)
      );
    } catch (dependencyError) {
      console.error('[users/search] dependency query failed:', dependencyError?.message || dependencyError);
      if (dependencyError?.stack) {
        console.error(dependencyError.stack);
      }
      sent = [];
      received = [];
      blocked = [];
      acceptedContactIds = new Set();
    }

    const requestByOtherUser = new Map();
    [...sent, ...received].forEach((request) => {
      const sender = String(request?.sender || '');
      const receiver = String(request?.receiver || '');
      const otherId = sender === currentUserId ? receiver : sender;
      if (!otherId) return;
      requestByOtherUser.set(otherId, request);
    });

    const blockedIds = new Set(
      blocked
        .map((entry) => {
          const blocker = String(entry?.blocker || '');
          const blockedUser = String(entry?.blocked || '');
          return blocker === currentUserId ? blockedUser : blocker;
        })
        .filter(Boolean)
    );

    const usersWithStatus = users.map((user) => {
      const userId = String(user._id);
      if (includeSelf && userId === currentUserId) {
        return {
          _id: userId,
          id: userId,
          uid: userId,
          username: user.username || '',
          displayName: user.displayName || user.username || '',
          avatar: user.avatar || '',
          photoUrl: user.avatar || '',
          requestStatus: 'self',
          requestId: null,
        };
      }

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

      if (acceptedContactIds.has(userId)) {
        status = 'accepted';
      } else if (request) {
        if (request?.status === 'accepted') {
          status = 'accepted';
        } else if (request?.status === 'pending') {
          status = String(request.sender || '') === currentUserId ? 'sent' : 'received';
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
    console.error('[users/search] fatal error:', error?.message || error);
    if (error?.stack) {
      console.error(error.stack);
    }
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
