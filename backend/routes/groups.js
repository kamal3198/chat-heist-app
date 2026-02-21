const express = require('express');
const { z } = require('zod');
const auth = require('../middleware/auth');
const Group = require('../models/Group');

const router = express.Router();

const createGroupSchema = z.object({
  name: z.string().trim().min(2).max(50),
  description: z.string().trim().max(200).optional().default(''),
  memberIds: z.array(z.string().min(1)).min(1),
});

const updateMembersSchema = z.object({
  memberIds: z.array(z.string().min(1)).min(1),
});

function isAdmin(group, userId) {
  return group.admins.some((id) => id.toString() === userId.toString());
}

// Create group
router.post('/', auth, async (req, res) => {
  try {
    const parsed = createGroupSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const creatorId = req.userId.toString();
    const uniqueMembers = Array.from(
      new Set([creatorId, ...parsed.data.memberIds.map((id) => id.toString())])
    );

    if (uniqueMembers.length < 2) {
      return res.status(400).json({ error: 'A group must have at least 2 members' });
    }

    const group = await Group.create({
      name: parsed.data.name,
      description: parsed.data.description,
      members: uniqueMembers,
      admins: [creatorId],
      createdBy: creatorId,
    });

    await group.populate('members admins createdBy', '-password');
    res.status(201).json({ group });
  } catch (error) {
    console.error('Create group error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// List groups for current user
router.get('/', auth, async (req, res) => {
  try {
    const groups = await Group.find({ members: req.userId })
      .populate('members admins createdBy', '-password')
      .sort({ updatedAt: -1 });

    res.json({ groups });
  } catch (error) {
    console.error('List groups error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Add members (admin only)
router.post('/:id/members', auth, async (req, res) => {
  try {
    const parsed = updateMembersSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (!group.members.some((id) => id.toString() === req.userId.toString())) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!isAdmin(group, req.userId)) {
      return res.status(403).json({ error: 'Only admins can add members' });
    }

    const currentMembers = new Set(group.members.map((id) => id.toString()));
    for (const memberId of parsed.data.memberIds.map((id) => id.toString())) {
      currentMembers.add(memberId);
    }

    group.members = Array.from(currentMembers);
    await group.save();
    await group.populate('members admins createdBy', '-password');
    res.json({ group });
  } catch (error) {
    console.error('Add group members error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Remove member (admin only, or user can leave)
router.delete('/:id/members/:memberId', auth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const actorId = req.userId.toString();
    const memberId = req.params.memberId.toString();
    const actorIsAdmin = isAdmin(group, actorId);
    const isSelfLeave = actorId === memberId;

    if (!group.members.some((id) => id.toString() === actorId)) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!actorIsAdmin && !isSelfLeave) {
      return res.status(403).json({ error: 'Only admins can remove other members' });
    }

    group.members = group.members.filter((id) => id.toString() !== memberId);
    group.admins = group.admins.filter((id) => id.toString() !== memberId);

    if (!group.members.length) {
      await Group.findByIdAndDelete(group._id);
      return res.json({ deleted: true });
    }

    if (!group.admins.length) {
      group.admins = [group.members[0]];
    }

    await group.save();
    await group.populate('members admins createdBy', '-password');
    res.json({ group });
  } catch (error) {
    console.error('Remove group member error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Promote member to admin (admin only)
router.post('/:id/admins/:memberId', auth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (!group.members.some((id) => id.toString() === req.userId.toString())) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!isAdmin(group, req.userId)) {
      return res.status(403).json({ error: 'Only admins can promote admins' });
    }

    const memberId = req.params.memberId.toString();
    if (!group.members.some((id) => id.toString() === memberId)) {
      return res.status(400).json({ error: 'User is not a member of this group' });
    }

    if (!group.admins.some((id) => id.toString() === memberId)) {
      group.admins.push(memberId);
      await group.save();
    }

    await group.populate('members admins createdBy', '-password');
    res.json({ group });
  } catch (error) {
    console.error('Promote group admin error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Demote admin (admin only, cannot remove last admin)
router.delete('/:id/admins/:memberId', auth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if (!group.members.some((id) => id.toString() === req.userId.toString())) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!isAdmin(group, req.userId)) {
      return res.status(403).json({ error: 'Only admins can demote admins' });
    }

    const memberId = req.params.memberId.toString();
    group.admins = group.admins.filter((id) => id.toString() !== memberId);

    if (!group.admins.length) {
      return res.status(400).json({ error: 'Group must have at least one admin' });
    }

    await group.save();
    await group.populate('members admins createdBy', '-password');
    res.json({ group });
  } catch (error) {
    console.error('Demote group admin error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
