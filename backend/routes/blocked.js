const express = require('express');
const router = express.Router();
const BlockedUser = require('../models/BlockedUser');
const User = require('../models/User');
const auth = require('../middleware/auth');

// Get blocked users list
router.get('/', auth, async (req, res) => {
  try {
    const userId = req.userId;

    const blockedUsers = await BlockedUser.find({ blocker: userId })
      .populate('blocked', '-password')
      .sort({ createdAt: -1 });

    res.json({ blockedUsers: blockedUsers.map(b => b.blocked) });
  } catch (error) {
    console.error('Get blocked users error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Block a user
router.post('/:userId', auth, async (req, res) => {
  try {
    const blockedId = req.params.userId;
    const blockerId = req.userId;

    if (blockerId.toString() === blockedId) {
      return res.status(400).json({ error: 'Cannot block yourself' });
    }

    // Check if user exists
    const userToBlock = await User.findById(blockedId);
    if (!userToBlock) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if already blocked
    const existing = await BlockedUser.findOne({
      blocker: blockerId,
      blocked: blockedId
    });

    if (existing) {
      return res.status(400).json({ error: 'User already blocked' });
    }

    // Create block
    const blocked = new BlockedUser({
      blocker: blockerId,
      blocked: blockedId
    });

    await blocked.save();

    // Emit socket event to blocked user
    const io = req.app.get('io');
    if (userToBlock.socketId) {
      io.to(userToBlock.socketId).emit('userBlocked', {
        blockerId: blockerId
      });
    }

    res.status(201).json({ message: 'User blocked successfully' });
  } catch (error) {
    console.error('Block user error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Unblock a user
router.delete('/:userId', auth, async (req, res) => {
  try {
    const blockedId = req.params.userId;
    const blockerId = req.userId;

    const result = await BlockedUser.deleteOne({
      blocker: blockerId,
      blocked: blockedId
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'User not blocked' });
    }

    res.json({ message: 'User unblocked successfully' });
  } catch (error) {
    console.error('Unblock user error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Check if user is blocked
router.get('/check/:userId', auth, async (req, res) => {
  try {
    const userId = req.params.userId;
    const currentUserId = req.userId;

    const isBlocked = await BlockedUser.findOne({
      $or: [
        { blocker: currentUserId, blocked: userId },
        { blocker: userId, blocked: currentUserId }
      ]
    });

    res.json({ 
      isBlocked: !!isBlocked,
      blockedBy: isBlocked ? (isBlocked.blocker.toString() === currentUserId.toString() ? 'you' : 'them') : null
    });
  } catch (error) {
    console.error('Check blocked error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
