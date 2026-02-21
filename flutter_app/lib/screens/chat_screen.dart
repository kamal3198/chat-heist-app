import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/message.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/message_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/user_avatar.dart';
import 'contact_profile_screen.dart';
import 'voice_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final User contact;

  const ChatScreen({
    super.key,
    required this.contact,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _typingTimer;

  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _showStickerPicker = false;
  final Set<String> _selectedMessageIds = {};
  final List<String> _customStickers = [];

  final List<String> _emojis = const [
    '\u{1F970}', '\u{1F60D}', '\u{1F60A}', '\u{1F618}', '\u{1F496}', '\u{1F49E}',
    '\u{1F44D}', '\u{1F44F}', '\u{1F64F}', '\u{1F525}', '\u{1F389}', '\u{1F31F}',
    '\u{1F60E}', '\u{1F973}', '\u{1F63A}', '\u{1F49B}', '\u{1F49C}', '\u{1F499}',
    '\u{1F917}', '\u{1F92D}', '\u{1F61A}', '\u{1F60B}', '\u{1F923}', '\u{1F92A}',
  ];

  final List<String> _stickers = const [
    '[sticker] (???????)?',
    '[sticker] (?????)',
    '[sticker] ?•?•?',
    '[sticker] (????)?*:???',
    '[sticker] (•`?•´)? ??',
    '[sticker] (???)',
    '[sticker] ¯\\_(?)_/¯',
    '[sticker] (?\'`-\'´)?',
  ];

  String get _chatWallpaperKey => 'user:${widget.contact.id}';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _selectionMode => _selectedMessageIds.isNotEmpty;

  void _loadMessages() {
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);
    messageProvider.setActiveConversation(widget.contact.id);
    messageProvider.loadMessages(widget.contact.id);
  }

  void _onTextChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);

    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      messageProvider.sendTyping(
        authProvider.currentUser!.id,
        widget.contact.id,
        true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        messageProvider.sendTyping(
          authProvider.currentUser!.id,
          widget.contact.id,
          false,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);

    messageProvider.sendMessage(
      senderId: authProvider.currentUser!.id,
      receiverId: widget.contact.id,
      text: text,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _sendSticker(String sticker) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);

    messageProvider.sendMessage(
      senderId: authProvider.currentUser!.id,
      receiverId: widget.contact.id,
      text: sticker,
    );
    _scrollToBottom();
  }

  Future<void> _createSticker() async {
    final controller = TextEditingController();
    final sticker = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Sticker'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: 'Enter cute text or emoji art',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (sticker != null && sticker.isNotEmpty) {
      setState(() {
        _customStickers.insert(0, '[sticker] $sticker');
      });
    }
  }

  void _toggleEmojiPicker() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) _showStickerPicker = false;
    });
  }

  void _toggleStickerPicker() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showStickerPicker = !_showStickerPicker;
      if (_showStickerPicker) _showEmojiPicker = false;
    });
  }

  void _appendEmoji(String emoji) {
    _messageController.text = '${_messageController.text}$emoji';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _toggleMessageSelection(Message message) {
    if (message.id.isEmpty) return;
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: Text('Delete ${_selectedMessageIds.length} selected messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final messageProvider = Provider.of<MessageProvider>(context, listen: false);
    final success = await messageProvider.deleteMessages(
      contactId: widget.contact.id,
      messageIds: _selectedMessageIds.toList(),
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedMessageIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageProvider.error ?? 'Delete failed')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image == null) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);
      final bytes = await image.readAsBytes();

      await messageProvider.sendFileBytesMessage(
        senderId: authProvider.currentUser!.id,
        receiverId: widget.contact.id,
        bytes: bytes,
        fileName: image.name,
        mimeType: lookupMimeType(image.name),
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);

      if (picked.bytes != null) {
        await messageProvider.sendFileBytesMessage(
          senderId: authProvider.currentUser!.id,
          receiverId: widget.contact.id,
          bytes: picked.bytes!,
          fileName: picked.name,
          mimeType: lookupMimeType(picked.name),
        );
      } else if (picked.path != null) {
        await messageProvider.sendFileMessage(
          senderId: authProvider.currentUser!.id,
          receiverId: widget.contact.id,
          file: File(picked.path!),
        );
      } else {
        throw Exception('Unsupported file data');
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send file: $e')),
        );
      }
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
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
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

  Future<void> _pickCustomChatWallpaper() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final settings = Provider.of<ChatSettingsProvider>(context, listen: false);
    await settings.setChatCustomWallpaperBytes(_chatWallpaperKey, bytes);
  }

  void _showChatWallpaperPicker() {
    final settings = Provider.of<ChatSettingsProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chat Wallpaper',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...ChatSettingsProvider.availableWallpapers.map((wallpaper) {
                    final selected =
                        settings.wallpaperForChat(_chatWallpaperKey) == wallpaper;
                    return InkWell(
                      onTap: () async {
                        if (wallpaper == 'custom') {
                          await _pickCustomChatWallpaper();
                        } else {
                          await settings.setChatWallpaper(_chatWallpaperKey, wallpaper);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 86,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                          color:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 50,
                              decoration: settings
                                  .wallpaperPreviewDecoration(wallpaper)
                                  .copyWith(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                              child: wallpaper == 'custom'
                                  ? const Center(
                                      child: Icon(Icons.photo_library_outlined),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _wallpaperLabel(wallpaper),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await settings.clearChatWallpaper(_chatWallpaperKey);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Use global'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _wallpaperLabel(String wallpaper) {
    switch (wallpaper) {
      case 'mint':
        return 'Mint';
      case 'ocean':
        return 'Ocean';
      case 'sunset':
        return 'Sunset';
      case 'dusk':
        return 'Dusk';
      case 'midnight':
        return 'Midnight';
      case 'custom':
        return 'Custom';
      default:
        return 'Default';
    }
  }

  void _showContactMenu() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactProfileScreen(user: widget.contact),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('Chat Wallpaper'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showChatWallpaperPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final contactProvider = Provider.of<ContactProvider>(context, listen: false);
                final success = await contactProvider.blockUser(widget.contact.id);
                if (!mounted) return;
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(contactProvider.error ?? 'Failed to block user')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.orange),
              title: const Text('Remove Contact'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final contactProvider = Provider.of<ContactProvider>(context, listen: false);
                final success = await contactProvider.removeContact(widget.contact.id);
                if (!mounted) return;
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact removed')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(contactProvider.error ?? 'Failed to remove contact')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedMessageIds.clear();
                  });
                },
              )
            : null,
        titleSpacing: 0,
        title: _selectionMode
            ? Text('${_selectedMessageIds.length} selected')
            : InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactProfileScreen(user: widget.contact),
                    ),
                  );
                },
                child: Row(
                  children: [
                    UserAvatar(
                      user: widget.contact,
                      radius: 20,
                      showOnlineIndicator: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.contact.username,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            widget.contact.isOnline
                                ? 'Online'
                                : widget.contact.lastSeen != null
                                    ? 'Last seen ${timeago.format(widget.contact.lastSeen!)}'
                                    : 'Offline',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelectedMessages,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () async {
                final callProvider =
                    Provider.of<CallProvider>(context, listen: false);
                final started = await callProvider.startCall(
                  context: context,
                  participantIds: [widget.contact.id],
                );
                if (!mounted) return;
                if (started != null) {
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
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showContactMenu,
            ),
          ]
        ],
      ),
      body: Consumer<ChatSettingsProvider>(
        builder: (context, chatSettings, _) => Container(
          decoration: chatSettings.buildWallpaperDecoration(
            Theme.of(context),
            chatKey: _chatWallpaperKey,
          ),
          child: Column(
            children: [
          Expanded(
            child: Consumer<MessageProvider>(
              builder: (context, messageProvider, child) {
                final messages = messageProvider.getConversation(widget.contact.id);

                if (messageProvider.isLoading && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with ${widget.contact.username}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSentByMe = message.sender.id == currentUserId;
                    return MessageBubble(
                      message: message,
                      isSentByMe: isSentByMe,
                      isSelected: _selectedMessageIds.contains(message.id),
                      onLongPress: () => _toggleMessageSelection(message),
                      onTap: _selectionMode ? () => _toggleMessageSelection(message) : null,
                    );
                  },
                );
              },
            ),
          ),
          Consumer<MessageProvider>(
            builder: (context, messageProvider, child) {
              if (messageProvider.isTyping(widget.contact.id)) {
                return TypingIndicator(username: widget.contact.username);
              }
              return const SizedBox.shrink();
            },
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
                  ),
                  onPressed: _toggleEmojiPicker,
                ),
                IconButton(
                  icon: Icon(
                    _showStickerPicker ? Icons.keyboard_alt_outlined : Icons.auto_awesome,
                  ),
                  onPressed: _toggleStickerPicker,
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onTap: () {
                      if (_showEmojiPicker || _showStickerPicker) {
                        setState(() {
                          _showEmojiPicker = false;
                          _showStickerPicker = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _showEmojiPicker ? 220 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _showEmojiPicker
                ? GridView.builder(
                    itemCount: _emojis.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () => _appendEmoji(_emojis[index]),
                        child: Center(
                          child: Text(
                            _emojis[index],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _showStickerPicker ? 220 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _showStickerPicker
                ? Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Stickers',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _createSticker,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Create'),
                          ),
                        ],
                      ),
                      Expanded(
                        child: GridView.builder(
                          itemCount: _customStickers.length + _stickers.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final sticker = index < _customStickers.length
                                ? _customStickers[index]
                                : _stickers[index - _customStickers.length];
                            return OutlinedButton(
                              onPressed: () => _sendSticker(sticker),
                              child: Text(
                                sticker.replaceFirst('[sticker]', '').trim(),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ],
      ),
        ),
      ),
    );
  }
}

