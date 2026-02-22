const crypto = require('crypto');
const { getFirestore, admin } = require('../config/firebase');

const db = getFirestore();
const FieldValue = admin.firestore.FieldValue;

const COLLECTIONS = {
  users: 'users',
  usersPublic: 'users_public',
  usernames: 'usernames',
  reservedUsernames: 'reserved_usernames',
  contactRequests: 'contact_requests',
  blockedUsers: 'blocked_users',
  messages: 'messages',
  groups: 'groups',
  channels: 'channels',
  statuses: 'statuses',
  aiSettings: 'ai_settings',
  callLogs: 'call_logs',
  deviceSessions: 'device_sessions',
};

const USERNAME_REGEX = /^(?!.*__)[a-z](?:[a-z0-9_]{1,18}[a-z0-9])$/;
const USERNAME_CHANGE_LIMIT = 2;
const USERNAME_CHANGE_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const RESERVED_USERNAMES = new Set([
  'admin',
  'support',
  'system',
  'null',
  'undefined',
  'api',
  'root',
]);

function now() {
  return new Date();
}

function normalizeValue(value) {
  if (!value) return value;
  if (Array.isArray(value)) return value.map(normalizeValue);
  if (value && typeof value === 'object') {
    if (typeof value.toDate === 'function') {
      return value.toDate();
    }

    const output = {};
    for (const [key, inner] of Object.entries(value)) {
      output[key] = normalizeValue(inner);
    }
    return output;
  }
  return value;
}

function withIds(id, data) {
  return {
    _id: id,
    id,
    ...normalizeValue(data || {}),
  };
}

function sanitizeUser(user) {
  if (!user) return null;
  const cloned = { ...user };
  delete cloned.password;
  return cloned;
}

function publicUserProjection(userId, userData = {}) {
  return {
    uid: String(userId),
    username: String(userData.username || ''),
    username_search: String(userData.username_search || userData.usernameLower || userData.username || ''),
    displayName: String(userData.displayName || userData.username || ''),
    photoUrl: String(userData.avatar || ''),
    isOnline: Boolean(userData.isOnline),
    updatedAt: userData.updatedAt || now(),
    createdAt: userData.createdAt || now(),
  };
}

function usernameError(message, code = 'USERNAME_INVALID', statusCode = 400) {
  const error = new Error(message);
  error.code = code;
  error.statusCode = statusCode;
  return error;
}

function normalizeUsername(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFKC');
}

function validateUsernamePolicy(username) {
  if (!USERNAME_REGEX.test(username)) {
    throw usernameError(
      'Username must be 3-20 chars, start with a letter, use only a-z, 0-9, _, and cannot contain consecutive/trailing underscores',
      'USERNAME_INVALID',
      400
    );
  }
  if (RESERVED_USERNAMES.has(username)) {
    throw usernameError('Username is reserved', 'USERNAME_RESERVED', 400);
  }
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function pruneUsernameChangeHistory(history, referenceDate) {
  const threshold = referenceDate.getTime() - USERNAME_CHANGE_WINDOW_MS;
  return (Array.isArray(history) ? history : [])
    .map((entry) => {
      const date = entry instanceof Date ? entry : new Date(entry);
      return Number.isNaN(date.getTime()) ? null : date;
    })
    .filter(Boolean)
    .filter((date) => date.getTime() >= threshold)
    .sort((a, b) => a.getTime() - b.getTime());
}

function usernamePrefixRange(prefixRaw) {
  const prefix = String(prefixRaw || '').trim().toLowerCase();
  return {
    start: prefix,
    end: `${prefix}\uf8ff`,
  };
}

function conversationKey(a, b) {
  return [String(a), String(b)].sort().join('__');
}

function pairKey(a, b) {
  return [String(a), String(b)].sort().join('__');
}

function blockDocId(blocker, blocked) {
  return `${String(blocker)}__${String(blocked)}`;
}

function deviceSessionDocId(userId, deviceId) {
  const raw = `${String(userId)}|${String(deviceId)}`;
  return crypto.createHash('sha256').update(raw).digest('hex');
}

function defaultUserPatch(input) {
  const username = normalizeUsername(input.username);
  return {
    username,
    usernameLower: username,
    username_search: username,
    email: normalizeEmail(input.email),
    avatar: input.avatar || `https://ui-avatars.com/api/?background=random&name=${encodeURIComponent(username || 'user')}`,
    about: input.about || 'Hey there! I am using ChatHeist.',
    socketId: null,
    isOnline: false,
    lastSeen: now(),
    aiSettings: {
      enabled: false,
      mode: 'off',
      customReply: 'Thanks for your message. I will get back to you soon.',
    },
    createdAt: now(),
    updatedAt: now(),
  };
}

function defaultAISettings(userId) {
  return {
    user: userId,
    enabled: false,
    autoReplyEnabled: false,
    autoReplyRules: [],
    defaultResponses: {
      away: 'I am currently away. Will get back to you soon!',
      busy: 'I am busy right now. Will reply later!',
      custom: 'Thanks for your message! I will respond shortly.',
    },
    quickReplies: [],
    createdAt: now(),
    updatedAt: now(),
  };
}

async function getUsersMap(userIds, includePrivate = false) {
  const unique = Array.from(new Set((userIds || []).filter(Boolean).map(String)));
  if (!unique.length) return new Map();

  const refs = unique.map((id) => db.collection(COLLECTIONS.users).doc(id));
  const snapshots = await db.getAll(...refs);
  const map = new Map();

  for (const docSnap of snapshots) {
    if (!docSnap.exists) continue;
    const user = withIds(docSnap.id, docSnap.data());
    map.set(docSnap.id, includePrivate ? user : sanitizeUser(user));
  }

  return map;
}

async function getUserById(userId, includePrivate = false) {
  const docSnap = await db.collection(COLLECTIONS.users).doc(String(userId)).get();
  if (!docSnap.exists) return null;
  const user = withIds(docSnap.id, docSnap.data());
  return includePrivate ? user : sanitizeUser(user);
}

async function getUserByUsername(username) {
  const normalized = normalizeUsername(username);
  if (!normalized) return null;
  const [searchSnap, lowerSnap] = await Promise.all([
    db.collection(COLLECTIONS.users).where('username_search', '==', normalized).limit(1).get(),
    db.collection(COLLECTIONS.users).where('usernameLower', '==', normalized).limit(1).get(),
  ]);

  const docSnap = searchSnap.docs[0] || lowerSnap.docs[0];
  if (!docSnap) return null;
  return withIds(docSnap.id, docSnap.data());
}

async function getUserByEmail(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) return null;
  const snap = await db.collection(COLLECTIONS.users)
    .where('email', '==', normalized)
    .limit(1)
    .get();
  if (snap.empty) return null;
  const docSnap = snap.docs[0];
  return withIds(docSnap.id, docSnap.data());
}

async function updateUserWithUsernameReservation(userId, patch) {
  const uid = String(userId);
  const nextUsername = normalizeUsername(patch.username);
  validateUsernamePolicy(nextUsername);

  const { username: _usernameIgnored, ...rawPatch } = patch;
  const patchWithoutUsername = { ...rawPatch };
  if (Object.prototype.hasOwnProperty.call(patchWithoutUsername, 'email')) {
    patchWithoutUsername.email = normalizeEmail(patchWithoutUsername.email);
  }

  const userRef = db.collection(COLLECTIONS.users).doc(uid);
  const userPublicRef = db.collection(COLLECTIONS.usersPublic).doc(uid);
  const usernameRef = db.collection(COLLECTIONS.usernames).doc(nextUsername);
  const reservedRef = db.collection(COLLECTIONS.reservedUsernames).doc(nextUsername);
  const txNow = now();

  await db.runTransaction(async (transaction) => {
    const [userSnap, usernameSnap, reservedSnap] = await Promise.all([
      transaction.get(userRef),
      transaction.get(usernameRef),
      transaction.get(reservedRef),
    ]);

    if (reservedSnap.exists) {
      throw usernameError('Username is reserved', 'USERNAME_RESERVED', 400);
    }

    const existingUserData = userSnap.exists
      ? normalizeValue(userSnap.data())
      : defaultUserPatch({
          username: nextUsername,
          email: patchWithoutUsername.email,
        });
    const currentUsername = normalizeUsername(
      existingUserData.username_search || existingUserData.usernameLower || existingUserData.username
    );
    const isRename = Boolean(currentUsername) && currentUsername !== nextUsername;

    if (usernameSnap.exists) {
      const ownerUid = String((usernameSnap.data() || {}).uid || '');
      if (ownerUid && ownerUid !== uid) {
        throw usernameError('Username already exists', 'USERNAME_TAKEN', 409);
      }
    }

    if (isRename) {
      const recentChanges = pruneUsernameChangeHistory(
        existingUserData.usernameChangeTimestamps,
        txNow
      );
      if (recentChanges.length >= USERNAME_CHANGE_LIMIT) {
        throw usernameError(
          `Username can be changed only ${USERNAME_CHANGE_LIMIT} times in 30 days`,
          'USERNAME_CHANGE_RATE_LIMITED',
          429
        );
      }
      recentChanges.push(txNow);
      patchWithoutUsername.usernameChangeTimestamps = recentChanges;
      patchWithoutUsername.lastUsernameChangeAt = txNow;
    }

    if (isRename) {
      const previousUsernameRef = db.collection(COLLECTIONS.usernames).doc(currentUsername);
      const previousUsernameSnap = await transaction.get(previousUsernameRef);
      if (previousUsernameSnap.exists) {
        const ownerUid = String((previousUsernameSnap.data() || {}).uid || '');
        if (!ownerUid || ownerUid === uid) {
          transaction.delete(previousUsernameRef);
        }
      }
    }

    const mergedUser = {
      ...existingUserData,
      ...patchWithoutUsername,
      username: nextUsername,
      usernameLower: nextUsername,
      username_search: nextUsername,
      email: normalizeEmail(
        Object.prototype.hasOwnProperty.call(patchWithoutUsername, 'email')
          ? patchWithoutUsername.email
          : existingUserData.email
      ),
      updatedAt: txNow,
      createdAt: existingUserData.createdAt || txNow,
    };

    transaction.set(
      usernameRef,
      {
        uid,
        username_search: nextUsername,
        updatedAt: txNow,
        createdAt: (usernameSnap.exists && usernameSnap.data()?.createdAt) || txNow,
      },
      { merge: true }
    );

    transaction.set(userRef, mergedUser, { merge: true });
    transaction.set(userPublicRef, publicUserProjection(uid, mergedUser), { merge: true });
  });

  return getUserById(uid, true);
}

async function createOrMergeUser(uid, patch) {
  if (Object.prototype.hasOwnProperty.call(patch, 'username')) {
    return updateUserWithUsernameReservation(uid, patch);
  }

  const userRef = db.collection(COLLECTIONS.users).doc(String(uid));
  const existing = await userRef.get();
  const base = existing.exists ? normalizeValue(existing.data()) : defaultUserPatch(patch);

  const merged = {
    ...base,
    ...patch,
    username: normalizeUsername(patch.username ?? base.username),
    usernameLower: normalizeUsername(patch.username ?? base.username),
    username_search: normalizeUsername(patch.username ?? base.username ?? base.username_search),
    email: normalizeEmail(patch.email ?? base.email),
    updatedAt: now(),
    createdAt: base.createdAt || now(),
  };

  await userRef.set(merged, { merge: true });
  const userPublicRef = db.collection(COLLECTIONS.usersPublic).doc(String(uid));
  await userPublicRef.set(publicUserProjection(uid, merged), { merge: true });
  const finalDoc = await userRef.get();
  return withIds(finalDoc.id, finalDoc.data());
}

async function updateUser(userId, patch) {
  if (Object.prototype.hasOwnProperty.call(patch, 'username')) {
    return updateUserWithUsernameReservation(userId, patch);
  }

  const ref = db.collection(COLLECTIONS.users).doc(String(userId));
  const updatePatch = {
    ...patch,
    ...(Object.prototype.hasOwnProperty.call(patch, 'email')
      ? { email: normalizeEmail(patch.email) }
      : {}),
    updatedAt: now(),
  };
  await ref.set(updatePatch, { merge: true });
  const updated = await getUserById(userId, true);
  if (updated) {
    const userPublicRef = db.collection(COLLECTIONS.usersPublic).doc(String(userId));
    await userPublicRef.set(publicUserProjection(userId, updated), { merge: true });
  }
  return updated;
}

async function searchUsers(prefix, excludeUserId, limit = 20) {
  const normalizedPrefix = normalizeUsername(prefix);
  const { start, end } = usernamePrefixRange(normalizedPrefix);
  if (!start || start.length < 2) return [];

  // Primary query uses normalized field. Fallback query supports older records
  // that may not yet have usernameLower populated.
  const [searchSnap, lowerSnap, legacySnap] = await Promise.all([
    db.collection(COLLECTIONS.users)
      .orderBy('username_search')
      .startAt(start)
      .endAt(end)
      .limit(limit)
      .get(),
    db.collection(COLLECTIONS.users)
      .orderBy('usernameLower')
      .startAt(start)
      .endAt(end)
      .limit(limit)
      .get(),
    db.collection(COLLECTIONS.users)
      .orderBy('username')
      .startAt(start)
      .endAt(end)
      .limit(limit)
      .get(),
  ]);

  const seen = new Set();
  const merged = [];
  for (const docSnap of [...searchSnap.docs, ...lowerSnap.docs, ...legacySnap.docs]) {
    if (seen.has(docSnap.id)) continue;
    seen.add(docSnap.id);
    merged.push(withIds(docSnap.id, docSnap.data()));
  }

  return merged
    .filter((user) => user._id !== String(excludeUserId))
    .filter((user) => String(user.username || '').toLowerCase().startsWith(normalizedPrefix))
    .filter((user) => Boolean(user.username_search || user.usernameLower || user.username))
    .slice(0, limit)
    .map(sanitizeUser);
}

async function upsertDeviceSession(userId, input) {
  const deviceId = input.deviceId || `web-${Date.now()}`;
  const sid = deviceSessionDocId(userId, deviceId);
  const ref = db.collection(COLLECTIONS.deviceSessions).doc(sid);
  const payload = {
    user: String(userId),
    deviceId,
    deviceName: input.deviceName || 'Unknown device',
    platform: input.platform || 'unknown',
    appVersion: input.appVersion || '1.0.0',
    isActive: true,
    lastActiveAt: now(),
    createdAt: now(),
    updatedAt: now(),
  };

  await ref.set(payload, { merge: true });
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function listActiveDeviceSessions(userId) {
  const snap = await db.collection(COLLECTIONS.deviceSessions)
    .where('user', '==', String(userId))
    .where('isActive', '==', true)
    .orderBy('lastActiveAt', 'desc')
    .get();

  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function getDeviceSessionById(sessionId) {
  const snap = await db.collection(COLLECTIONS.deviceSessions).doc(String(sessionId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function deactivateDeviceSession(sessionId) {
  const ref = db.collection(COLLECTIONS.deviceSessions).doc(String(sessionId));
  await ref.set({ isActive: false, updatedAt: now() }, { merge: true });
}

async function touchDeviceSession(sessionId) {
  const ref = db.collection(COLLECTIONS.deviceSessions).doc(String(sessionId));
  await ref.set({ lastActiveAt: now(), updatedAt: now() }, { merge: true });
}

async function getContactRequestById(requestId) {
  const snap = await db.collection(COLLECTIONS.contactRequests).doc(String(requestId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function getContactRequestByPair(userA, userB) {
  const id = pairKey(userA, userB);
  return getContactRequestById(id);
}

async function createContactRequest(senderId, receiverId) {
  const id = pairKey(senderId, receiverId);
  const ref = db.collection(COLLECTIONS.contactRequests).doc(id);
  const payload = {
    sender: String(senderId),
    receiver: String(receiverId),
    status: 'pending',
    createdAt: now(),
    updatedAt: now(),
  };
  await ref.set(payload, { merge: false });
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function setContactRequestStatus(requestId, status) {
  const ref = db.collection(COLLECTIONS.contactRequests).doc(String(requestId));
  await ref.set({ status, updatedAt: now() }, { merge: true });
  return getContactRequestById(requestId);
}

async function listRequestsBySender(senderId, status = null) {
  let query = db.collection(COLLECTIONS.contactRequests).where('sender', '==', String(senderId));
  if (status) query = query.where('status', '==', status);
  const snap = await query.orderBy('createdAt', 'desc').get();
  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function listRequestsByReceiver(receiverId, status = null) {
  let query = db.collection(COLLECTIONS.contactRequests).where('receiver', '==', String(receiverId));
  if (status) query = query.where('status', '==', status);
  const snap = await query.orderBy('createdAt', 'desc').get();
  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function listAcceptedRequestsForUser(userId) {
  const [asSender, asReceiver] = await Promise.all([
    listRequestsBySender(userId, 'accepted'),
    listRequestsByReceiver(userId, 'accepted'),
  ]);
  return [...asSender, ...asReceiver];
}

async function removeAcceptedContact(userA, userB) {
  const id = pairKey(userA, userB);
  const existing = await getContactRequestById(id);
  if (!existing || existing.status !== 'accepted') return false;
  await db.collection(COLLECTIONS.contactRequests).doc(id).delete();
  return true;
}

async function getAcceptedContactIds(userId) {
  const requests = await listAcceptedRequestsForUser(userId);
  const uid = String(userId);
  return requests.map((request) => (request.sender === uid ? request.receiver : request.sender));
}

async function blockUser(blockerId, blockedId) {
  const id = blockDocId(blockerId, blockedId);
  const ref = db.collection(COLLECTIONS.blockedUsers).doc(id);
  const payload = {
    blocker: String(blockerId),
    blocked: String(blockedId),
    createdAt: now(),
    updatedAt: now(),
  };
  await ref.set(payload, { merge: false });
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function getBlock(blockerId, blockedId) {
  const snap = await db.collection(COLLECTIONS.blockedUsers).doc(blockDocId(blockerId, blockedId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function isEitherBlocked(userA, userB) {
  const [direct, reverse] = await Promise.all([
    getBlock(userA, userB),
    getBlock(userB, userA),
  ]);
  return direct || reverse;
}

async function listBlockedByUser(userId) {
  const snap = await db.collection(COLLECTIONS.blockedUsers)
    .where('blocker', '==', String(userId))
    .orderBy('createdAt', 'desc')
    .get();

  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function listBlocksInvolvingUser(userId) {
  const [asBlocker, asBlocked] = await Promise.all([
    db.collection(COLLECTIONS.blockedUsers).where('blocker', '==', String(userId)).get(),
    db.collection(COLLECTIONS.blockedUsers).where('blocked', '==', String(userId)).get(),
  ]);

  const combined = [...asBlocker.docs, ...asBlocked.docs];
  return combined.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function unblockUser(blockerId, blockedId) {
  const ref = db.collection(COLLECTIONS.blockedUsers).doc(blockDocId(blockerId, blockedId));
  const snap = await ref.get();
  if (!snap.exists) return false;
  await ref.delete();
  return true;
}

function serializeMessageInput(payload) {
  return {
    sender: String(payload.sender),
    receiver: String(payload.receiver),
    text: payload.text || '',
    fileUrl: payload.fileUrl || null,
    fileName: payload.fileName || null,
    fileType: payload.fileType || null,
    clientMessageId: payload.clientMessageId || null,
    status: payload.status || 'sent',
    timestamp: payload.timestamp || now(),
    conversationKey: conversationKey(payload.sender, payload.receiver),
    createdAt: now(),
    updatedAt: now(),
  };
}

async function createMessage(payload) {
  const prepared = serializeMessageInput(payload);
  const ref = await db.collection(COLLECTIONS.messages).add(prepared);
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function getConversationMessages(userA, userB) {
  const key = conversationKey(userA, userB);
  const snap = await db.collection(COLLECTIONS.messages)
    .where('conversationKey', '==', key)
    .orderBy('timestamp', 'asc')
    .get();

  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function bulkDeleteMessagesForUser(userId, messageIds) {
  const refs = messageIds.map((id) => db.collection(COLLECTIONS.messages).doc(String(id)));
  const snapshots = await db.getAll(...refs);

  const batch = db.batch();
  let deletedCount = 0;

  snapshots.forEach((snap) => {
    if (!snap.exists) return;
    const data = snap.data() || {};
    const sender = String(data.sender || '');
    const receiver = String(data.receiver || '');
    if (sender === String(userId) || receiver === String(userId)) {
      batch.delete(snap.ref);
      deletedCount += 1;
    }
  });

  if (deletedCount > 0) {
    await batch.commit();
  }

  return deletedCount;
}

async function markConversationRead(userId, contactId) {
  const snap = await db.collection(COLLECTIONS.messages)
    .where('sender', '==', String(contactId))
    .where('receiver', '==', String(userId))
    .where('status', 'in', ['sent', 'delivered'])
    .get();

  if (snap.empty) return 0;

  const batch = db.batch();
  snap.docs.forEach((docSnap) => {
    batch.set(docSnap.ref, { status: 'read', updatedAt: now() }, { merge: true });
  });
  await batch.commit();
  return snap.size;
}

async function upsertAISettings(userId, patch = {}) {
  const ref = db.collection(COLLECTIONS.aiSettings).doc(String(userId));
  const snap = await ref.get();
  const base = snap.exists ? normalizeValue(snap.data()) : defaultAISettings(String(userId));

  const merged = {
    ...base,
    ...patch,
    defaultResponses: {
      ...(base.defaultResponses || {}),
      ...((patch && patch.defaultResponses) || {}),
    },
    updatedAt: now(),
    createdAt: base.createdAt || now(),
    user: String(userId),
  };

  await ref.set(merged, { merge: true });
  const finalDoc = await ref.get();
  return withIds(finalDoc.id, finalDoc.data());
}

async function getAISettings(userId) {
  const ref = db.collection(COLLECTIONS.aiSettings).doc(String(userId));
  const snap = await ref.get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function createGroup(payload) {
  const ref = await db.collection(COLLECTIONS.groups).add({
    ...payload,
    createdAt: now(),
    updatedAt: now(),
  });
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function updateGroup(groupId, patch) {
  const ref = db.collection(COLLECTIONS.groups).doc(String(groupId));
  await ref.set({ ...patch, updatedAt: now() }, { merge: true });
  const snap = await ref.get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function getGroupById(groupId) {
  const snap = await db.collection(COLLECTIONS.groups).doc(String(groupId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function deleteGroup(groupId) {
  await db.collection(COLLECTIONS.groups).doc(String(groupId)).delete();
}

async function listGroupsForMember(userId) {
  const snap = await db.collection(COLLECTIONS.groups)
    .where('members', 'array-contains', String(userId))
    .orderBy('updatedAt', 'desc')
    .get();
  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function createChannel(payload) {
  const ref = await db.collection(COLLECTIONS.channels).add({
    ...payload,
    posts: payload.posts || [],
    createdAt: now(),
    updatedAt: now(),
  });
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function getChannelById(channelId) {
  const snap = await db.collection(COLLECTIONS.channels).doc(String(channelId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function updateChannel(channelId, patch) {
  const ref = db.collection(COLLECTIONS.channels).doc(String(channelId));
  await ref.set({ ...patch, updatedAt: now() }, { merge: true });
  const snap = await ref.get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function deleteChannel(channelId) {
  await db.collection(COLLECTIONS.channels).doc(String(channelId)).delete();
}

async function listChannelsForSubscriber(userId) {
  const snap = await db.collection(COLLECTIONS.channels)
    .where('subscribers', 'array-contains', String(userId))
    .orderBy('updatedAt', 'desc')
    .get();
  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function discoverChannels(limit = 100) {
  const snap = await db.collection(COLLECTIONS.channels)
    .where('isPrivate', '==', false)
    .orderBy('updatedAt', 'desc')
    .limit(limit)
    .get();
  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function createStatus(payload) {
  const ref = await db.collection(COLLECTIONS.statuses).add({
    ...payload,
    views: payload.views || [],
    createdAt: now(),
    updatedAt: now(),
  });
  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function getStatusById(statusId) {
  const snap = await db.collection(COLLECTIONS.statuses).doc(String(statusId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function updateStatus(statusId, patch) {
  const ref = db.collection(COLLECTIONS.statuses).doc(String(statusId));
  await ref.set({ ...patch, updatedAt: now() }, { merge: true });
  const snap = await ref.get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function listStatusesByUsers(userIds) {
  const unique = Array.from(new Set((userIds || []).map(String).filter(Boolean)));
  if (!unique.length) return [];

  const chunkSize = 10;
  const chunks = [];
  for (let i = 0; i < unique.length; i += chunkSize) {
    chunks.push(unique.slice(i, i + chunkSize));
  }

  const nowDate = now();
  const snapshots = await Promise.all(
    chunks.map((chunk) =>
      db.collection(COLLECTIONS.statuses)
        .where('user', 'in', chunk)
        .where('expiresAt', '>', nowDate)
        .orderBy('expiresAt', 'asc')
        .get()
    )
  );

  const combined = snapshots.flatMap((snap) => snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data())));
  return combined.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

async function upsertCallLog(callId, patch) {
  const ref = db.collection(COLLECTIONS.callLogs).doc(String(callId));
  await ref.set({
    callId: String(callId),
    ...patch,
    updatedAt: now(),
    createdAt: patch.createdAt || now(),
  }, { merge: true });

  const snap = await ref.get();
  return withIds(snap.id, snap.data());
}

async function getCallLog(callId) {
  const snap = await db.collection(COLLECTIONS.callLogs).doc(String(callId)).get();
  if (!snap.exists) return null;
  return withIds(snap.id, snap.data());
}

async function listCallLogsForUser(userId, limit = 100) {
  const snap = await db.collection(COLLECTIONS.callLogs)
    .where('participants', 'array-contains', String(userId))
    .orderBy('startedAt', 'desc')
    .limit(limit)
    .get();

  return snap.docs.map((docSnap) => withIds(docSnap.id, docSnap.data()));
}

async function populateByUserFields(items, fields) {
  const rows = Array.isArray(items) ? items : [items];
  const allIds = [];

  for (const row of rows) {
    if (!row) continue;
    for (const field of fields) {
      const value = row[field];
      if (Array.isArray(value)) {
        value.forEach((id) => allIds.push(String(id)));
      } else if (typeof value === 'string' && value) {
        allIds.push(value);
      }
    }

    if (Array.isArray(row.posts)) {
      row.posts.forEach((post) => {
        if (post && post.author) allIds.push(String(post.author));
      });
    }
  }

  const usersMap = await getUsersMap(allIds, false);

  const result = rows.map((row) => {
    if (!row) return row;
    const clone = { ...row };

    for (const field of fields) {
      const value = clone[field];
      if (Array.isArray(value)) {
        clone[field] = value
          .map((id) => usersMap.get(String(id)))
          .filter(Boolean);
      } else if (typeof value === 'string' && value) {
        clone[field] = usersMap.get(value) || null;
      }
    }

    if (Array.isArray(clone.posts)) {
      clone.posts = clone.posts.map((post, idx) => ({
        _id: post._id || `${clone._id}_post_${idx}`,
        ...post,
        author: usersMap.get(String(post.author)) || null,
      }));
    }

    return clone;
  });

  return Array.isArray(items) ? result : result[0];
}

module.exports = {
  COLLECTIONS,
  FieldValue,
  now,
  normalizeValue,
  withIds,
  sanitizeUser,
  conversationKey,
  pairKey,

  getUsersMap,
  getUserById,
  getUserByUsername,
  getUserByEmail,
  createOrMergeUser,
  updateUser,
  searchUsers,

  upsertDeviceSession,
  listActiveDeviceSessions,
  getDeviceSessionById,
  deactivateDeviceSession,
  touchDeviceSession,

  getContactRequestById,
  getContactRequestByPair,
  createContactRequest,
  setContactRequestStatus,
  listRequestsBySender,
  listRequestsByReceiver,
  listAcceptedRequestsForUser,
  removeAcceptedContact,
  getAcceptedContactIds,

  blockUser,
  getBlock,
  isEitherBlocked,
  listBlockedByUser,
  listBlocksInvolvingUser,
  unblockUser,

  createMessage,
  getConversationMessages,
  bulkDeleteMessagesForUser,
  markConversationRead,

  upsertAISettings,
  getAISettings,

  createGroup,
  updateGroup,
  getGroupById,
  deleteGroup,
  listGroupsForMember,

  createChannel,
  getChannelById,
  updateChannel,
  deleteChannel,
  listChannelsForSubscriber,
  discoverChannels,

  createStatus,
  getStatusById,
  updateStatus,
  listStatusesByUsers,

  upsertCallLog,
  getCallLog,
  listCallLogsForUser,

  populateByUserFields,
};
