const { getFirestore, admin } = require('../config/firebase');

const db = getFirestore();
const FieldValue = admin.firestore.FieldValue;

const COLLECTIONS = {
  users: 'users',
  chats: 'chats',
};

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

async function createUser(payload) {
  const name = String(payload.name || '').trim();
  const email = String(payload.email || '').trim().toLowerCase();

  if (!name) throw badRequest('name is required');
  if (!email) throw badRequest('email is required');

  const ref = db.collection(COLLECTIONS.users).doc();
  const user = {
    name,
    email,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await ref.set(user);
  const snap = await ref.get();
  return { id: snap.id, ...snap.data() };
}

async function createChat(payload) {
  const participants = Array.isArray(payload.participants)
    ? payload.participants.map((id) => String(id).trim()).filter(Boolean)
    : [];

  if (participants.length < 2) {
    throw badRequest('participants must include at least 2 user ids');
  }

  const uniqueParticipants = Array.from(new Set(participants));
  const ref = db.collection(COLLECTIONS.chats).doc();

  await ref.set({
    participants: uniqueParticipants,
    createdAt: FieldValue.serverTimestamp(),
  });

  const snap = await ref.get();
  return { id: snap.id, ...snap.data() };
}

async function listUserChats(userId, limit = 50) {
  const normalizedUserId = String(userId || '').trim();
  if (!normalizedUserId) throw badRequest('userId is required');

  const chatsSnap = await db
    .collection(COLLECTIONS.chats)
    .where('participants', 'array-contains', normalizedUserId)
    .orderBy('createdAt', 'desc')
    .limit(Number(limit) || 50)
    .get();

  return chatsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function sendMessage(chatId, payload) {
  const senderId = String(payload.senderId || '').trim();
  const message = String(payload.message || '').trim();

  if (!senderId) throw badRequest('senderId is required');
  if (!message) throw badRequest('message is required');

  const chatRef = db.collection(COLLECTIONS.chats).doc(String(chatId));
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) {
    const error = new Error('Chat not found');
    error.statusCode = 404;
    throw error;
  }

  const participants = chatSnap.data().participants || [];
  if (!participants.includes(senderId)) {
    throw badRequest('senderId must be one of chat participants');
  }

  const messageRef = chatRef.collection('messages').doc();
  await messageRef.set({
    senderId,
    message,
    timestamp: FieldValue.serverTimestamp(),
  });

  const snap = await messageRef.get();
  return { id: snap.id, ...snap.data() };
}

async function getChatMessages(chatId, limit = 100) {
  const chatRef = db.collection(COLLECTIONS.chats).doc(String(chatId));
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) {
    const error = new Error('Chat not found');
    error.statusCode = 404;
    throw error;
  }

  const messagesSnap = await chatRef
    .collection('messages')
    .orderBy('timestamp', 'asc')
    .limit(Number(limit) || 100)
    .get();

  return messagesSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function deleteChat(chatId) {
  const chatRef = db.collection(COLLECTIONS.chats).doc(String(chatId));
  const chatSnap = await chatRef.get();

  if (!chatSnap.exists) {
    const error = new Error('Chat not found');
    error.statusCode = 404;
    throw error;
  }

  let lastDoc = null;
  const chunkSize = 450;

  while (true) {
    let query = chatRef.collection('messages').orderBy('__name__').limit(chunkSize);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  await chatRef.delete();
}

module.exports = {
  COLLECTIONS,
  createUser,
  createChat,
  listUserChats,
  sendMessage,
  getChatMessages,
  deleteChat,
};
