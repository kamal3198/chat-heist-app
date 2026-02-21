const express = require('express');
const { z } = require('zod');
const auth = require('../middleware/auth');
const AISettings = require('../models/AISettings');

const router = express.Router();

const updateSettingsSchema = z.object({
  enabled: z.boolean().optional(),
  autoReplyEnabled: z.boolean().optional(),
  autoReplyRules: z.array(z.object({
    keyword: z.string(),
    response: z.string(),
    isCaseSensitive: z.boolean().optional(),
  })).optional(),
  defaultResponses: z.object({
    away: z.string().optional(),
    busy: z.string().optional(),
    custom: z.string().optional(),
  }).optional(),
  quickReplies: z.array(z.string()).optional(),
});

// Get AI settings
router.get('/', auth, async (req, res) => {
  try {
    let settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      // Create default settings if not exists
      settings = await AISettings.create({ user: req.userId });
    }

    res.json({ settings });
  } catch (error) {
    console.error('Get AI settings error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Update AI settings
router.put('/', auth, async (req, res) => {
  try {
    const parsed = updateSettingsSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    let settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      settings = await AISettings.create({ user: req.userId });
    }

    // Update fields
    if (parsed.data.enabled !== undefined) {
      settings.enabled = parsed.data.enabled;
    }
    if (parsed.data.autoReplyEnabled !== undefined) {
      settings.autoReplyEnabled = parsed.data.autoReplyEnabled;
    }
    if (parsed.data.autoReplyRules !== undefined) {
      settings.autoReplyRules = parsed.data.autoReplyRules;
    }
    if (parsed.data.defaultResponses !== undefined) {
      settings.defaultResponses = { ...settings.defaultResponses, ...parsed.data.defaultResponses };
    }
    if (parsed.data.quickReplies !== undefined) {
      settings.quickReplies = parsed.data.quickReplies;
    }

    await settings.save();

    res.json({ settings });
  } catch (error) {
    console.error('Update AI settings error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Add auto-reply rule
router.post('/rules', auth, async (req, res) => {
  try {
    const { keyword, response, isCaseSensitive } = req.body;

    if (!keyword || !response) {
      return res.status(400).json({ error: 'Keyword and response are required' });
    }

    let settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      settings = await AISettings.create({ user: req.userId });
    }

    settings.autoReplyRules.push({
      keyword,
      response,
      isCaseSensitive: isCaseSensitive || false,
    });

    await settings.save();

    res.json({ rules: settings.autoReplyRules });
  } catch (error) {
    console.error('Add rule error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Delete auto-reply rule
router.delete('/rules/:ruleIndex', auth, async (req, res) => {
  try {
    const ruleIndex = parseInt(req.params.ruleIndex);

    const settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    if (ruleIndex < 0 || ruleIndex >= settings.autoReplyRules.length) {
      return res.status(400).json({ error: 'Invalid rule index' });
    }

    settings.autoReplyRules.splice(ruleIndex, 1);
    await settings.save();

    res.json({ rules: settings.autoReplyRules });
  } catch (error) {
    console.error('Delete rule error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Add quick reply
router.post('/quick-replies', auth, async (req, res) => {
  try {
    const { reply } = req.body;

    if (!reply) {
      return res.status(400).json({ error: 'Reply text is required' });
    }

    let settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      settings = await AISettings.create({ user: req.userId });
    }

    settings.quickReplies.push(reply);
    await settings.save();

    res.json({ quickReplies: settings.quickReplies });
  } catch (error) {
    console.error('Add quick reply error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Delete quick reply
router.delete('/quick-replies/:replyIndex', auth, async (req, res) => {
  try {
    const replyIndex = parseInt(req.params.replyIndex);

    const settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    if (replyIndex < 0 || replyIndex >= settings.quickReplies.length) {
      return res.status(400).json({ error: 'Invalid reply index' });
    }

    settings.quickReplies.splice(replyIndex, 1);
    await settings.save();

    res.json({ quickReplies: settings.quickReplies });
  } catch (error) {
    console.error('Delete quick reply error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Toggle AI feature
router.post('/toggle', auth, async (req, res) => {
  try {
    const { enabled } = req.body;

    let settings = await AISettings.findOne({ user: req.userId });
    
    if (!settings) {
      settings = await AISettings.create({ user: req.userId, enabled: enabled ?? true });
    } else {
      settings.enabled = enabled !== undefined ? enabled : !settings.enabled;
      await settings.save();
    }

    res.json({ enabled: settings.enabled });
  } catch (error) {
    console.error('Toggle AI error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
