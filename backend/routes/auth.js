const express = require('express');
const { z } = require('zod');

const auth = require('../middleware/auth');
const env = require('../config/env');
const { getAuth } = require('../config/firebase');
const {
  getUserByUsername,
  getUserByEmail,
  createOrMergeUser,
  upsertDeviceSession,
  sanitizeUser,
} = require('../services/store');

const router = express.Router();
const USERNAME_REGEX = /^(?!.*__)[a-z](?:[a-z0-9_]{1,18}[a-z0-9])$/;

const baseAuthSchema = {
  deviceId: z.string().trim().min(1).optional(),
  deviceName: z.string().trim().min(1).optional(),
  platform: z.string().trim().min(1).optional(),
  appVersion: z.string().trim().min(1).optional(),
};

const registerSchema = z.object({
  username: z.string().trim().min(3).optional(),
  email: z.string().trim().email().optional(),
  password: z.string().min(6),
  ...baseAuthSchema,
});

const loginSchema = z.object({
  username: z.string().trim().min(1).optional(),
  email: z.string().trim().email().optional(),
  password: z.string().min(1),
  ...baseAuthSchema,
});

const googleLoginSchema = z.object({
  idToken: z.string().min(10),
  ...baseAuthSchema,
});

const firebaseSessionSchema = z.object({
  idToken: z.string().min(10),
  username: z.string().trim().min(3).optional(),
  email: z.string().trim().email().optional(),
  ...baseAuthSchema,
});

function fallbackEmailFromUsername(username) {
  const clean = String(username || '').trim().toLowerCase().replace(/[^a-z0-9._-]/g, '');
  return `${clean || `user${Date.now()}`}@chatheist.local`;
}

function canonicalizeUsernameSeed(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFKC')
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function buildValidUsername(baseValue, uid) {
  let candidate = canonicalizeUsernameSeed(baseValue);
  const uidSeed = String(uid || '').replace(/[^a-z0-9]/gi, '').toLowerCase() || 'userseed';

  if (!candidate || !/^[a-z]/.test(candidate)) {
    candidate = `u${candidate}`;
  }

  candidate = candidate.replace(/_+/g, '_').replace(/^_+|_+$/g, '');
  if (candidate.length > 20) candidate = candidate.slice(0, 20);
  candidate = candidate.replace(/_+$/g, '');

  let i = 0;
  while (candidate.length < 3 && i < uidSeed.length) {
    candidate += uidSeed[i];
    i += 1;
  }

  if (!USERNAME_REGEX.test(candidate)) {
    const fallback = `u${uidSeed.slice(0, 19)}`.slice(0, 20).replace(/_+$/g, '');
    candidate = USERNAME_REGEX.test(fallback) ? fallback : `user${uidSeed.slice(0, 16)}`;
  }

  return candidate;
}

async function identityToolkit(path, payload) {
  if (!env.firebaseWebApiKey) {
    throw new Error('Missing FIREBASE_WEB_API_KEY');
  }

  const url = `https://identitytoolkit.googleapis.com/v1/${path}?key=${env.firebaseWebApiKey}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const data = await response.json();
  if (!response.ok) {
    const message = data?.error?.message || 'Firebase Auth error';
    throw new Error(message);
  }

  return data;
}

async function resolveUniqueUsername(uid, usernameCandidate, emailCandidate) {
  let username = buildValidUsername(usernameCandidate, uid);
  if (!username) {
    const email = String(emailCandidate || '').trim().toLowerCase();
    if (email.includes('@')) {
      username = buildValidUsername(email.split('@')[0], uid);
    } else {
      username = buildValidUsername(`user_${String(uid).slice(0, 8)}`, uid);
    }
  }

  const existingByUsername = await getUserByUsername(username);
  if (existingByUsername && String(existingByUsername._id) !== String(uid)) {
    const suffix = String(uid).toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 6) || 'u12345';
    const base = username.slice(0, Math.max(3, 20 - (suffix.length + 1))).replace(/_+$/g, '');
    username = buildValidUsername(`${base}_${suffix}`, uid);
  }

  return username;
}

async function issueSessionFromFirebaseUser(idToken, payload = {}) {
  const decoded = await getAuth().verifyIdToken(idToken);
  const firebaseUser = await getAuth().getUser(decoded.uid);

  const email = String(payload.email || firebaseUser.email || '').trim().toLowerCase();
  const username = await resolveUniqueUsername(
    decoded.uid,
    payload.username || firebaseUser.displayName,
    email
  );

  const profile = await createOrMergeUser(decoded.uid, {
    username,
    email,
    ...(firebaseUser.photoURL ? { avatar: firebaseUser.photoURL } : {}),
    ...(firebaseUser.displayName ? { displayName: firebaseUser.displayName } : {}),
  });

  const session = await upsertDeviceSession(profile._id, payload);

  return {
    token: idToken,
    sessionId: session._id,
    user: sanitizeUser(profile),
  };
}

async function hydrateProfileFromAuth(authData, body, fallbackUsernameSeed = '') {
  const uid = authData.localId || authData.uid;
  const email = String(authData.email || body.email || '').trim().toLowerCase();

  const username = await resolveUniqueUsername(
    uid,
    body.username,
    email || fallbackUsernameSeed
  );

  const profile = await createOrMergeUser(uid, {
    username,
    email,
    ...(authData.displayName ? { displayName: authData.displayName } : {}),
  });

  return profile;
}

router.post('/register', async (req, res) => {
  try {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid input', details: parsed.error.flatten() });
    }

    const body = parsed.data;
    if (!body.username && !body.email) {
      return res.status(400).json({ error: 'username or email is required' });
    }

    const normalizedUsername = body.username ? body.username.toLowerCase() : null;

    const email = body.email ? body.email.toLowerCase() : fallbackEmailFromUsername(normalizedUsername);
    const signUp = await identityToolkit('accounts:signUp', {
      email,
      password: body.password,
      returnSecureToken: true,
    });

    const profile = await hydrateProfileFromAuth(signUp, body, normalizedUsername || email);
    const session = await upsertDeviceSession(profile._id, body);

    return res.status(201).json({
      message: 'User created successfully',
      token: signUp.idToken,
      refreshToken: signUp.refreshToken,
      sessionId: session._id,
      user: sanitizeUser(profile),
    });
  } catch (error) {
    return res.status(500).json({ error: `Server error during registration: ${error.message}` });
  }
});

router.post('/login', async (req, res) => {
  try {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid input', details: parsed.error.flatten() });
    }

    const body = parsed.data;
    if (!body.username && !body.email) {
      return res.status(400).json({ error: 'username or email is required' });
    }

    let email = body.email ? body.email.toLowerCase() : '';
    if (!email && body.username) {
      const user = await getUserByUsername(body.username.toLowerCase());
      if (user?.email) {
        email = user.email;
      } else {
        email = fallbackEmailFromUsername(body.username.toLowerCase());
      }
    }

    const login = await identityToolkit('accounts:signInWithPassword', {
      email,
      password: body.password,
      returnSecureToken: true,
    });

    const profile = await hydrateProfileFromAuth(login, body, email);
    const session = await upsertDeviceSession(profile._id, body);

    return res.json({
      message: 'Login successful',
      token: login.idToken,
      refreshToken: login.refreshToken,
      sessionId: session._id,
      user: sanitizeUser(profile),
    });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
});

router.post('/google', async (req, res) => {
  try {
    const parsed = googleLoginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid input', details: parsed.error.flatten() });
    }

    const sessionPayload = await issueSessionFromFirebaseUser(parsed.data.idToken, parsed.data);

    return res.json({
      message: 'Google login successful',
      ...sessionPayload,
    });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid Google token' });
  }
});

router.post('/firebase', async (req, res) => {
  try {
    const parsed = firebaseSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid input', details: parsed.error.flatten() });
    }

    const sessionPayload = await issueSessionFromFirebaseUser(parsed.data.idToken, parsed.data);

    return res.json({
      message: 'Firebase session established',
      ...sessionPayload,
    });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid Firebase token' });
  }
});

router.get('/me', auth, async (req, res) => {
  try {
    return res.json({ user: req.user });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
