import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/chat_model.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
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
    final authProvider = context.read<AuthProvider>();
    final contactProvider = context.read<ContactProvider>();
    if (authProvider.currentUser != null) {
      await contactProvider.loadContacts();
    }
  }

  Future<void> _refresh() => _loadData();

  User _resolveContact(
    String contactId,
    List<User> contacts,
    DateTime now,
  ) {
    for (final contact in contacts) {
      if (contact.id == contactId) return contact;
    }
    return User(
      id: contactId,
      username: 'User',
      avatar: '',
      createdAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final currentUser = authProvider.currentUser;
    final currentUserId = currentUser?.id ?? '';
    final now = DateTime.now();

    if (currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.chatSnapshots(currentUserId),
        builder: (context, chatsSnapshot) {
          if (chatsSnapshot.connectionState == ConnectionState.waiting &&
              !chatsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chatDocs = chatsSnapshot.data?.docs ?? const [];
          final chats = chatDocs.map(ChatModel.fromDoc).toList();

          if (chats.isEmpty) {
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
                      const SizedBox(height: 180),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final contactId = chat.participants
                    .where((id) => id != currentUserId)
                    .firstOrNull;

                if (contactId == null) return const SizedBox.shrink();
                final contact = _resolveContact(contactId, contactProvider.contacts, now);
                final chatId = _chatService.conversationId(currentUserId, contactId);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatService.unseenMessageSnapshots(
                    chatId: chatId,
                    currentUserId: currentUserId,
                  ),
                  builder: (context, unreadSnapshot) {
                    final unreadCount = unreadSnapshot.data?.docs.length ?? 0;
                    final hasUnread = unreadCount > 0;
                    final isLastFromMe = chat.lastSenderId == currentUserId;

                    return ListTile(
                      leading: UserAvatar(
                        user: contact,
                        radius: 28,
                        showOnlineIndicator: true,
                      ),
                      title: Text(
                        contact.username,
                        style: TextStyle(
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          if (isLastFromMe)
                            Icon(
                              Icons.done_all,
                              size: 16,
                              color: hasUnread
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                          if (isLastFromMe) const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              chat.lastMessage.isEmpty ? 'Start chatting' : chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatMessageTime(chat.lastTimestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year && local.month == now.month && local.day == now.day;

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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
