const express = require('express');
const { z } = require('zod');

const auth = require('../middleware/auth');
const { getAISettings, upsertAISettings } = require('../services/store');

const router = express.Router();

const updateSettingsSchema = z.object({
  enabled: z.boolean().optional(),
  autoReplyEnabled: z.boolean().optional(),
  autoReplyRules: z.array(
    z.object({
      keyword: z.string(),
      response: z.string(),
      isCaseSensitive: z.boolean().optional(),
    })
  ).optional(),
  defaultResponses: z.object({
    away: z.string().optional(),
    busy: z.string().optional(),
    custom: z.string().optional(),
  }).optional(),
  quickReplies: z.array(z.string()).optional(),
});

router.get('/', auth, async (req, res) => {
  try {
    let settings = await getAISettings(req.userId);
    if (!settings) {
      settings = await upsertAISettings(req.userId, {});
    }

    return res.json({ settings });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.put('/', auth, async (req, res) => {
  try {
    const parsed = updateSettingsSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const settings = await upsertAISettings(req.userId, parsed.data);
    return res.json({ settings });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/rules', auth, async (req, res) => {
  try {
    const { keyword, response, isCaseSensitive } = req.body;

    if (!keyword || !response) {
      return res.status(400).json({ error: 'Keyword and response are required' });
    }

    const current = (await getAISettings(req.userId)) || (await upsertAISettings(req.userId, {}));
    const autoReplyRules = [
      ...(current.autoReplyRules || []),
      { keyword, response, isCaseSensitive: !!isCaseSensitive },
    ];

    const settings = await upsertAISettings(req.userId, { autoReplyRules });
    return res.json({ rules: settings.autoReplyRules });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/rules/:ruleIndex', auth, async (req, res) => {
  try {
    const ruleIndex = Number(req.params.ruleIndex);
    const settings = await getAISettings(req.userId);

    if (!settings) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    const rules = [...(settings.autoReplyRules || [])];
    if (!Number.isInteger(ruleIndex) || ruleIndex < 0 || ruleIndex >= rules.length) {
      return res.status(400).json({ error: 'Invalid rule index' });
    }

    rules.splice(ruleIndex, 1);
    const updated = await upsertAISettings(req.userId, { autoReplyRules: rules });
    return res.json({ rules: updated.autoReplyRules });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/quick-replies', auth, async (req, res) => {
  try {
    const { reply } = req.body;
    if (!reply) {
      return res.status(400).json({ error: 'Reply text is required' });
    }

    const settings = (await getAISettings(req.userId)) || (await upsertAISettings(req.userId, {}));
    const quickReplies = [...(settings.quickReplies || []), reply];
    const updated = await upsertAISettings(req.userId, { quickReplies });

    return res.json({ quickReplies: updated.quickReplies });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/quick-replies/:replyIndex', auth, async (req, res) => {
  try {
    const replyIndex = Number(req.params.replyIndex);
    const settings = await getAISettings(req.userId);

    if (!settings) {
      return res.status(404).json({ error: 'Settings not found' });
    }

    const quickReplies = [...(settings.quickReplies || [])];
    if (!Number.isInteger(replyIndex) || replyIndex < 0 || replyIndex >= quickReplies.length) {
      return res.status(400).json({ error: 'Invalid reply index' });
    }

    quickReplies.splice(replyIndex, 1);
    const updated = await upsertAISettings(req.userId, { quickReplies });

    return res.json({ quickReplies: updated.quickReplies });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/toggle', auth, async (req, res) => {
  try {
    const { enabled } = req.body;
    const settings = (await getAISettings(req.userId)) || (await upsertAISettings(req.userId, {}));

    const nextEnabled = typeof enabled === 'boolean' ? enabled : !settings.enabled;
    const updated = await upsertAISettings(req.userId, { enabled: nextEnabled });

    return res.json({ enabled: updated.enabled });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
