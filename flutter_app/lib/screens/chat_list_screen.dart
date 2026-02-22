import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/message_provider.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      await _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await contactProvider.loadContacts();
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id ?? '';

    return Scaffold(
      body: Consumer2<ContactProvider, MessageProvider>(
        builder: (context, contactProvider, messageProvider, child) {
          if (contactProvider.isLoading && contactProvider.contacts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = contactProvider.contacts;
          
          // Filter contacts that have messages
          final contactsWithMessages = contacts.where((contact) {
            final lastMessage = messageProvider.getLastMessage(contact.id);
            return lastMessage != null;
          }).toList();

          // Sort by last message time
          contactsWithMessages.sort((a, b) {
            final aMsg = messageProvider.getLastMessage(a.id);
            final bMsg = messageProvider.getLastMessage(b.id);
            if (aMsg == null || bMsg == null) return 0;
            return bMsg.timestamp.compareTo(aMsg.timestamp);
          });

          if (contactsWithMessages.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with your contacts',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 200), // For pull to refresh
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: contactsWithMessages.length,
              itemBuilder: (context, index) {
                final contact = contactsWithMessages[index];
                final lastMessage = messageProvider.getLastMessage(contact.id);
                final unreadCount = messageProvider.getUnreadCount(
                  contact.id,
                  currentUserId,
                );

                return ListTile(
                  leading: UserAvatar(
                    user: contact,
                    radius: 28,
                    showOnlineIndicator: true,
                  ),
                  title: Text(
                    contact.username,
                    style: TextStyle(
                      fontWeight: unreadCount > 0 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: lastMessage != null
                      ? Row(
                          children: [
                            if (lastMessage.sender.id == currentUserId) ...[
                              Icon(
                                _getStatusIcon(lastMessage.status),
                                size: 16,
                                color: lastMessage.status == 'read'
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                lastMessage.hasFile
                                    ? lastMessage.isImage
                                        ? 'Photo'
                                        : 'File: ${lastMessage.fileName}'
                                    : lastMessage.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (lastMessage != null)
                        Text(
                          _formatMessageTime(lastMessage.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: unreadCount > 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
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
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      default:
        return Icons.schedule;
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    if (isToday) {
      return DateFormat('h:mm a').format(local);
    }

    final difference = now.difference(local);
    if (difference.inDays < 7) {
      return timeago.format(local, locale: 'en_short');
    }

    return DateFormat('dd/MM/yy').format(local);
  }
}
