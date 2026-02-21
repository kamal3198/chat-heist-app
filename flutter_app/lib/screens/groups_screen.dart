import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/group_provider.dart';
import 'voice_call_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).loadGroups();
    });
  }

  Future<void> _openManageDialog(Group group) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';
    final isAdmin = group.admins.any((admin) => admin.id == currentUserId);
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only group admins can manage members')),
      );
      return;
    }

    final memberIds = group.members.map((member) => member.id).toSet();
    final candidates = contactProvider.contacts.where((user) => !memberIds.contains(user.id)).toList();
    final selectedIds = <String>{};

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Manage ${group.name}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Add Members', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    if (candidates.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No contacts left to add'),
                      ),
                    if (candidates.isNotEmpty)
                      SizedBox(
                        height: 180,
                        child: ListView(
                          children: candidates.map((user) {
                            final checked = selectedIds.contains(user.id);
                            return CheckboxListTile(
                              dense: true,
                              title: Text(user.username),
                              value: checked,
                              onChanged: (_) {
                                setState(() {
                                  if (checked) {
                                    selectedIds.remove(user.id);
                                  } else {
                                    selectedIds.add(user.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(context, true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || selectedIds.isEmpty || !mounted) return;

    final success = await groupProvider.addMembers(
      groupId: group.id,
      memberIds: selectedIds.toList(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Members added' : (groupProvider.error ?? 'Failed to add members'))),
    );
  }

  Future<void> _onMemberAction({
    required Group group,
    required User member,
    required String action,
  }) async {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';
    final isCurrentAdmin = group.admins.any((admin) => admin.id == currentUserId);

    if (!isCurrentAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can perform this action')),
      );
      return;
    }

    bool success = false;
    if (action == 'remove') {
      success = await groupProvider.removeMember(groupId: group.id, memberId: member.id);
    } else if (action == 'promote') {
      success = await groupProvider.promoteAdmin(groupId: group.id, memberId: member.id);
    } else if (action == 'demote') {
      success = await groupProvider.demoteAdmin(groupId: group.id, memberId: member.id);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Group updated' : (groupProvider.error ?? 'Action failed'))),
    );
  }

  Future<void> _openMembersDialog(Group group) async {
    final adminIds = group.admins.map((user) => user.id).toSet();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${group.name} Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: group.members.length,
              itemBuilder: (context, index) {
                final member = group.members[index];
                final isAdmin = adminIds.contains(member.id);
                final isSelf = member.id == currentUserId;

                return ListTile(
                  title: Text(member.username),
                  subtitle: Text(isAdmin ? 'Admin' : 'Member'),
                  trailing: isSelf
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            Navigator.pop(context);
                            _onMemberAction(group: group, member: member, action: value);
                          },
                          itemBuilder: (context) => [
                            if (!isAdmin)
                              const PopupMenuItem(value: 'promote', child: Text('Make admin')),
                            if (isAdmin)
                              const PopupMenuItem(value: 'demote', child: Text('Remove admin')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove member')),
                          ],
                        ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, _) {
        if (groupProvider.isLoading && groupProvider.groups.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (groupProvider.groups.isEmpty) {
          return Center(
            child: Text(
              'No groups yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          itemCount: groupProvider.groups.length,
          itemBuilder: (context, index) {
            final group = groupProvider.groups[index];
            return ListTile(
              onTap: () => _openMembersDialog(group),
              leading: CircleAvatar(
                child: Text(
                  group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                ),
              ),
              title: Text(group.name),
              subtitle: Text('${group.members.length} members | ${group.admins.length} admins'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Manage group',
                    icon: const Icon(Icons.manage_accounts, color: Colors.blueGrey),
                    onPressed: () => _openManageDialog(group),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.teal),
                    onPressed: () async {
                      final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
                      final callTargets = group.members
                          .where((member) => member.id != currentUserId)
                          .map((member) => member.id)
                          .toList();
                      if (callTargets.isEmpty) return;

                      final callProvider = Provider.of<CallProvider>(context, listen: false);
                      final started = await callProvider.startCall(
                        context: context,
                        participantIds: callTargets,
                      );
                      if (!mounted) return;
                      if (started != null) {
                        final participants = group.members.where((member) => member.id != currentUserId).toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VoiceCallScreen(
                              title: group.name,
                              isGroup: true,
                              participants: participants,
                              onEndCall: () => callProvider.endCall(),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              callProvider.error ?? 'Unable to start call',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
