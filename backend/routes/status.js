const express = require('express');
const { z } = require('zod');

const auth = require('../middleware/auth');
const upload = require('../middleware/upload');
const {
  createStatus,
  listStatusesByUsers,
  getStatusById,
  updateStatus,
  getAcceptedContactIds,
  populateByUserFields,
} = require('../services/store');

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

    const status = await createStatus({
      user: req.userId,
      caption: parsed.data.caption,
      mediaUrl,
      mediaType,
      views: [],
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    });

    const populated = await populateByUserFields(status, ['user', 'views']);
    return res.status(201).json({ status: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/feed', auth, async (req, res) => {
  try {
    const contactIds = await getAcceptedContactIds(req.userId);
    const statuses = await listStatusesByUsers([req.userId, ...contactIds]);
    const populated = await populateByUserFields(statuses, ['user', 'views']);
    return res.json({ statuses: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.put('/:id/view', auth, async (req, res) => {
  try {
    const status = await getStatusById(req.params.id);
    if (!status) {
      return res.status(404).json({ error: 'Status not found' });
    }

    const views = new Set((status.views || []).map(String));
    if (!views.has(req.userId)) {
      views.add(req.userId);
      await updateStatus(status._id, { views: Array.from(views) });
    }

    return res.json({ message: 'Viewed' });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
