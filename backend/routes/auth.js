const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const User = require('../models/User');
const DeviceSession = require('../models/DeviceSession');
const auth = require('../middleware/auth');
const env = require('../config/env');

const registerSchema = z.object({
  username: z.string().trim().min(3).transform((value) => value.toLowerCase()),
  password: z.string().min(6),
  deviceId: z.string().trim().min(1).optional(),
  deviceName: z.string().trim().min(1).optional(),
  platform: z.string().trim().min(1).optional(),
  appVersion: z.string().trim().min(1).optional(),
});

const loginSchema = z.object({
  username: z.string().trim().min(1).transform((value) => value.toLowerCase()),
  password: z.string().min(1),
  deviceId: z.string().trim().min(1).optional(),
  deviceName: z.string().trim().min(1).optional(),
  platform: z.string().trim().min(1).optional(),
  appVersion: z.string().trim().min(1).optional(),
});

async function upsertSession(userId, input) {
  const sessionPayload = {
    user: userId,
    deviceId: input.deviceId || `web-${Date.now()}`,
    deviceName: input.deviceName || 'Unknown device',
    platform: input.platform || 'unknown',
    appVersion: input.appVersion || '1.0.0',
    isActive: true,
    lastActiveAt: new Date(),
  };

  const session = await DeviceSession.findOneAndUpdate(
    { user: userId, deviceId: sessionPayload.deviceId },
    { $set: sessionPayload },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  return session;
}

router.post('/register', async (req, res) => {
  try {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid input', details: parsed.error.flatten() });
    }

    const { username, password } = parsed.data;
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ error: 'Username already exists' });
    }

    const user = new User({ username, password });
    await user.save();

    const session = await upsertSession(user._id, parsed.data);

    const token = jwt.sign(
      { userId: user._id, sid: session._id },
      env.jwtSecret,
      { expiresIn: env.jwtExpiresIn }
    );

    res.status(201).json({
      message: 'User created successfully',
      token,
      sessionId: session._id,
      user: user.toJSON(),
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid input', details: parsed.error.flatten() });
    }

    const { username, password } = parsed.data;
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const session = await upsertSession(user._id, parsed.data);

    const token = jwt.sign(
      { userId: user._id, sid: session._id },
      env.jwtSecret,
      { expiresIn: env.jwtExpiresIn }
    );

    res.json({
      message: 'Login successful',
      token,
      sessionId: session._id,
      user: user.toJSON(),
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Server error during login' });
  }
});

router.get('/me', auth, async (req, res) => {
  try {
    res.json({ user: req.user.toJSON() });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

