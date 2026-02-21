const express = require('express');
const router = express.Router();
const ContactRequest = require('../models/ContactRequest');
const BlockedUser = require('../models/BlockedUser');
const User = require('../models/User');
const auth = require('../middleware/auth');

// Get all accepted contacts
router.get('/', auth, async (req, res) => {
  try {
    const userId = req.userId;

    // Find all accepted contact requests where user is either sender or receiver
    const acceptedRequests = await ContactRequest.find({
      $or: [
        { sender: userId, status: 'accepted' },
        { receiver: userId, status: 'accepted' }
      ]
    }).populate('sender receiver', '-password');

    // Get blocked users
    const blockedUsers = await BlockedUser.find({ blocker: userId });
    const blockedIds = blockedUsers.map(b => b.blocked.toString());

    // Extract contacts (excluding blocked users)
    const contacts = acceptedRequests.map(request => {
      const contact = request.sender._id.toString() === userId.toString() 
        ? request.receiver 
        : request.sender;
      
      return contact;
    }).filter(contact => !blockedIds.includes(contact._id.toString()));

    res.json({ contacts });
  } catch (error) {
    console.error('Get contacts error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Send contact request
router.post('/request', auth, async (req, res) => {
  try {
    const { receiverId } = req.body;
    const senderId = req.userId;

    if (senderId.toString() === receiverId) {
      return res.status(400).json({ error: 'Cannot send request to yourself' });
    }

    // Check if receiver exists
    const receiver = await User.findById(receiverId);
    if (!receiver) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if already blocked
    const isBlocked = await BlockedUser.findOne({
      $or: [
        { blocker: senderId, blocked: receiverId },
        { blocker: receiverId, blocked: senderId }
      ]
    });

    if (isBlocked) {
      return res.status(400).json({ error: 'Cannot send request to this user' });
    }

    // Check if request already exists
    const existingRequest = await ContactRequest.findOne({
      $or: [
        { sender: senderId, receiver: receiverId },
        { sender: receiverId, receiver: senderId }
      ]
    });

    if (existingRequest) {
      if (existingRequest.status === 'accepted') {
        return res.status(400).json({ error: 'Already contacts' });
      }
      if (existingRequest.status === 'pending') {
        return res.status(400).json({ error: 'Request already sent' });
      }
    }

    // Create new request
    const request = new ContactRequest({
      sender: senderId,
      receiver: receiverId
    });

    await request.save();
    await request.populate('sender receiver', '-password');

    // Emit socket event to receiver
    const io = req.app.get('io');
    if (receiver.socketId) {
      io.to(receiver.socketId).emit('contactRequest', {
        request: request
      });
    }

    res.status(201).json({
      message: 'Contact request sent',
      request
    });
  } catch (error) {
    console.error('Send request error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get pending requests (received)
router.get('/requests', auth, async (req, res) => {
  try {
    const userId = req.userId;

    const requests = await ContactRequest.find({
      receiver: userId,
      status: 'pending'
    })
      .populate('sender receiver', '-password')
      .sort({ createdAt: -1 });

    res.json({ requests });
  } catch (error) {
    console.error('Get requests error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get sent requests
router.get('/requests/sent', auth, async (req, res) => {
  try {
    const userId = req.userId;

    const requests = await ContactRequest.find({
      sender: userId,
      status: 'pending'
    })
      .populate('sender receiver', '-password')
      .sort({ createdAt: -1 });

    res.json({ requests });
  } catch (error) {
    console.error('Get sent requests error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Accept contact request
router.put('/request/:id/accept', auth, async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.userId;

    const request = await ContactRequest.findById(requestId);
    
    if (!request) {
      return res.status(404).json({ error: 'Request not found' });
    }

    if (request.receiver.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    request.status = 'accepted';
    await request.save();
    await request.populate('sender receiver', '-password');

    // Emit socket event to sender
    const io = req.app.get('io');
    const sender = await User.findById(request.sender);
    if (sender.socketId) {
      io.to(sender.socketId).emit('requestAccepted', {
        request: request
      });
    }

    res.json({
      message: 'Request accepted',
      request
    });
  } catch (error) {
    console.error('Accept request error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Reject contact request
router.put('/request/:id/reject', auth, async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.userId;

    const request = await ContactRequest.findById(requestId);
    
    if (!request) {
      return res.status(404).json({ error: 'Request not found' });
    }

    if (request.receiver.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    request.status = 'rejected';
    await request.save();

    res.json({ message: 'Request rejected' });
  } catch (error) {
    console.error('Reject request error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Remove contact
router.delete('/:userId', auth, async (req, res) => {
  try {
    const contactId = req.params.userId;
    const userId = req.userId;

    await ContactRequest.deleteOne({
      $or: [
        { sender: userId, receiver: contactId },
        { sender: contactId, receiver: userId }
      ],
      status: 'accepted'
    });

    res.json({ message: 'Contact removed' });
  } catch (error) {
    console.error('Remove contact error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
