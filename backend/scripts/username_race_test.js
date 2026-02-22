#!/usr/bin/env node
/* eslint-disable no-console */
const { getFirestore } = require('../config/firebase');

const db = getFirestore();
const attempts = Number(process.env.RACE_ATTEMPTS || 50);
const target = (process.env.RACE_USERNAME || `race_${Date.now()}`).toLowerCase();
const cleanup = process.argv.includes('--cleanup');

async function claim(username, uid) {
  const ref = db.collection('usernames').doc(username);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      const owner = String((snap.data() || {}).uid || '');
      if (owner && owner !== uid) {
        throw new Error(`reserved_by_${owner}`);
      }
    }
    tx.set(
      ref,
      {
        uid,
        username_search: username,
        updatedAt: new Date(),
        createdAt: snap.exists ? snap.data().createdAt || new Date() : new Date(),
      },
      { merge: true }
    );
  });
}

async function run() {
  const ids = Array.from({ length: attempts }, (_, i) => `race-user-${i + 1}`);
  const results = await Promise.allSettled(ids.map((uid) => claim(target, uid)));
  const success = results
    .map((r, i) => ({ r, uid: ids[i] }))
    .filter(({ r }) => r.status === 'fulfilled')
    .map(({ uid }) => uid);
  const failed = results
    .map((r, i) => ({ r, uid: ids[i] }))
    .filter(({ r }) => r.status === 'rejected')
    .map(({ uid, r }) => ({ uid, reason: String(r.reason?.message || r.reason) }));

  const reservation = await db.collection('usernames').doc(target).get();
  const owner = reservation.exists ? reservation.data().uid : null;

  console.log(
    JSON.stringify(
      {
        target,
        attempts,
        successCount: success.length,
        failureCount: failed.length,
        owner,
        successes: success,
        failures: failed.slice(0, 10),
      },
      null,
      2
    )
  );

  if (cleanup) {
    await db.collection('usernames').doc(target).delete();
    console.log(`cleanup=true deleted usernames/${target}`);
  }
}

run().catch((error) => {
  console.error('Race test failed:', error);
  process.exit(1);
});

