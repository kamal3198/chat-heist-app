const express = require('express');
const { z } = require('zod');

const auth = require('../middleware/auth');
const {
  createGroup,
  getGroupById,
  updateGroup,
  deleteGroup,
  listGroupsForMember,
  populateByUserFields,
} = require('../services/store');

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
  return (group.admins || []).map(String).includes(String(userId));
}

router.post('/', auth, async (req, res) => {
  try {
    const parsed = createGroupSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const creatorId = String(req.userId);
    const uniqueMembers = Array.from(new Set([creatorId, ...parsed.data.memberIds.map(String)]));

    if (uniqueMembers.length < 2) {
      return res.status(400).json({ error: 'A group must have at least 2 members' });
    }

    const group = await createGroup({
      name: parsed.data.name,
      description: parsed.data.description,
      avatar: '',
      members: uniqueMembers,
      admins: [creatorId],
      createdBy: creatorId,
    });

    const populated = await populateByUserFields(group, ['members', 'admins', 'createdBy']);
    return res.status(201).json({ group: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const groups = await listGroupsForMember(req.userId);
    const populated = await populateByUserFields(groups, ['members', 'admins', 'createdBy']);
    return res.json({ groups: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/members', auth, async (req, res) => {
  try {
    const parsed = updateMembersSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
    }

    const group = await getGroupById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const actorId = String(req.userId);
    const members = (group.members || []).map(String);

    if (!members.includes(actorId)) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!isAdmin(group, actorId)) {
      return res.status(403).json({ error: 'Only admins can add members' });
    }

    const mergedMembers = Array.from(new Set([...members, ...parsed.data.memberIds.map(String)]));
    const updated = await updateGroup(group._id, { members: mergedMembers });
    const populated = await populateByUserFields(updated, ['members', 'admins', 'createdBy']);
    return res.json({ group: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/:id/members/:memberId', auth, async (req, res) => {
  try {
    const group = await getGroupById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const actorId = String(req.userId);
    const memberId = String(req.params.memberId);

    const members = (group.members || []).map(String);
    const admins = (group.admins || []).map(String);

    const actorIsAdmin = admins.includes(actorId);
    const isSelfLeave = actorId === memberId;

    if (!members.includes(actorId)) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!actorIsAdmin && !isSelfLeave) {
      return res.status(403).json({ error: 'Only admins can remove other members' });
    }

    const nextMembers = members.filter((id) => id !== memberId);
    const nextAdmins = admins.filter((id) => id !== memberId);

    if (!nextMembers.length) {
      await deleteGroup(group._id);
      return res.json({ deleted: true });
    }

    const finalAdmins = nextAdmins.length ? nextAdmins : [nextMembers[0]];
    const updated = await updateGroup(group._id, {
      members: nextMembers,
      admins: finalAdmins,
    });

    const populated = await populateByUserFields(updated, ['members', 'admins', 'createdBy']);
    return res.json({ group: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/admins/:memberId', auth, async (req, res) => {
  try {
    const group = await getGroupById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const actorId = String(req.userId);
    const memberId = String(req.params.memberId);

    const members = (group.members || []).map(String);
    const admins = (group.admins || []).map(String);

    if (!members.includes(actorId)) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!admins.includes(actorId)) {
      return res.status(403).json({ error: 'Only admins can promote admins' });
    }
    if (!members.includes(memberId)) {
      return res.status(400).json({ error: 'User is not a member of this group' });
    }

    if (!admins.includes(memberId)) {
      admins.push(memberId);
    }

    const updated = await updateGroup(group._id, { admins });
    const populated = await populateByUserFields(updated, ['members', 'admins', 'createdBy']);
    return res.json({ group: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/:id/admins/:memberId', auth, async (req, res) => {
  try {
    const group = await getGroupById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const actorId = String(req.userId);
    const memberId = String(req.params.memberId);

    const members = (group.members || []).map(String);
    const admins = (group.admins || []).map(String);

    if (!members.includes(actorId)) {
      return res.status(403).json({ error: 'Not a group member' });
    }
    if (!admins.includes(actorId)) {
      return res.status(403).json({ error: 'Only admins can demote admins' });
    }

    const nextAdmins = admins.filter((id) => id !== memberId);
    if (!nextAdmins.length) {
      return res.status(400).json({ error: 'Group must have at least one admin' });
    }

    const updated = await updateGroup(group._id, { admins: nextAdmins });
    const populated = await populateByUserFields(updated, ['members', 'admins', 'createdBy']);
    return res.json({ group: populated });
  } catch (error) {
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
