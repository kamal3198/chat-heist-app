import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../providers/group_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedMemberIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.length < 2 || _selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter group name and select at least one member'),
        ),
      );
      return;
    }

    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final success = await groupProvider.createGroup(
      name: name,
      description: _descriptionController.text.trim(),
      memberIds: _selectedMemberIds.toList(),
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(groupProvider.error ?? 'Failed to create group')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = Provider.of<ContactProvider>(context).contacts;
    final groupProvider = Provider.of<GroupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: groupProvider.isLoading ? null : _createGroup,
            child: const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final selected = _selectedMemberIds.contains(contact.id);

                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) {
                    setState(() {
                      if (selected) {
                        _selectedMemberIds.remove(contact.id);
                      } else {
                        _selectedMemberIds.add(contact.id);
                      }
                    });
                  },
                  title: Text(contact.username),
                  subtitle: Text(contact.isOnline ? 'Online' : 'Offline'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
