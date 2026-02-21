const express = require('express');
const { z } = require('zod');

const auth = require('../middleware/auth');
const {
  createChannel,
  getChannelById,
  updateChannel,
  deleteChannel,
  listChannelsForSubscriber,
  discoverChannels,
  populateByUserFields,
  now,
} = require('../services/store');

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

    const channel = await createChannel({
      ...parsed.data,
      avatar: '',
      creator: req.userId,
      admins: [req.userId],
      subscribers: [req.userId],
      posts: [],
    });

    const populated = await populateByUserFields(channel, ['creator', 'admins', 'subscribers']);
    return res.status(201).json({ channel: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const channels = await listChannelsForSubscriber(req.userId);
    const populated = await populateByUserFields(channels, ['creator', 'admins', 'subscribers']);
    return res.json({ channels: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/discover', auth, async (req, res) => {
  try {
    const channels = await discoverChannels(100);
    const populated = await populateByUserFields(channels, ['creator', 'admins', 'subscribers']);
    return res.json({ channels: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/join', auth, async (req, res) => {
  try {
    const channel = await getChannelById(req.params.id);
    if (!channel) return res.status(404).json({ error: 'Channel not found' });
    if (channel.isPrivate) return res.status(403).json({ error: 'Private channel' });

    const subscribers = Array.from(new Set([...(channel.subscribers || []).map(String), req.userId]));
    const updated = await updateChannel(channel._id, { subscribers });

    const populated = await populateByUserFields(updated, ['creator', 'admins', 'subscribers']);
    return res.json({ channel: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/leave', auth, async (req, res) => {
  try {
    const channel = await getChannelById(req.params.id);
    if (!channel) return res.status(404).json({ error: 'Channel not found' });

    const uid = String(req.userId);
    const subscribers = (channel.subscribers || []).map(String).filter((id) => id !== uid);
    const admins = (channel.admins || []).map(String).filter((id) => id !== uid);

    if (!subscribers.length) {
      await deleteChannel(channel._id);
      return res.json({ message: 'Channel removed' });
    }

    const nextAdmins = admins.length ? admins : [String(channel.creator)];
    const updated = await updateChannel(channel._id, {
      subscribers,
      admins: nextAdmins,
    });

    const populated = await populateByUserFields(updated, ['creator', 'admins', 'subscribers']);
    return res.json({ channel: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/posts', auth, async (req, res) => {
  try {
    const parsed = postSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const channel = await getChannelById(req.params.id);
    if (!channel) return res.status(404).json({ error: 'Channel not found' });

    const admins = (channel.admins || []).map(String);
    if (!admins.includes(req.userId)) {
      return res.status(403).json({ error: 'Only admins can publish posts' });
    }
    if (!parsed.data.text) {
      return res.status(400).json({ error: 'Post text is required' });
    }

    const post = {
      _id: `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
      author: req.userId,
      text: parsed.data.text,
      mediaUrl: null,
      createdAt: now(),
    };

    const posts = [post, ...((channel.posts || []).slice(0, 199))];
    const updated = await updateChannel(channel._id, { posts });
    const populated = await populateByUserFields(updated, ['creator', 'admins', 'subscribers']);

    return res.status(201).json({ channel: populated, post: populated.posts[0] });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
