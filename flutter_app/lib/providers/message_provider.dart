import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/message_service.dart';
import '../services/socket_service.dart';

class MessageProvider with ChangeNotifier {
  MessageProvider({
    ChatService? chatService,
    MessageService? messageService,
    SocketService? socketService,
  })  : _chatService = chatService ?? ChatService(),
        _messageService = messageService ?? MessageService(),
        _socketService = socketService ?? SocketService();

  final ChatService _chatService;
  final MessageService _messageService;
  final SocketService _socketService;

  final Map<String, List<MessageModel>> _conversations = {};
  final Map<String, StreamSubscription<List<MessageModel>>> _conversationSubs = {};
  final Map<String, bool> _typingStatus = {};

  StreamSubscription<List<ChatModel>>? _chatSub;
  List<ChatModel> _chats = [];

  String? _activeConversationId;
  bool _isLoading = false;
  String? _error;
  bool _socketListenersBound = false;
  String? _initializedForUserId;
  User? _currentUser;

  List<MessageModel> getConversation(String contactId) {
    return _conversations[contactId] ?? const [];
  }

  List<ChatModel> get chats => _chats;
  bool isTyping(String contactId) => _typingStatus[contactId] ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get activeConversationId => _activeConversationId;

  Future<void> initialize(User currentUser) async {
    if (_initializedForUserId == currentUser.id) return;

    _initializedForUserId = currentUser.id;
    _currentUser = currentUser;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _chatService.ensureUserProfile(currentUser);
      await _chatService.setUserOnlineStatus(currentUser.id, true);

      await _chatSub?.cancel();
      _chatSub = _chatService.streamUserChats(currentUser.id).listen(
        (value) {
          _chats = value;
          notifyListeners();
        },
        onError: (Object e) {
          _error = e.toString();
          notifyListeners();
        },
      );

      if (!_socketListenersBound) {
        _setupSocketListeners();
        _socketListenersBound = true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupSocketListeners() {
    _socketService.onUserTyping((contactId, isTyping) {
      _typingStatus[contactId] = isTyping;
      notifyListeners();
    });
  }

  void setActiveConversation(String? contactId) {
    _activeConversationId = contactId;
    if (contactId != null) {
      markMessagesAsRead(contactId);
    }
    notifyListeners();
  }

  Future<void> loadMessages(String contactId) async {
    final me = _currentUser;
    if (me == null) return;

    _conversationSubs[contactId]?.cancel();
    _conversationSubs[contactId] = _chatService
        .streamMessages(_chatService.conversationId(me.id, contactId))
        .listen(
      (messages) {
        _conversations[contactId] = messages;
        if (_activeConversationId == contactId) {
          unawaited(markMessagesAsRead(contactId));
        }
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? senderName,
  }) async {
    try {
      await _chatService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        type: 'text',
        senderName: senderName,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendFileMessage({
    required String senderId,
    required String receiverId,
    required File file,
    String? senderName,
  }) async {
    final uploaded = await _messageService.uploadFile(file);
    if (uploaded == null) {
      _error = 'Failed to upload file';
      notifyListeners();
      return;
    }

    final fileUrl = (uploaded['fileUrl'] ?? '').toString();
    final fileType = (uploaded['fileType'] ?? '').toString();
    final type = fileType.startsWith('image/') ? 'image' : 'text';
    final payload = type == 'image'
        ? fileUrl
        : '[file] ${uploaded['fileName'] ?? 'attachment'} $fileUrl';

    await _chatService.sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: payload,
      type: type,
      senderName: senderName,
    );
  }

  Future<void> sendFileBytesMessage({
    required String senderId,
    required String receiverId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? senderName,
  }) async {
    final uploaded = await _messageService.uploadFileBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    if (uploaded == null) {
      _error = 'Failed to upload file';
      notifyListeners();
      return;
    }

    final fileUrl = (uploaded['fileUrl'] ?? '').toString();
    final fileType = (uploaded['fileType'] ?? '').toString();
    final type = fileType.startsWith('image/') ? 'image' : 'text';
    final payload =
        type == 'image' ? fileUrl : '[file] ${uploaded['fileName'] ?? fileName} $fileUrl';

    await _chatService.sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: payload,
      type: type,
      senderName: senderName,
    );
  }

  void sendTyping(String senderId, String receiverId, bool isTyping) {
    _socketService.sendTyping(
      senderId: senderId,
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  Future<void> markMessagesAsRead(String contactId) async {
    final me = _currentUser;
    if (me == null) return;
    try {
      await _chatService.markConversationSeen(
        currentUserId: me.id,
        contactId: contactId,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deleteMessages({
    required String contactId,
    required List<String> messageIds,
  }) async {
    final me = _currentUser;
    if (me == null) return false;
    try {
      await _chatService.deleteMessages(
        chatId: _chatService.conversationId(me.id, contactId),
        messageIds: messageIds,
        userId: me.id,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  MessageModel? getLastMessage(String contactId) {
    final me = _currentUser;
    if (me == null) return null;
    final chatId = _chatService.conversationId(me.id, contactId);
    final chat = _chats.where((item) => item.id == chatId).firstOrNull;
    if (chat == null || chat.lastMessage.isEmpty) return null;

    return MessageModel(
      id: '${chat.id}-last',
      senderId: chat.lastSenderId,
      receiverId: chat.lastSenderId == me.id ? contactId : me.id,
      text: chat.lastMessage,
      type: 'text',
      deliveryStatus: switch (chat.lastDeliveryStatus) {
        'seen' => DeliveryStatus.seen,
        _ => DeliveryStatus.sent,
      },
      sentAt: chat.lastTimestamp ?? DateTime.now(),
      seenAt: chat.lastDeliveryStatus == 'seen'
          ? chat.lastTimestamp ?? DateTime.now()
          : null,
      deletedFor: const [],
    );
  }

  int getUnreadCount(String contactId, String currentUserId) {
    final messages = _conversations[contactId];
    if (messages == null) return 0;
    return messages
        .where((m) =>
            m.senderId != currentUserId &&
            m.deliveryStatus != DeliveryStatus.seen &&
            !m.isDeletedFor(currentUserId))
        .length;
  }

  List<String> getConversationIds() => _conversations.keys.toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearConversation(String contactId) {
    _conversationSubs[contactId]?.cancel();
    _conversationSubs.remove(contactId);
    _conversations.remove(contactId);
    notifyListeners();
  }

  @override
  void dispose() {
    final currentId = _currentUser?.id;
    if (currentId != null) {
      unawaited(_chatService.setUserOnlineStatus(currentId, false));
    }
    for (final sub in _conversationSubs.values) {
      sub.cancel();
    }
    _conversationSubs.clear();
    _chatSub?.cancel();
    _conversations.clear();
    _typingStatus.clear();
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
