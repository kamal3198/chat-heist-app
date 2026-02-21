const {
  getCallLog,
  upsertCallLog,
  createMessage,
  populateByUserFields,
  getContactRequestByPair,
  isEitherBlocked,
  getUserById,
  updateUser,
  markConversationRead,
  getAcceptedContactIds,
} = require('./services/store');
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
    await upsertCallLog(callId, {
      status: 'accepted',
      connectedAt: new Date(),
    });
    clearCallTimeout(callId);

    const call = await getCallLog(callId);
    if (!call) return;

    const participants = (call.participants || []).map(String);
    for (const participantId of participants) {
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
    const call = await getCallLog(callId);
    if (!call) return;
    if (call.status === 'ended') return;

    const endedAt = new Date();
    const baseStart = call.connectedAt || call.startedAt || endedAt;
    const durationSeconds = Math.max(0, Math.floor((endedAt.getTime() - new Date(baseStart).getTime()) / 1000));

    await upsertCallLog(callId, {
      status,
      endedAt,
      durationSeconds: status === 'accepted' || status === 'ended' ? durationSeconds : call.durationSeconds || 0,
      ...(endedBy ? { endedBy } : {}),
    });

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
        const userKey = String(userId);
        ensureUserSet(userKey).add(socket.id);

        await updateUser(userKey, {
          socketId: socket.id,
          isOnline: true,
          lastSeen: new Date(),
        });

        const contacts = await getAcceptedContactIds(userKey);
        contacts.forEach((contactId) => emitToUser(String(contactId), 'userOnline', { userId: userKey }));
      } catch (error) {
        logger.error('Register user error:', error);
      }
    });

    socket.on('sendMessage', async (data) => {
      try {
        const { senderId, receiverId, text, fileUrl, fileName, fileType, clientMessageId } = data;

        const relation = await getContactRequestByPair(senderId, receiverId);
        if (!relation || relation.status !== 'accepted') {
          socket.emit('error', { message: 'Not contacts' });
          return;
        }

        const isBlocked = await isEitherBlocked(senderId, receiverId);
        if (isBlocked) {
          socket.emit('error', { message: 'Cannot send message' });
          return;
        }

        const receiverSockets = activeUsers.get(String(receiverId));

        const message = await createMessage({
          sender: senderId,
          receiver: receiverId,
          text: text || '',
          fileUrl,
          fileName,
          fileType,
          clientMessageId: clientMessageId || null,
          status: receiverSockets && receiverSockets.size ? 'delivered' : 'sent',
        });

        const populatedMessage = await populateByUserFields(message, ['sender', 'receiver']);

        socket.emit('messageSent', { message: populatedMessage });
        emitToUser(String(receiverId), 'receiveMessage', { message: populatedMessage });

        const receiver = await getUserById(receiverId, true);
        const aiReply = autoReplyText(receiver?.aiSettings);
        if (aiReply && !fileUrl) {
          const autoMessage = await createMessage({
            sender: receiverId,
            receiver: senderId,
            text: aiReply,
            status: activeUsers.get(String(senderId))?.size ? 'delivered' : 'sent',
          });
          const populatedAuto = await populateByUserFields(autoMessage, ['sender', 'receiver']);

          emitToUser(String(senderId), 'receiveMessage', { message: populatedAuto });
          emitToUser(String(receiverId), 'messageSent', { message: populatedAuto });
        }
      } catch (error) {
        logger.error('Send message error:', error);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    socket.on('typing', async (data) => {
      try {
        const { senderId, receiverId, isTyping } = data;
        emitToUser(String(receiverId), 'userTyping', { userId: senderId, isTyping });
      } catch (error) {
        logger.error('Typing error:', error);
      }
    });

    socket.on('initiateCall', async (data) => {
      try {
        const { callId, callerId, participantIds = [], isGroup = false } = data;
        const targets = Array.isArray(participantIds)
          ? participantIds.filter((id) => id && String(id) !== String(callerId)).map(String)
          : [];
        const allParticipants = Array.from(new Set([String(callerId), ...targets]));

        await upsertCallLog(callId, {
          callId: String(callId),
          callerId: String(callerId),
          receiverId: !isGroup && targets.length ? String(targets[0]) : '',
          caller: String(callerId),
          receiver: !isGroup && targets.length ? String(targets[0]) : null,
          participants: allParticipants,
          isGroup,
          status: 'calling',
          startedAt: new Date(),
          connectedAt: null,
          endedAt: null,
          durationSeconds: 0,
          endedBy: null,
        });

        for (const targetId of targets) {
          emitToUser(String(targetId), 'incomingCall', {
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
          const call = await getCallLog(callId);
          if (!call || call.status !== 'calling') return;

          await markCallFinal(callId, 'missed');
          for (const participantId of (call.participants || []).map(String)) {
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
        const call = await getCallLog(callId);
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

        const recipients = participantIds.filter((id) => id && String(id) !== String(userId));
        for (const targetId of recipients) {
          emitToUser(String(targetId), 'callRejected', { callId, userId });
        }
      } catch (error) {
        logger.error('Reject call error:', error);
      }
    });

    socket.on('endCall', async (data) => {
      try {
        const { callId, userId, participantIds = [] } = data;
        const call = await getCallLog(callId);
        if (!call || call.status === 'ended') return;

        await markCallFinal(callId, 'ended', userId);

        const fromParticipants = participantIds.filter((id) => id && String(id) !== String(userId)).map(String);
        const fromDb = (call.participants || []).map(String).filter((id) => id !== String(userId));
        const recipients = Array.from(new Set([...fromParticipants, ...fromDb]));

        for (const targetId of recipients) {
          emitToUser(String(targetId), 'callEnded', {
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

        const call = await getCallLog(callId);
        if (!call) return;

        const participants = (call.participants || []).map(String);
        if (!participants.includes(String(fromUserId)) || !participants.includes(String(toUserId))) {
          return;
        }

        emitToUser(String(toUserId), 'callSignal', {
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
        await markConversationRead(userId, contactId);
        emitToUser(String(contactId), 'messagesRead', { readBy: userId });
      } catch (error) {
        logger.error('Mark as read error:', error);
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
          await updateUser(disconnectedUserId, {
            ...(stillOnline ? { isOnline: true } : { isOnline: false, lastSeen: new Date() }),
          });

          if (!stillOnline) {
            const contacts = await getAcceptedContactIds(disconnectedUserId);
            contacts.forEach((contactId) => {
              emitToUser(String(contactId), 'userOffline', {
                userId: disconnectedUserId,
                lastSeen: new Date(),
              });
            });
          }
        }
      } catch (error) {
        logger.error('Disconnect error:', error);
      }
    });
  });
}

module.exports = setupSocket;
