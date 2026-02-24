import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/message_model.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/message_provider.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/user_avatar.dart';
import 'contact_profile_screen.dart';
import 'voice_call_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.contact});

  final User contact;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _pageSize = 30;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final ChatService _chatService = ChatService();
  final Set<String> _selectedMessageIds = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _liveMessagesSub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _liveMessageDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderMessageDocs = [];

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _boundChatId;

  final List<String> _emojis = const [
    '\u{1F970}',
    '\u{1F60D}',
    '\u{1F60A}',
    '\u{1F618}',
    '\u{1F496}',
    '\u{1F44D}',
    '\u{1F44F}',
    '\u{1F64F}',
    '\u{1F525}',
    '\u{1F389}',
    '\u{1F31F}',
    '\u{1F923}',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MessageProvider>();
      provider.setActiveConversation(widget.contact.id);
      provider.markMessagesAsRead(widget.contact.id);
    });
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindLiveMessagesIfNeeded();
  }

  @override
  void dispose() {
    _liveMessagesSub?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _selectionMode => _selectedMessageIds.isNotEmpty;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _combinedDocs {
    final seen = <String>{};
    final combined = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in [..._liveMessageDocs, ..._olderMessageDocs]) {
      if (seen.contains(doc.id)) continue;
      seen.add(doc.id);
      combined.add(doc);
    }
    return combined;
  }

  void _bindLiveMessagesIfNeeded() {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;

    final chatId = _chatService.conversationId(me.id, widget.contact.id);
    if (_boundChatId == chatId) return;

    _boundChatId = chatId;
    _liveMessagesSub?.cancel();

    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _liveMessageDocs = [];
      _olderMessageDocs = [];
    });

    _liveMessagesSub = _chatService
        .messageSnapshots(chatId, limit: _pageSize)
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _liveMessageDocs = snapshot.docs;
        _isInitialLoading = false;
        if (_combinedDocs.length < _pageSize) {
          _hasMore = false;
        }
      });

      if (snapshot.docs.isNotEmpty) {
        context.read<MessageProvider>().markMessagesAsRead(widget.contact.id);
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _boundChatId == null) return;
    final currentDocs = _combinedDocs;
    if (currentDocs.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final older = await _chatService.fetchOlderMessages(
        chatId: _boundChatId!,
        startAfter: currentDocs.last,
        limit: _pageSize,
      );

      if (!mounted) return;

      final existingIds = _combinedDocs.map((doc) => doc.id).toSet();
      final newDocs = older.docs.where((doc) => !existingIds.contains(doc.id)).toList();

      setState(() {
        _olderMessageDocs = [..._olderMessageDocs, ...newDocs];
        _isLoadingMore = false;
        if (older.docs.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMoreMessages();
    }
  }

  void _onTextChanged() {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;
    final provider = context.read<MessageProvider>();

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      provider.sendTyping(me.id, widget.contact.id, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        provider.sendTyping(me.id, widget.contact.id, false);
      }
    });
  }

  void _appendEmoji(String emoji) {
    _messageController.text = '${_messageController.text}$emoji';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    final me = context.read<AuthProvider>().currentUser;
    if (me == null || text.isEmpty) return;

    context.read<MessageProvider>().sendMessage(
          senderId: me.id,
          receiverId: widget.contact.id,
          text: text,
          senderName: me.username,
        );

    _messageController.clear();
    _scrollToLatest();
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;

    final image = await _imagePicker.pickImage(source: source);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    await context.read<MessageProvider>().sendFileBytesMessage(
          senderId: me.id,
          receiverId: widget.contact.id,
          bytes: bytes,
          fileName: image.name,
          mimeType: lookupMimeType(image.name),
          senderName: me.username,
        );
  }

  Future<void> _pickFile() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;

    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final provider = context.read<MessageProvider>();

    if (picked.bytes != null) {
      await provider.sendFileBytesMessage(
        senderId: me.id,
        receiverId: widget.contact.id,
        bytes: picked.bytes!,
        fileName: picked.name,
        mimeType: lookupMimeType(picked.name),
        senderName: me.username,
      );
    } else if (picked.path != null) {
      await provider.sendFileMessage(
        senderId: me.id,
        receiverId: widget.contact.id,
        file: File(picked.path!),
        senderName: me.username,
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedMessages(String contactId) async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;
    final chatId = _chatService.conversationId(me.id, contactId);
    final chatSnap =
        await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    final retention =
        ((chatSnap.data()?['retentionPolicy'] as Map?) ?? const <String, dynamic>{});
    if (retention['enabled'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deletion is disabled by enterprise retention policy'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: Text('Delete ${_selectedMessageIds.length} selected messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await context.read<MessageProvider>().deleteMessages(
          contactId: contactId,
          messageIds: _selectedMessageIds.toList(),
        );

    if (!mounted) return;
    if (success) {
      setState(() => _selectedMessageIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final currentUserId = me?.id ?? '';
    final combinedDocs = _combinedDocs;
    final messages = combinedDocs
        .map(MessageModel.fromDoc)
        .where((message) => !message.isDeletedFor(currentUserId))
        .toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedMessageIds.clear()),
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedMessageIds.length} selected')
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _chatService.userSnapshot(widget.contact.id),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() ?? {};
                  final isOnline = data['isOnline'] == true;
                  final ts = data['lastSeen'];
                  final lastSeen = ts is Timestamp ? ts.toDate() : widget.contact.lastSeen;

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactProfileScreen(user: widget.contact),
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          user: widget.contact.copyWith(
                            isOnline: isOnline,
                            lastSeen: lastSeen,
                          ),
                          radius: 20,
                          showOnlineIndicator: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.contact.username),
                              Text(
                                isOnline
                                    ? 'Online'
                                    : lastSeen != null
                                        ? 'Last seen ${timeago.format(lastSeen)}'
                                        : 'Offline',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        actions: [
          if (_selectionMode)
            IconButton(
              onPressed: () => _deleteSelectedMessages(widget.contact.id),
              icon: const Icon(Icons.delete_outline),
            )
          else
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: () async {
                final callProvider = context.read<CallProvider>();
                final started = await callProvider.startCall(
                  context: context,
                  participantIds: [widget.contact.id],
                );
                if (!mounted || started == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VoiceCallScreen(
                      title: widget.contact.username,
                      isGroup: false,
                      participants: [widget.contact],
                      onEndCall: () => callProvider.endCall(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isLoadingMore && index == messages.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final message = messages[index];
                          return MessageBubble(
                            message: message,
                            isSentByMe: message.senderId == currentUserId,
                            isSelected: _selectedMessageIds.contains(message.id),
                            onLongPress: () {
                              setState(() {
                                if (_selectedMessageIds.contains(message.id)) {
                                  _selectedMessageIds.remove(message.id);
                                } else {
                                  _selectedMessageIds.add(message.id);
                                }
                              });
                            },
                            onTap: _selectionMode
                                ? () {
                                    setState(() {
                                      if (_selectedMessageIds.contains(message.id)) {
                                        _selectedMessageIds.remove(message.id);
                                      } else {
                                        _selectedMessageIds.add(message.id);
                                      }
                                    });
                                  }
                                : null,
                          );
                        },
                      ),
          ),
          Consumer<MessageProvider>(
            builder: (context, provider, _) => provider.isTyping(widget.contact.id)
                ? TypingIndicator(username: widget.contact.username)
                : const SizedBox.shrink(),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showEmojiPicker = !_showEmojiPicker);
                    },
                    icon: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard_alt_outlined
                          : Icons.emoji_emotions_outlined,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: 'Type a message',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _showAttachmentOptions,
                            icon: const Icon(Icons.attach_file),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _showEmojiPicker ? 200 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _showEmojiPicker
                ? GridView.builder(
                    itemCount: _emojis.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                    ),
                    itemBuilder: (context, index) => InkWell(
                      onTap: () => _appendEmoji(_emojis[index]),
                      child: Center(
                        child: Text(
                          _emojis[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
