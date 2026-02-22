#!/usr/bin/env node
/* eslint-disable no-console */
const env = require('../config/env');
const { getFirebaseApp } = require('../config/firebase');

function requireEnv(name, value) {
  if (!String(value || '').trim()) {
    throw new Error(`Missing required env var: ${name}`);
  }
}

async function checkUrl(url) {
  const response = await fetch(url, { method: 'GET' });
  const body = await response.text();
  return { status: response.status, body };
}

async function run() {
  requireEnv('FIREBASE_WEB_API_KEY', env.firebaseWebApiKey);

  // Ensures Admin SDK initializes once and credentials are valid.
  getFirebaseApp();

  const baseUrl = process.env.RENDER_PUBLIC_URL || '';
  const result = {
    firebaseAdmin: 'ok',
    env: 'ok',
    urls: {},
  };

  if (baseUrl) {
    const root = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    result.urls.root = await checkUrl(`${root}/`);
    result.urls.health = await checkUrl(`${root}/health`);
  } else {
    result.urls.note = 'Set RENDER_PUBLIC_URL to run live URL checks';
  }

  console.log(JSON.stringify(result, null, 2));
}

run().catch((error) => {
  console.error('Preflight failed:', error.message);
  process.exit(1);
});

