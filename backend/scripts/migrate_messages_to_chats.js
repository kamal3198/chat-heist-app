const { getFirestore, admin } = require('../config/firebase');

const db = getFirestore();
const FieldValue = admin.firestore.FieldValue;
const APPLY = process.argv.includes('--apply');
const PAGE_SIZE = 200;

function asDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function normalizeStatus(status) {
  return status === 'read' || status === 'seen' ? 'seen' : 'sent';
}

function sortedChatId(a, b) {
  return [String(a).trim(), String(b).trim()].sort().join('__');
}

function canonicalMessage(data) {
  const senderId = String(data.senderId || data.sender || '').trim();
  const receiverId = String(data.receiverId || data.receiver || '').trim();
  const timestamp = data.timestamp || data.sentAt || FieldValue.serverTimestamp();
  const deliveryStatus = normalizeStatus(data.deliveryStatus || data.status);

  return {
    senderId,
    receiverId,
    text: String(data.text || data.message || ''),
    type: String(data.type || (data.fileUrl ? 'image' : 'text')),
    fileUrl: data.fileUrl || null,
    fileName: data.fileName || null,
    fileType: data.fileType || null,
    clientMessageId: data.clientMessageId || null,
    deliveryStatus,
    sentAt: data.sentAt || timestamp,
    timestamp,
    seenAt: data.seenAt || (deliveryStatus === 'seen' ? data.updatedAt || timestamp : null),
    deletedFor: Array.isArray(data.deletedFor) ? data.deletedFor.map(String) : [],
    createdAt: data.createdAt || timestamp,
    updatedAt: data.updatedAt || timestamp,
  };
}

async function migratePage(startAfterDoc) {
  let query = db.collection('messages').orderBy('__name__').limit(PAGE_SIZE);
  if (startAfterDoc) query = query.startAfter(startAfterDoc);

  const snap = await query.get();
  if (snap.empty) return { lastDoc: null, scanned: 0, migratable: 0, skipped: 0 };

  const batch = db.batch();
  let migratable = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const message = canonicalMessage(data);
    if (!message.senderId || !message.receiverId) {
      skipped += 1;
      console.warn(`[migrate:messages] skip ${doc.id}: missing sender/receiver`);
      continue;
    }

    const chatId = data.conversationKey || sortedChatId(message.senderId, message.receiverId);
    const chatRef = db.collection('chats').doc(chatId);
    const messageRef = chatRef.collection('messages').doc(doc.id);
    const lastDate = asDate(message.timestamp) || asDate(message.sentAt);

    batch.set(chatRef, {
      participants: [message.senderId, message.receiverId].sort(),
      lastMessage: message.text,
      lastTimestamp: message.timestamp || FieldValue.serverTimestamp(),
      lastSenderId: message.senderId,
      lastDeliveryStatus: message.deliveryStatus,
      retentionPolicy: {
        enabled: false,
        retainDays: 30,
      },
      migratedFromTopLevelMessagesAt: FieldValue.serverTimestamp(),
      updatedAt: lastDate || FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(messageRef, {
      ...message,
      legacyMessageId: doc.id,
      migratedFromTopLevelMessages: true,
    }, { merge: true });
    migratable += 1;
  }

  if (APPLY && migratable > 0) {
    await batch.commit();
  }

  return {
    lastDoc: snap.docs[snap.docs.length - 1],
    scanned: snap.size,
    migratable,
    skipped,
  };
}

async function main() {
  console.log(`[migrate:messages] mode=${APPLY ? 'apply' : 'dry-run'}`);
  let startAfterDoc = null;
  let scanned = 0;
  let migratable = 0;
  let skipped = 0;

  while (true) {
    const page = await migratePage(startAfterDoc);
    if (!page.lastDoc) break;
    scanned += page.scanned;
    migratable += page.migratable;
    skipped += page.skipped;
    startAfterDoc = page.lastDoc;
    console.log(
      `[migrate:messages] scanned=${scanned} migratable=${migratable} skipped=${skipped}`
    );
  }

  console.log(
    `[migrate:messages] done scanned=${scanned} migratable=${migratable} skipped=${skipped}`
  );
  if (!APPLY) {
    console.log('[migrate:messages] dry-run only. Re-run with --apply to write canonical docs.');
  }
}

main().catch((error) => {
  console.error('[migrate:messages] failed', error);
  process.exitCode = 1;
});
