const express = require('express');
const router = express.Router();

const auth = require('../middleware/auth');
const {
  listBlockedByUser,
  getUsersMap,
  getUserById,
  getBlock,
  blockUser,
  unblockUser,
  isEitherBlocked,
} = require('../services/store');

router.get('/', auth, async (req, res) => {
  try {
    const blocked = await listBlockedByUser(req.userId);
    const userIds = blocked.map((entry) => entry.blocked);
    const usersMap = await getUsersMap(userIds, false);
    const blockedUsers = userIds.map((id) => usersMap.get(String(id))).filter(Boolean);

    return res.json({ blockedUsers });
  } catch (error) {
    console.error('BLOCKED_LIST ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.post('/:userId', auth, async (req, res) => {
  try {
    const blockedId = String(req.params.userId);
    const blockerId = req.userId;

    if (blockerId === blockedId) {
      return res.status(400).json({ error: 'Cannot block yourself' });
    }

    const userToBlock = await getUserById(blockedId, false);
    if (!userToBlock) {
      return res.status(404).json({ error: 'User not found' });
    }

    const existing = await getBlock(blockerId, blockedId);
    if (existing) {
      return res.status(400).json({ error: 'User already blocked' });
    }

    await blockUser(blockerId, blockedId);

    const io = req.app.get('io');
    if (userToBlock.socketId) {
      io.to(userToBlock.socketId).emit('userBlocked', { blockerId });
    }

    return res.status(201).json({ message: 'User blocked successfully' });
  } catch (error) {
    console.error('BLOCKED_CREATE ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.delete('/:userId', auth, async (req, res) => {
  try {
    const removed = await unblockUser(req.userId, req.params.userId);
    if (!removed) {
      return res.status(404).json({ error: 'User not blocked' });
    }

    return res.json({ message: 'User unblocked successfully' });
  } catch (error) {
    console.error('BLOCKED_DELETE ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.get('/check/:userId', auth, async (req, res) => {
  try {
    const userId = String(req.params.userId);
    const currentUserId = req.userId;

    const isBlocked = await isEitherBlocked(currentUserId, userId);
    const blockedBy = isBlocked
      ? (String(isBlocked.blocker) === String(currentUserId) ? 'you' : 'them')
      : null;

    return res.json({
      isBlocked: !!isBlocked,
      blockedBy,
    });
  } catch (error) {
    console.error('BLOCKED_CHECK ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

module.exports = router;
