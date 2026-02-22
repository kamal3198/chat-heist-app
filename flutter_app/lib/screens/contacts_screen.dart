import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/call_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'search_users_screen.dart';
import 'requests_screen.dart';
import 'voice_call_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      await _loadContacts();
    });
  }

  Future<void> _loadContacts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await contactProvider.initialize(authProvider.currentUser!.id);
    }
  }

  Future<void> _refresh() async {
    await _loadContacts();
  }

  Future<void> _startOneToOneCall(User contact) async {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final started = await callProvider.startCall(
      context: context,
      participantIds: [contact.id],
    );
    if (!mounted) return;
    if (started != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceCallScreen(
            title: contact.username,
            isGroup: false,
            participants: [contact],
            onEndCall: () => callProvider.endCall(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(callProvider.error ?? 'Unable to start call')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, child) {
          if (contactProvider.isLoading && contactProvider.contacts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = contactProvider.contacts;
          final pendingRequestsCount = contactProvider.pendingRequests.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                // Pending requests banner
                if (pendingRequestsCount > 0)
                  Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RequestsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$pendingRequestsCount pending contact ${pendingRequestsCount == 1 ? "request" : "requests"}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Contacts list
                Expanded(
                  child: contacts.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No contacts yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to add contacts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 200), // For pull to refresh
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            
                            return ListTile(
                              leading: UserAvatar(
                                user: contact,
                                radius: 28,
                                showOnlineIndicator: true,
                              ),
                              title: Text(contact.username),
                              subtitle: Text(
                                contact.isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: contact.isOnline
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'call',
                                    child: Row(
                                      children: [
                                        Icon(Icons.call, color: Colors.teal),
                                        SizedBox(width: 8),
                                        Text('Voice Call'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'block',
                                    child: Row(
                                      children: [
                                        Icon(Icons.block, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Block'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Text('Remove'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) async {
                                  if (value == 'call') {
                                    await _startOneToOneCall(contact);
                                  } else if (value == 'block') {
                                    final success = await contactProvider.blockUser(contact.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success 
                                                ? 'Contact blocked' 
                                                : contactProvider.error ?? 'Failed to block',
                                          ),
                                        ),
                                      );
                                    }
                                  } else if (value == 'remove') {
                                    final success = await contactProvider.removeContact(contact.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success 
                                                ? 'Contact removed' 
                                                : contactProvider.error ?? 'Failed to remove',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(contact: contact),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Add Contact'),
                    onTap: () => Navigator.pop(context, 'add_contact'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_add),
                    title: const Text('Create Group'),
                    onTap: () => Navigator.pop(context, 'create_group'),
                  ),
                ],
              ),
            ),
          );

          if (!mounted || action == null) return;

          if (action == 'add_contact') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchUsersScreen(),
              ),
            );
          } else if (action == 'create_group') {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateGroupScreen(),
              ),
            );
            if (created == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group created successfully')),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
