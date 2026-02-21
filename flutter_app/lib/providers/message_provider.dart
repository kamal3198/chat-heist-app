import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/message_service.dart';
import '../services/socket_service.dart';

class MessageProvider with ChangeNotifier {
  final MessageService _messageService = MessageService();
  final SocketService _socketService = SocketService();

  // Map of contactId -> List of messages
  final Map<String, List<Message>> _conversations = {};
  
  // Map of contactId -> typing status
  final Map<String, bool> _typingStatus = {};
  
  // Current active conversation
  String? _activeConversationId;
  bool _isLoading = false;
  String? _error;
  bool _listenersInitialized = false;

  List<Message> getConversation(String contactId) {
    return _conversations[contactId] ?? [];
  }

  bool isTyping(String contactId) {
    return _typingStatus[contactId] ?? false;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get activeConversationId => _activeConversationId;

  // Initialize message provider
  void initialize(String userId) {
    if (_listenersInitialized) return;
    _setupSocketListeners(userId);
    _listenersInitialized = true;
  }

  // Setup socket listeners
  void _setupSocketListeners(String userId) {
    // Listen for incoming messages
    _socketService.onReceiveMessage((message) {
      final contactId = message.sender.id;
      if (!_conversations.containsKey(contactId)) {
        _conversations[contactId] = [];
      }
      final exists =
          _conversations[contactId]!.any((m) => m.id == message.id);
      if (!exists) {
        _conversations[contactId]!.add(message);
      }
      
      // Auto-mark as read if this conversation is active
      if (_activeConversationId == contactId) {
        markMessagesAsRead(contactId);
      }
      
      notifyListeners();
    });

    // Listen for message sent confirmation
    _socketService.onMessageSent((message) {
      final contactId = message.receiver.id;
      if (_conversations.containsKey(contactId)) {
        int index = _conversations[contactId]!
            .indexWhere((m) => m.id == message.id);

        if (index == -1 && message.clientMessageId != null) {
          index = _conversations[contactId]!.indexWhere(
            (m) => m.clientMessageId == message.clientMessageId,
          );
        }

        if (index == -1) {
          _conversations[contactId]!.add(message);
        } else {
          _conversations[contactId]![index] = message;
        }
        notifyListeners();
      }
    });

    // Listen for typing indicators
    _socketService.onUserTyping((contactId, isTyping) {
      _typingStatus[contactId] = isTyping;
      notifyListeners();
    });

    // Listen for messages read
    _socketService.onMessagesRead((readBy) {
      // Update message status to read
      if (_conversations.containsKey(readBy)) {
        for (var i = 0; i < _conversations[readBy]!.length; i++) {
          if (_conversations[readBy]![i].status != 'read') {
            _conversations[readBy]![i] = _conversations[readBy]![i].copyWith(
              status: 'read',
            );
          }
        }
        notifyListeners();
      }
    });

    // Listen for online/offline status
    _socketService.onUserOnline((userId) {
      // Can be used to update UI if needed
    });

    _socketService.onUserOffline((userId, lastSeen) {
      // Can be used to update UI if needed
    });
  }

  // Set active conversation
  void setActiveConversation(String? contactId) {
    _activeConversationId = contactId;
    if (contactId != null) {
      markMessagesAsRead(contactId);
    }
    notifyListeners();
  }

  // Load messages for a conversation
  Future<void> loadMessages(String contactId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final messages = await _messageService.getMessages(contactId);
      _conversations[contactId] = messages;
      
      // Mark as read
      if (_activeConversationId == contactId) {
        await markMessagesAsRead(contactId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send text message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final clientMessageId =
        'local-${DateTime.now().microsecondsSinceEpoch}-$senderId';

    // Create optimistic message
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: User(
        id: senderId,
        username: '',
        avatar: '',
        createdAt: DateTime.now(),
      ),
      receiver: User(
        id: receiverId,
        username: '',
        avatar: '',
        createdAt: DateTime.now(),
      ),
      text: text,
      clientMessageId: clientMessageId,
      status: 'sent',
      timestamp: DateTime.now(),
    );

    // Add to UI immediately
    if (!_conversations.containsKey(receiverId)) {
      _conversations[receiverId] = [];
    }
    _conversations[receiverId]!.add(tempMessage);
    notifyListeners();

    // Send via socket
    _socketService.sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      clientMessageId: clientMessageId,
      text: text,
    );
  }

  // Send file message
  Future<void> sendFileMessage({
    required String senderId,
    required String receiverId,
    required File file,
  }) async {
    try {
      // Upload file first
      final fileData = await _messageService.uploadFile(file);
      
      if (fileData != null) {
        final clientMessageId =
            'local-${DateTime.now().microsecondsSinceEpoch}-$senderId';
        // Send message with file
        _socketService.sendMessage(
          senderId: senderId,
          receiverId: receiverId,
          clientMessageId: clientMessageId,
          text: '',
          fileUrl: fileData['fileUrl'],
          fileName: fileData['fileName'],
          fileType: fileData['fileType'],
        );
      } else {
        _error = 'Failed to upload file';
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendFileBytesMessage({
    required String senderId,
    required String receiverId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final fileData = await _messageService.uploadFileBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );

      if (fileData != null) {
        final clientMessageId =
            'local-${DateTime.now().microsecondsSinceEpoch}-$senderId';
        _socketService.sendMessage(
          senderId: senderId,
          receiverId: receiverId,
          clientMessageId: clientMessageId,
          text: '',
          fileUrl: fileData['fileUrl'],
          fileName: fileData['fileName'],
          fileType: fileData['fileType'],
        );
      } else {
        _error = 'Failed to upload file';
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Send typing indicator
  void sendTyping(String senderId, String receiverId, bool isTyping) {
    _socketService.sendTyping(
      senderId: senderId,
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String contactId) async {
    try {
      await _messageService.markMessagesAsRead(contactId);
      
      // Update local messages
      if (_conversations.containsKey(contactId)) {
        for (var i = 0; i < _conversations[contactId]!.length; i++) {
          if (_conversations[contactId]![i].status != 'read') {
            _conversations[contactId]![i] = _conversations[contactId]![i].copyWith(
              status: 'read',
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deleteMessages({
    required String contactId,
    required List<String> messageIds,
  }) async {
    final success = await _messageService.deleteMessages(messageIds);
    if (!success) {
      _error = 'Failed to delete messages';
      notifyListeners();
      return false;
    }

    if (_conversations.containsKey(contactId)) {
      _conversations[contactId] = _conversations[contactId]!
          .where((m) => !messageIds.contains(m.id))
          .toList();
      notifyListeners();
    }
    return true;
  }

  // Get last message for a contact
  Message? getLastMessage(String contactId) {
    final messages = _conversations[contactId];
    if (messages == null || messages.isEmpty) return null;
    return messages.last;
  }

  // Get unread count for a contact
  int getUnreadCount(String contactId, String currentUserId) {
    final messages = _conversations[contactId];
    if (messages == null) return 0;
    
    return messages.where((m) => 
      m.sender.id != currentUserId && m.status != 'read'
    ).length;
  }

  // Get all conversations with last message
  List<String> getConversationIds() {
    return _conversations.keys.toList();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear conversation
  void clearConversation(String contactId) {
    _conversations.remove(contactId);
    notifyListeners();
  }

  @override
  void dispose() {
    _conversations.clear();
    _typingStatus.clear();
    super.dispose();
  }
}
