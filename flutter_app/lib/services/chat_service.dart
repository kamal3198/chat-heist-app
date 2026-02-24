import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/api_config.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user.dart';

class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  static String generateChatId(String uid1, String uid2) {
    final ids = [uid1.trim(), uid2.trim()]..sort();
    return ids.join('_');
  }

  String conversationId(String uid1, String uid2) => generateChatId(uid1, uid2);

  Future<void> ensureUserProfile(User user) async {
    final authUser = fb.FirebaseAuth.instance.currentUser;
    await _users.doc(user.id).set({
      'name': user.username,
      'email': authUser?.email ?? '',
      'photoURL': user.avatar,
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    }, SetOptions(merge: true));
  }

  // Keep presence updates infrequent for Spark usage.
  Future<void> setUserOnlineStatus(String userId, bool isOnline) async {
    await _users.doc(userId).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userSnapshot(String userId) {
    return _users.doc(userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> chatSnapshots(String userId) {
    return _chats
        .where('participants', arrayContains: userId)
        .orderBy('lastTimestamp', descending: true)
        .limit(30)
        .snapshots();
  }

  Stream<List<ChatModel>> streamUserChats(String userId) {
    return chatSnapshots(userId).map(
      (snapshot) => snapshot.docs.map(ChatModel.fromDoc).toList(),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messageSnapshots(
    String chatId, {
    int limit = 30,
  }) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<List<MessageModel>> streamMessages(String chatId) {
    return messageSnapshots(chatId).map(
      (snapshot) => snapshot.docs.map(MessageModel.fromDoc).toList(),
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchOlderMessages({
    required String chatId,
    required DocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = 30,
  }) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(startAfter)
        .limit(limit)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> unseenMessageSnapshots({
    required String chatId,
    required String currentUserId,
  }) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('deliveryStatus', isEqualTo: 'sent')
        .snapshots();
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? senderName,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;

    final chatId = generateChatId(senderId, receiverId);
    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final batch = _firestore.batch();
    batch.set(
      chatRef,
      {
        'participants': [senderId, receiverId]..sort(),
        'lastMessage': normalizedText,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'lastDeliveryStatus': 'sent',
        'retentionPolicy': {
          'enabled': false,
          'retainDays': 30,
        },
      },
      SetOptions(merge: true),
    );

    batch.set(
      messageRef,
      {
        'senderId': senderId,
        'receiverId': receiverId,
        'text': normalizedText,
        'deliveryStatus': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'seenAt': null,
        'deletedFor': <String>[],
        'type': type,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    await _sendPushToReceiver(
      receiverId: receiverId,
      senderId: senderId,
      senderName: senderName ?? 'New message',
      messageText: normalizedText,
      chatId: chatId,
    );
  }

  Future<void> markConversationSeen({
    required String currentUserId,
    required String contactId,
  }) async {
    final chatId = generateChatId(currentUserId, contactId);
    final sentMessages = await _chats
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('deliveryStatus', isEqualTo: 'sent')
        .limit(100)
        .get();

    if (sentMessages.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in sentMessages.docs) {
      batch.set(
        doc.reference,
        {
          'deliveryStatus': 'seen',
          'seenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    batch.set(
      _chats.doc(chatId),
      {'lastDeliveryStatus': 'seen'},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> deleteMessages({
    required String chatId,
    required List<String> messageIds,
    required String userId,
  }) async {
    if (messageIds.isEmpty) return;
    final chatRef = _chats.doc(chatId);
    final chatSnap = await chatRef.get();
    final chatData = chatSnap.data() ?? <String, dynamic>{};
    final retention = (chatData['retentionPolicy'] as Map?) ?? const {};
    if (retention['enabled'] == true) {
      throw Exception('Message deletion is disabled by retention policy');
    }

    final batch = _firestore.batch();
    for (final id in messageIds) {
      batch.set(
        chatRef.collection('messages').doc(id),
        {
          'deletedFor': FieldValue.arrayUnion([userId]),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> _sendPushToReceiver({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    if (ApiConfig.fcmServerKey.trim().isEmpty) {
      // For Spark MVP this remains client-side; move to secure backend dispatch when available.
      return;
    }

    final receiverSnap = await _users.doc(receiverId).get();
    final receiverData = receiverSnap.data() ?? <String, dynamic>{};
    final token = (receiverData['fcmToken'] ?? '').toString().trim();
    if (token.isEmpty) return;

    await http.post(
      Uri.parse(ApiConfig.fcmLegacySendEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=${ApiConfig.fcmServerKey}',
      },
      body: jsonEncode({
        'to': token,
        'notification': {
          'title': senderName,
          'body': messageText,
        },
        'data': {
          'chatId': chatId,
          'senderId': senderId,
        },
      }),
    );
  }
}
