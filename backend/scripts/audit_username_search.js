#!/usr/bin/env node
/* eslint-disable no-console */
const { getFirestore } = require('../config/firebase');

const db = getFirestore();
const PAGE_SIZE = Number(process.env.AUDIT_PAGE_SIZE || 500);

async function run() {
  let lastDoc = null;
  let scanned = 0;
  const missing = [];
  const nullish = [];

  while (true) {
    let query = db.collection('users').orderBy('__name__').limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      if (!Object.prototype.hasOwnProperty.call(data, 'username_search')) {
        missing.push(doc.id);
        continue;
      }
      const value = data.username_search;
      if (value == null || String(value).trim() === '') {
        nullish.push(doc.id);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE_SIZE) break;
  }

  console.log(
    JSON.stringify(
      {
        scanned,
        missingFieldCount: missing.length,
        nullOrEmptyCount: nullish.length,
        missingSample: missing.slice(0, 100),
        nullOrEmptySample: nullish.slice(0, 100),
      },
      null,
      2
    )
  );
}

run().catch((error) => {
  console.error('Audit failed:', error);
  process.exit(1);
});

