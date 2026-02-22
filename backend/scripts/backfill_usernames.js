#!/usr/bin/env node
/* eslint-disable no-console */
const { getFirestore } = require('../config/firebase');

const db = getFirestore();
const USERNAME_REGEX = /^(?!.*__)[a-z](?:[a-z0-9_]{1,18}[a-z0-9])$/;
const RESERVED = new Set(['admin', 'support', 'system', 'null', 'undefined', 'api', 'root']);

const APPLY = process.argv.includes('--apply');
const PAGE_SIZE = Number(process.env.BACKFILL_PAGE_SIZE || 300);

function normalizeUsername(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFKC');
}

function fallbackFromUid(uid) {
  const safe = String(uid || '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .slice(0, 16);
  return `user${safe}`.slice(0, 20);
}

function buildCandidate(userDoc) {
  const raw = userDoc.username || userDoc.usernameLower || userDoc.username_search || '';
  let normalized = normalizeUsername(raw);
  if (!normalized) normalized = fallbackFromUid(userDoc.id);
  if (!/^[a-z]/.test(normalized)) normalized = `u${normalized}`;
  normalized = normalized
    .replace(/[^a-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
  if (normalized.length > 20) normalized = normalized.slice(0, 20).replace(/_+$/g, '');
  while (normalized.length < 3) normalized += 'x';
  if (!USERNAME_REGEX.test(normalized) || RESERVED.has(normalized)) {
    normalized = fallbackFromUid(userDoc.id);
  }
  return normalized;
}

async function run() {
  let lastDoc = null;
  let scanned = 0;
  let updatedUsers = 0;
  let createdReservations = 0;
  const collisions = [];

  while (true) {
    let query = db.collection('users').orderBy('__name__').limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const page = await query.get();
    if (page.empty) break;

    for (const docSnap of page.docs) {
      scanned += 1;
      const id = docSnap.id;
      const data = docSnap.data() || {};
      const usernameSearch = buildCandidate({ ...data, id });

      const reservationRef = db.collection('usernames').doc(usernameSearch);
      const publicRef = db.collection('users_public').doc(id);
      const reservationSnap = await reservationRef.get();
      const owner = reservationSnap.exists ? String((reservationSnap.data() || {}).uid || '') : '';
      if (owner && owner !== id) {
        collisions.push({ username_search: usernameSearch, existingUid: owner, incomingUid: id });
        continue;
      }

      if (APPLY) {
        const batch = db.batch();
        batch.set(
          docSnap.ref,
          {
            username: usernameSearch,
            usernameLower: usernameSearch,
            username_search: usernameSearch,
            updatedAt: new Date(),
          },
          { merge: true }
        );
        batch.set(
          publicRef,
          {
            uid: id,
            username: usernameSearch,
            username_search: usernameSearch,
            displayName: data.displayName || usernameSearch,
            photoUrl: data.avatar || '',
            isOnline: Boolean(data.isOnline),
            updatedAt: new Date(),
            createdAt: data.createdAt || new Date(),
          },
          { merge: true }
        );
        batch.set(
          reservationRef,
          {
            uid: id,
            username_search: usernameSearch,
            updatedAt: new Date(),
            createdAt: reservationSnap.exists ? reservationSnap.data().createdAt || new Date() : new Date(),
          },
          { merge: true }
        );
        await batch.commit();
      }

      updatedUsers += 1;
      if (!reservationSnap.exists) createdReservations += 1;
    }

    lastDoc = page.docs[page.docs.length - 1];
    if (page.size < PAGE_SIZE) break;
  }

  console.log(
    JSON.stringify(
      {
        mode: APPLY ? 'apply' : 'dry-run',
        scanned,
        updatedUsers,
        createdReservations,
        collisionCount: collisions.length,
        collisions: collisions.slice(0, 100),
      },
      null,
      2
    )
  );

  if (collisions.length > 0) {
    process.exitCode = 2;
  }
}

run().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
