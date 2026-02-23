const express = require('express');
const router = express.Router();

const auth = require('../middleware/auth');
const {
  listBlockedByUser,
  getUsersMap,
  getUserById,
  isEitherBlocked,
  getContactRequestByPair,
  createContactRequest,
  listRequestsByReceiver,
  listRequestsBySender,
  getContactRequestById,
  setContactRequestStatus,
  acceptContactRequest,
  acceptRequestByUserIds,
  removeAcceptedContact,
  populateByUserFields,
  getAcceptedContactIds,
} = require('../services/store');

router.get('/', auth, async (req, res) => {
  try {
    const userId = req.userId;
    const [contactIds, blockedUsers] = await Promise.all([
      getAcceptedContactIds(userId),
      listBlockedByUser(userId),
    ]);

    const blockedIds = new Set(blockedUsers.map((entry) => String(entry.blocked)));
    const visibleContactIds = contactIds.filter((id) => !blockedIds.has(String(id)));

    const usersMap = await getUsersMap(visibleContactIds, false);
    const contacts = visibleContactIds.map((id) => usersMap.get(String(id))).filter(Boolean);

    return res.json({ contacts });
  } catch (error) {
    console.error('CONTACTS_LIST ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.post('/request', auth, async (req, res) => {
  try {
    const { receiverId } = req.body;
    const senderId = req.userId;

    if (!receiverId) {
      return res.status(400).json({ error: 'receiverId is required' });
    }

    if (senderId === String(receiverId)) {
      return res.status(400).json({ error: 'Cannot send request to yourself' });
    }

    const receiver = await getUserById(receiverId, false);
    if (!receiver) {
      return res.status(404).json({ error: 'User not found' });
    }

    const blocked = await isEitherBlocked(senderId, receiverId);
    if (blocked) {
      return res.status(400).json({ error: 'Cannot send request to this user' });
    }

    const existingRequest = await getContactRequestByPair(senderId, receiverId);
    if (existingRequest) {
      if (existingRequest.status === 'accepted') {
        return res.status(400).json({ error: 'Already contacts' });
      }
      if (existingRequest.status === 'pending') {
        return res.status(400).json({ error: 'Request already sent' });
      }
    }

    const request = await createContactRequest(senderId, receiverId);
    const populated = await populateByUserFields(request, ['sender', 'receiver']);

    const io = req.app.get('io');
    if (receiver.socketId) {
      io.to(receiver.socketId).emit('contactRequest', { request: populated });
    }

    return res.status(201).json({
      message: 'Contact request sent',
      request: populated,
    });
  } catch (error) {
    console.error('CONTACTS_REQUEST_CREATE ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.get('/requests', auth, async (req, res) => {
  try {
    const requests = await listRequestsByReceiver(req.userId, 'pending');
    const populated = await populateByUserFields(requests, ['sender', 'receiver']);
    return res.json({ requests: populated });
  } catch (error) {
    console.error('CONTACTS_REQUESTS_RECEIVED ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.get('/requests/sent', auth, async (req, res) => {
  try {
    const requests = await listRequestsBySender(req.userId, 'pending');
    const populated = await populateByUserFields(requests, ['sender', 'receiver']);
    return res.json({ requests: populated });
  } catch (error) {
    console.error('CONTACTS_REQUESTS_SENT ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.put('/request/:id/accept', auth, async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.userId;

    const request = await getContactRequestById(requestId);
    if (!request) {
      return res.status(404).json({ error: 'Request not found' });
    }

    if (String(request.receiver) !== String(userId)) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    const updated = await acceptRequestByUserIds(userId, request.sender);
    const populated = await populateByUserFields(updated, ['sender', 'receiver']);

    const io = req.app.get('io');
    const sender = await getUserById(request.sender, false);
    if (sender?.socketId) {
      io.to(sender.socketId).emit('requestAccepted', { request: populated });
    }

    return res.json({
      message: 'Request accepted',
      request: populated,
    });
  } catch (error) {
    if (error?.statusCode === 404) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (error?.statusCode === 403) {
      return res.status(403).json({ error: 'Unauthorized' });
    }
    console.error('CONTACTS_REQUEST_ACCEPT ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.post('/accept-request', auth, async (req, res) => {
  try {
    const { requestId } = req.body || {};

    if (!requestId) {
      return res.status(400).json({ error: 'requestId is required' });
    }

    await acceptContactRequest(requestId, req.userId);

    return res.status(200).json({
      success: true,
      message: 'Contact request accepted successfully',
    });
  } catch (error) {
    console.error('Accept Request Error:', error);
    console.error('FULL ERROR:', error);
    if (error?.statusCode === 400) {
      return res.status(400).json({ error: error.message });
    }
    if (error?.statusCode === 404) {
      return res.status(404).json({ error: error.message });
    }
    if (error?.statusCode === 403) {
      return res.status(403).json({ error: error.message });
    }
    if (error?.statusCode === 409) {
      return res.status(409).json({ error: error.message });
    }
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

router.put('/request/:id/reject', auth, async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.userId;

    const request = await getContactRequestById(requestId);
    if (!request) {
      return res.status(404).json({ error: 'Request not found' });
    }

    if (String(request.receiver) !== String(userId)) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    await setContactRequestStatus(requestId, 'rejected');
    return res.json({ message: 'Request rejected' });
  } catch (error) {
    console.error('CONTACTS_REQUEST_REJECT ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const userId = String(req.params.id);
    const user = await getUserById(userId, true);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const contactIds = Array.isArray(user.contacts)
      ? user.contacts.map((id) => String(id)).filter(Boolean)
      : [];
    const usersMap = await getUsersMap(contactIds, false);
    const contacts = contactIds.map((id) => usersMap.get(String(id))).filter(Boolean);

    return res.status(200).json(contacts);
  } catch (error) {
    console.error('CONTACTS_BY_ID ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

router.delete('/:userId', auth, async (req, res) => {
  try {
    await removeAcceptedContact(req.userId, req.params.userId);
    return res.json({ message: 'Contact removed' });
  } catch (error) {
    console.error('CONTACTS_DELETE ERROR:', error);
    console.error('FULL ERROR:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
});

module.exports = router;
