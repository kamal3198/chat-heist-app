const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const ContactRequest = require('../models/ContactRequest');
const BlockedUser = require('../models/BlockedUser');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');

// Delete selected messages for current user conversation
router.post('/bulk-delete', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const { messageIds } = req.body;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ error: 'messageIds is required' });
    }

    const result = await Message.deleteMany({
      _id: { $in: messageIds },
      $or: [
        { sender: userId },
        { receiver: userId }
      ]
    });

    res.json({
      message: 'Messages deleted',
      deletedCount: result.deletedCount,
    });
  } catch (error) {
    console.error('Bulk delete messages error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get conversation with a contact
router.get('/:contactId', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const contactId = req.params.contactId;

    // Verify they are contacts
    const isContact = await ContactRequest.findOne({
      $or: [
        { sender: userId, receiver: contactId, status: 'accepted' },
        { sender: contactId, receiver: userId, status: 'accepted' }
      ]
    });

    if (!isContact) {
      return res.status(403).json({ error: 'Not contacts' });
    }

    // Check if blocked
    const isBlocked = await BlockedUser.findOne({
      $or: [
        { blocker: userId, blocked: contactId },
        { blocker: contactId, blocked: userId }
      ]
    });

    if (isBlocked) {
      return res.status(403).json({ error: 'Cannot view messages' });
    }

    // Get messages
    const messages = await Message.find({
      $or: [
        { sender: userId, receiver: contactId },
        { sender: contactId, receiver: userId }
      ]
    })
    .populate('sender receiver', '-password')
    .sort({ timestamp: 1 });

    res.json({ messages });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Mark messages as read
router.put('/read/:contactId', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const contactId = req.params.contactId;

    // Update all unread messages from contact
    const result = await Message.updateMany(
      {
        sender: contactId,
        receiver: userId,
        status: { $ne: 'read' }
      },
      {
        $set: { status: 'read' }
      }
    );

    // Emit socket event to sender
    const io = req.app.get('io');
    const User = require('../models/User');
    const contact = await User.findById(contactId);
    
    if (contact.socketId) {
      io.to(contact.socketId).emit('messagesRead', {
        readBy: userId,
        count: result.modifiedCount
      });
    }

    res.json({ 
      message: 'Messages marked as read',
      count: result.modifiedCount
    });
  } catch (error) {
    console.error('Mark read error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Upload file
router.post('/upload', auth, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const fileUrl = `/uploads/${req.file.filename}`;
    
    res.json({
      message: 'File uploaded successfully',
      fileUrl: fileUrl,
      fileName: req.file.originalname,
      fileType: req.file.mimetype
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'File upload failed' });
  }
});

module.exports = router;
