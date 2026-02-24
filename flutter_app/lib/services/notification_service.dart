import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Incoming chat message notifications',
    importance: Importance.high,
  );

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _localInitialized = false;

  Future<void> initializeForUser(String userId) async {
    if (userId.isEmpty) return;

    await _requestPermission();
    await _initLocalNotifications();
    await _saveCurrentToken(userId);
    _listenTokenRefresh(userId);
    _listenForegroundMessages();
  }

  Future<void> clearForLogout() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _local.initialize(settings);

    final androidImplementation = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_channel);

    _localInitialized = true;
  }

  Future<void> _saveCurrentToken(String userId) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    debugPrint('FCM token: $token');
    await _upsertToken(userId, token.trim());
  }

  void _listenTokenRefresh(String userId) {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      if (token.trim().isEmpty) return;
      await _upsertToken(userId, token.trim());
    });
  }

  void _listenForegroundMessages() {
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ?? 'New message';
      final body = message.notification?.body ?? '';
      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Incoming chat message notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> _upsertToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handling hook for FCM; app-level behavior can be extended later.
}
