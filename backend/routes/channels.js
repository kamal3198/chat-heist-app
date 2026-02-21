const express = require('express');
const { z } = require('zod');
const auth = require('../middleware/auth');
const Channel = require('../models/Channel');

const router = express.Router();

const createSchema = z.object({
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(250).optional().default(''),
  kind: z.enum(['channel', 'community']).optional().default('channel'),
  isPrivate: z.boolean().optional().default(false),
});

const postSchema = z.object({
  text: z.string().trim().max(2000).optional().default(''),
});

router.post('/', auth, async (req, res) => {
  try {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const channel = await Channel.create({
      ...parsed.data,
      creator: req.userId,
      admins: [req.userId],
      subscribers: [req.userId],
    });

    await channel.populate('creator admins subscribers posts.author', '-password');
    res.status(201).json({ channel });
  } catch (error) {
    console.error('Create channel error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const channels = await Channel.find({ subscribers: req.userId })
      .populate('creator admins subscribers posts.author', '-password')
      .sort({ updatedAt: -1 });
    res.json({ channels });
  } catch (error) {
    console.error('List channels error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/discover', auth, async (req, res) => {
  try {
    const channels = await Channel.find({ isPrivate: false })
      .populate('creator admins subscribers posts.author', '-password')
      .sort({ updatedAt: -1 })
      .limit(100);
    res.json({ channels });
  } catch (error) {
    console.error('Discover channels error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/join', auth, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.id);
    if (!channel) return res.status(404).json({ error: 'Channel not found' });
    if (channel.isPrivate) return res.status(403).json({ error: 'Private channel' });

    if (!channel.subscribers.some((id) => id.toString() === req.userId.toString())) {
      channel.subscribers.push(req.userId);
      await channel.save();
    }

    await channel.populate('creator admins subscribers posts.author', '-password');
    res.json({ channel });
  } catch (error) {
    console.error('Join channel error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/leave', auth, async (req, res) => {
  try {
    const channel = await Channel.findById(req.params.id);
    if (!channel) return res.status(404).json({ error: 'Channel not found' });

    channel.subscribers = channel.subscribers.filter((id) => id.toString() !== req.userId.toString());
    channel.admins = channel.admins.filter((id) => id.toString() !== req.userId.toString());

    if (!channel.subscribers.length) {
      await channel.deleteOne();
      return res.json({ message: 'Channel removed' });
    }

    if (!channel.admins.length) channel.admins = [channel.creator];

    await channel.save();
    await channel.populate('creator admins subscribers posts.author', '-password');
    res.json({ channel });
  } catch (error) {
    console.error('Leave channel error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/posts', auth, async (req, res) => {
  try {
    const parsed = postSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const channel = await Channel.findById(req.params.id);
    if (!channel) return res.status(404).json({ error: 'Channel not found' });

    const isAdmin = channel.admins.some((id) => id.toString() === req.userId.toString());
    if (!isAdmin) return res.status(403).json({ error: 'Only admins can publish posts' });
    if (!parsed.data.text) return res.status(400).json({ error: 'Post text is required' });

    channel.posts.unshift({ author: req.userId, text: parsed.data.text, createdAt: new Date() });
    await channel.save();
    await channel.populate('creator admins subscribers posts.author', '-password');

    res.status(201).json({ channel, post: channel.posts[0] });
  } catch (error) {
    console.error('Create channel post error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

