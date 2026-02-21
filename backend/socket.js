const Message = require('./models/Message');
const User = require('./models/User');
const ContactRequest = require('./models/ContactRequest');
const BlockedUser = require('./models/BlockedUser');
const CallLog = require('./models/CallLog');
const logger = require('./config/logger');

function setupSocket(io) {
  const activeUsers = new Map();
  const callTimeouts = new Map();

  function ensureUserSet(userId) {
    if (!activeUsers.has(userId)) activeUsers.set(userId, new Set());
    return activeUsers.get(userId);
  }

  function emitToUser(userId, event, payload) {
    const sockets = activeUsers.get(userId);
    if (!sockets || !sockets.size) return;
    for (const socketId of sockets) {
      io.to(socketId).emit(event, payload);
    }
  }

  function clearCallTimeout(callId) {
    const timer = callTimeouts.get(callId);
    if (timer) {
      clearTimeout(timer);
      callTimeouts.delete(callId);
    }
  }

  async function markCallConnected(callId, acceptedBy) {
    await CallLog.findOneAndUpdate(
      { callId },
      {
        $set: {
          status: 'accepted',
          connectedAt: new Date(),
        },
      }
    );
    clearCallTimeout(callId);

    const call = await CallLog.findOne({ callId }).lean();
    if (!call) return;

    for (const participantId of call.participants.map((id) => id.toString())) {
      emitToUser(participantId, 'callConnected', {
        callId,
        connectedBy: acceptedBy,
        connectedAt: new Date().toISOString(),
      });
      emitToUser(participantId, 'callAccepted', {
        callId,
        userId: acceptedBy,
        acceptedAt: new Date().toISOString(),
      });
    }
  }

  async function markCallFinal(callId, status, endedBy = null) {
    const call = await CallLog.findOne({ callId });
    if (!call) return;
    if (call.status === 'ended') return;

    const endedAt = new Date();
    const baseStart = call.connectedAt || call.startedAt;
    const durationSeconds = Math.max(0, Math.floor((endedAt.getTime() - baseStart.getTime()) / 1000));

    call.status = status;
    call.endedAt = endedAt;
    call.durationSeconds = status === 'accepted' || status === 'ended' ? durationSeconds : call.durationSeconds;
    if (endedBy) call.endedBy = endedBy;

    await call.save();
    clearCallTimeout(callId);
  }

  function autoReplyText(aiSettings) {
    if (!aiSettings?.enabled || aiSettings?.mode === 'off') return null;
    if (aiSettings.mode === 'away') return 'I am away right now. I will reply soon.';
    if (aiSettings.mode === 'busy') return 'I am currently busy. I will get back to you later.';
    if (aiSettings.mode === 'custom') {
      return aiSettings.customReply || 'Thanks for your message. I will respond shortly.';
    }
    return null;
  }

  io.on('connection', (socket) => {
    logger.info(`Socket connected: ${socket.id}`);

    socket.on('registerUser', async (userId) => {
      try {
        const userKey = userId.toString();
        ensureUserSet(userKey).add(socket.id);

        await User.findByIdAndUpdate(userId, {
          socketId: socket.id,
          isOnline: true,
          lastSeen: new Date(),
        });

        const contacts = await getAcceptedContacts(userId);
        contacts.forEach((contactId) => emitToUser(contactId.toString(), 'userOnline', { userId }));
      } catch (error) {
        console.error('Register user error:', error);
      }
    });

    socket.on('sendMessage', async (data) => {
      try {
        const { senderId, receiverId, text, fileUrl, fileName, fileType, clientMessageId } = data;

        const isContact = await ContactRequest.findOne({
          $or: [
            { sender: senderId, receiver: receiverId, status: 'accepted' },
            { sender: receiverId, receiver: senderId, status: 'accepted' },
          ],
        });

        if (!isContact) {
          socket.emit('error', { message: 'Not contacts' });
          return;
        }

        const isBlocked = await BlockedUser.findOne({
          $or: [
            { blocker: senderId, blocked: receiverId },
            { blocker: receiverId, blocked: senderId },
          ],
        });

        if (isBlocked) {
          socket.emit('error', { message: 'Cannot send message' });
          return;
        }

        const receiverSockets = activeUsers.get(receiverId.toString());

        const message = new Message({
          sender: senderId,
          receiver: receiverId,
          text: text || '',
          fileUrl,
          fileName,
          fileType,
          clientMessageId: clientMessageId || null,
          status: receiverSockets && receiverSockets.size ? 'delivered' : 'sent',
        });

        await message.save();
        await message.populate('sender receiver', '-password');

        socket.emit('messageSent', { message });
        emitToUser(receiverId.toString(), 'receiveMessage', { message });

        const receiver = await User.findById(receiverId).select('aiSettings');
        const aiReply = autoReplyText(receiver?.aiSettings);
        if (aiReply && !fileUrl) {
          const autoMessage = new Message({
            sender: receiverId,
            receiver: senderId,
            text: aiReply,
            status: activeUsers.get(senderId.toString())?.size ? 'delivered' : 'sent',
          });
          await autoMessage.save();
          await autoMessage.populate('sender receiver', '-password');

          emitToUser(senderId.toString(), 'receiveMessage', { message: autoMessage });
          emitToUser(receiverId.toString(), 'messageSent', { message: autoMessage });
        }
      } catch (error) {
        console.error('Send message error:', error);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    socket.on('typing', async (data) => {
      try {
        const { senderId, receiverId, isTyping } = data;
        emitToUser(receiverId.toString(), 'userTyping', { userId: senderId, isTyping });
      } catch (error) {
        console.error('Typing error:', error);
      }
    });

    socket.on('initiateCall', async (data) => {
      try {
        const { callId, callerId, participantIds = [], isGroup = false } = data;
        const targets = Array.isArray(participantIds)
          ? participantIds.filter((id) => id && id !== callerId)
          : [];
        const allParticipants = [callerId, ...targets];

        await CallLog.findOneAndUpdate(
          { callId },
          {
            $set: {
              callId,
              callerId: callerId.toString(),
              receiverId: !isGroup && targets.length ? targets[0].toString() : '',
              caller: callerId,
              receiver: !isGroup && targets.length ? targets[0] : null,
              participants: allParticipants,
              isGroup,
              status: 'calling',
              startedAt: new Date(),
              connectedAt: null,
              endedAt: null,
              durationSeconds: 0,
              endedBy: null,
            },
          },
          { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        for (const targetId of targets) {
          emitToUser(targetId.toString(), 'incomingCall', {
            callId,
            callerId,
            participantIds: allParticipants,
            isGroup,
            startedAt: new Date().toISOString(),
          });
        }

        socket.emit('callInitiated', {
          callId,
          participantIds: allParticipants,
          isGroup,
          startedAt: new Date().toISOString(),
          status: 'calling',
        });

        const timeout = setTimeout(async () => {
          const call = await CallLog.findOne({ callId });
          if (!call) return;
          if (call.status !== 'calling') return;

          await markCallFinal(callId, 'missed');
          for (const participantId of call.participants.map((id) => id.toString())) {
            emitToUser(participantId, 'callMissed', {
              callId,
              at: new Date().toISOString(),
            });
          }
        }, 30000);

        callTimeouts.set(callId, timeout);
      } catch (error) {
        logger.error('Initiate call error:', error);
        socket.emit('error', { message: 'Failed to initiate call' });
      }
    });

    socket.on('acceptCall', async (data) => {
      try {
        const { callId, userId } = data;
        const call = await CallLog.findOne({ callId });
        if (!call || call.status === 'ended') return;
        await markCallConnected(callId, userId);
      } catch (error) {
        logger.error('Accept call error:', error);
      }
    });

    socket.on('rejectCall', async (data) => {
      try {
        const { callId, userId, participantIds = [] } = data;
        await markCallFinal(callId, 'rejected', userId);

        const recipients = participantIds.filter((id) => id && id !== userId);
        for (const targetId of recipients) {
          emitToUser(targetId.toString(), 'callRejected', { callId, userId });
        }
      } catch (error) {
        logger.error('Reject call error:', error);
      }
    });

    socket.on('endCall', async (data) => {
      try {
        const { callId, userId, participantIds = [] } = data;
        const call = await CallLog.findOne({ callId }).select('status participants');
        if (!call || call.status === 'ended') return;
        await markCallFinal(callId, 'ended', userId);

        const fromParticipants = participantIds.filter((id) => id && id !== userId);
        const fromDb = call.participants.map((id) => id.toString()).filter((id) => id && id !== userId);
        const recipients = Array.from(new Set([...fromParticipants, ...fromDb]));
        for (const targetId of recipients) {
          emitToUser(targetId.toString(), 'callEnded', {
            callId,
            endedBy: userId,
            endedAt: new Date().toISOString(),
          });
        }
      } catch (error) {
        logger.error('End call error:', error);
      }
    });

    socket.on('callSignal', async (data) => {
      try {
        const {
          callId,
          fromUserId,
          toUserId,
          type,
          sdp = null,
          candidate = null,
        } = data || {};

        if (!callId || !fromUserId || !toUserId || !type) return;

        const call = await CallLog.findOne({
          callId,
          participants: fromUserId,
        }).select('_id participants');

        if (!call) return;

        const isRecipientInCall = call.participants.some(
          (participantId) => participantId.toString() === toUserId.toString()
        );

        if (!isRecipientInCall) return;

        emitToUser(toUserId.toString(), 'callSignal', {
          callId,
          fromUserId,
          toUserId,
          type,
          ...(sdp ? { sdp } : {}),
          ...(candidate ? { candidate } : {}),
        });
      } catch (error) {
        logger.error('Call signal relay error:', error);
      }
    });

    socket.on('markAsRead', async (data) => {
      try {
        const { userId, contactId } = data;
        await Message.updateMany(
          { sender: contactId, receiver: userId, status: { $ne: 'read' } },
          { $set: { status: 'read' } }
        );
        emitToUser(contactId.toString(), 'messagesRead', { readBy: userId });
      } catch (error) {
        console.error('Mark as read error:', error);
      }
    });

    socket.on('disconnect', async () => {
      try {
        let disconnectedUserId = null;
        for (const [userId, socketIds] of activeUsers.entries()) {
          if (socketIds.has(socket.id)) {
            socketIds.delete(socket.id);
            disconnectedUserId = userId;
            if (!socketIds.size) activeUsers.delete(userId);
            break;
          }
        }

        if (disconnectedUserId) {
          const stillOnline = activeUsers.has(disconnectedUserId);
          await User.findByIdAndUpdate(disconnectedUserId, {
            ...(stillOnline ? { isOnline: true } : { isOnline: false, lastSeen: new Date() }),
          });

          if (!stillOnline) {
            const contacts = await getAcceptedContacts(disconnectedUserId);
            contacts.forEach((contactId) => {
              emitToUser(contactId.toString(), 'userOffline', {
                userId: disconnectedUserId,
                lastSeen: new Date(),
              });
            });
          }
        }
      } catch (error) {
        console.error('Disconnect error:', error);
      }
    });
  });

  async function getAcceptedContacts(userId) {
    const requests = await ContactRequest.find({
      $or: [
        { sender: userId, status: 'accepted' },
        { receiver: userId, status: 'accepted' },
      ],
    });

    return requests.map((request) =>
      request.sender.toString() === userId.toString() ? request.receiver : request.sender
    );
  }
}

module.exports = setupSocket;
