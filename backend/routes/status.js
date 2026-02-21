const express = require('express');
const { z } = require('zod');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');
const Status = require('../models/Status');
const ContactRequest = require('../models/ContactRequest');

const router = express.Router();

const createStatusSchema = z.object({
  caption: z.string().trim().max(700).optional().default(''),
  mediaType: z.enum(['text', 'image', 'video']).optional().default('text'),
});

router.post('/', auth, upload.single('media'), async (req, res) => {
  try {
    const parsed = createStatusSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    let mediaUrl = '';
    let mediaType = parsed.data.mediaType;
    if (req.file) {
      mediaUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      const mime = req.file.mimetype || '';
      mediaType = mime.startsWith('video/') ? 'video' : 'image';
    }

    if (!parsed.data.caption && !mediaUrl) {
      return res.status(400).json({ error: 'Caption or media is required' });
    }

    const status = await Status.create({
      user: req.userId,
      caption: parsed.data.caption,
      mediaUrl,
      mediaType,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    });

    await status.populate('user views', '-password');
    res.status(201).json({ status });
  } catch (error) {
    console.error('Create status error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/feed', auth, async (req, res) => {
  try {
    const connections = await ContactRequest.find({
      $or: [
        { sender: req.userId, status: 'accepted' },
        { receiver: req.userId, status: 'accepted' },
      ],
    });

    const contactIds = connections.map((entry) =>
      entry.sender.toString() === req.userId.toString() ? entry.receiver : entry.sender
    );

    const statuses = await Status.find({
      user: { $in: [req.userId, ...contactIds] },
      expiresAt: { $gt: new Date() },
    })
      .populate('user views', '-password')
      .sort({ createdAt: -1 });

    res.json({ statuses });
  } catch (error) {
    console.error('Status feed error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.put('/:id/view', auth, async (req, res) => {
  try {
    const status = await Status.findById(req.params.id);
    if (!status) {
      return res.status(404).json({ error: 'Status not found' });
    }

    if (!status.views.some((id) => id.toString() === req.userId.toString())) {
      status.views.push(req.userId);
      await status.save();
    }

    res.json({ message: 'Viewed' });
  } catch (error) {
    console.error('Status view error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

