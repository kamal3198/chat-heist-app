const express = require('express');
const router = express.Router();

const auth = require('../middleware/auth');
const upload = require('../middleware/upload');
const {
  bulkDeleteMessagesForUser,
  getContactRequestByPair,
  isEitherBlocked,
  getConversationMessages,
  populateByUserFields,
  markConversationRead,
  getUserById,
} = require('../services/store');

router.post('/bulk-delete', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const { messageIds } = req.body;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ error: 'messageIds is required' });
    }

    const deletedCount = await bulkDeleteMessagesForUser(userId, messageIds);

    return res.json({
      message: 'Messages deleted',
      deletedCount,
    });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/:contactId', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const contactId = String(req.params.contactId);

    const relation = await getContactRequestByPair(userId, contactId);
    const isContact = relation && relation.status === 'accepted';

    if (!isContact) {
      return res.status(403).json({ error: 'Not contacts' });
    }

    const blocked = await isEitherBlocked(userId, contactId);
    if (blocked) {
      return res.status(403).json({ error: 'Cannot view messages' });
    }

    const messages = await getConversationMessages(userId, contactId);
    const populated = await populateByUserFields(messages, ['sender', 'receiver']);

    return res.json({ messages: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.put('/read/:contactId', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const contactId = String(req.params.contactId);

    const count = await markConversationRead(userId, contactId);

    const io = req.app.get('io');
    const contact = await getUserById(contactId, false);

    if (contact?.socketId) {
      io.to(contact.socketId).emit('messagesRead', {
        readBy: userId,
        count,
      });
    }

    return res.json({
      message: 'Messages marked as read',
      count,
    });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/upload', auth, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const fileUrl = `/uploads/${req.file.filename}`;

    return res.json({
      message: 'File uploaded successfully',
      fileUrl,
      fileName: req.file.originalname,
      fileType: req.file.mimetype,
    });
  } catch (error) {
    return res.status(500).json({ error: 'File upload failed' });
  }
});

module.exports = router;
