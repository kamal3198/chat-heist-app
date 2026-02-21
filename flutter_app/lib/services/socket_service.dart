import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../models/message.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void connect(String userId) {
    if (_socket != null && _isConnected) {
      return;
    }

    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(3000)
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      _socket!.emit('registerUser', userId);
    });

    _socket!.onReconnect((_) {
      _isConnected = true;
      _socket!.emit('registerUser', userId);
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void sendMessage({
    required String senderId,
    required String receiverId,
    String? clientMessageId,
    String? text,
    String? fileUrl,
    String? fileName,
    String? fileType,
  }) {
    if (!_isConnected) return;

    _socket!.emit('sendMessage', {
      'senderId': senderId,
      'receiverId': receiverId,
      'clientMessageId': clientMessageId,
      'text': text ?? '',
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
    });
  }

  void sendTyping({
    required String senderId,
    required String receiverId,
    required bool isTyping,
  }) {
    if (!_isConnected) return;

    _socket!.emit('typing', {
      'senderId': senderId,
      'receiverId': receiverId,
      'isTyping': isTyping,
    });
  }

  void markAsRead({
    required String userId,
    required String contactId,
  }) {
    if (!_isConnected) return;

    _socket!.emit('markAsRead', {
      'userId': userId,
      'contactId': contactId,
    });
  }

  void onReceiveMessage(Function(Message) callback) {
    _socket?.on('receiveMessage', (data) {
      final message = Message.fromJson(data['message']);
      callback(message);
    });
  }

  void onMessageSent(Function(Message) callback) {
    _socket?.on('messageSent', (data) {
      final message = Message.fromJson(data['message']);
      callback(message);
    });
  }

  void onUserTyping(Function(String userId, bool isTyping) callback) {
    _socket?.on('userTyping', (data) {
      callback(data['userId'], data['isTyping']);
    });
  }

  void onMessagesRead(Function(String readBy) callback) {
    _socket?.on('messagesRead', (data) {
      callback(data['readBy']);
    });
  }

  void onUserOnline(Function(String userId) callback) {
    _socket?.on('userOnline', (data) {
      callback(data['userId']);
    });
  }

  void onUserOffline(Function(String userId, DateTime lastSeen) callback) {
    _socket?.on('userOffline', (data) {
      callback(
        data['userId'],
        DateTime.parse(data['lastSeen']),
      );
    });
  }

  void onContactRequest(Function(Map<String, dynamic>) callback) {
    _socket?.on('contactRequest', (data) {
      callback(data);
    });
  }

  void onRequestAccepted(Function(Map<String, dynamic>) callback) {
    _socket?.on('requestAccepted', (data) {
      callback(data);
    });
  }

  void onUserBlocked(Function(String blockerId) callback) {
    _socket?.on('userBlocked', (data) {
      callback(data['blockerId']);
    });
  }

  void onSocketError(Function(String error) callback) {
    _socket?.on('error', (data) {
      callback(data['message'] ?? 'Unknown error');
    });
  }

  void removeAllListeners() {
    _socket?.off('receiveMessage');
    _socket?.off('messageSent');
    _socket?.off('userTyping');
    _socket?.off('messagesRead');
    _socket?.off('userOnline');
    _socket?.off('userOffline');
    _socket?.off('contactRequest');
    _socket?.off('requestAccepted');
    _socket?.off('userBlocked');
    _socket?.off('incomingCall');
    _socket?.off('callInitiated');
    _socket?.off('callAccepted');
    _socket?.off('callConnected');
    _socket?.off('callMissed');
    _socket?.off('callRejected');
    _socket?.off('callEnded');
    _socket?.off('callSignal');
    _socket?.off('error');
  }

  void removeCallListeners() {
    _socket?.off('incomingCall');
    _socket?.off('callInitiated');
    _socket?.off('callAccepted');
    _socket?.off('callConnected');
    _socket?.off('callMissed');
    _socket?.off('callRejected');
    _socket?.off('callEnded');
    _socket?.off('callSignal');
  }

  void initiateCall({
    required String callId,
    required String callerId,
    required List<String> participantIds,
    required bool isGroup,
  }) {
    if (!_isConnected) return;
    _socket!.emit('initiateCall', {
      'callId': callId,
      'callerId': callerId,
      'participantIds': participantIds,
      'isGroup': isGroup,
    });
  }

  void acceptCall({
    required String callId,
    required String userId,
    required List<String> participantIds,
  }) {
    if (!_isConnected) return;
    _socket!.emit('acceptCall', {
      'callId': callId,
      'userId': userId,
      'participantIds': participantIds,
    });
  }

  void rejectCall({
    required String callId,
    required String userId,
    required List<String> participantIds,
  }) {
    if (!_isConnected) return;
    _socket!.emit('rejectCall', {
      'callId': callId,
      'userId': userId,
      'participantIds': participantIds,
    });
  }

  void endCall({
    required String callId,
    required String userId,
    required List<String> participantIds,
  }) {
    if (!_isConnected) return;
    _socket!.emit('endCall', {
      'callId': callId,
      'userId': userId,
      'participantIds': participantIds,
    });
  }

  void onIncomingCall(Function(Map<String, dynamic>) callback) {
    _socket?.on('incomingCall', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onCallInitiated(Function(Map<String, dynamic>) callback) {
    _socket?.on('callInitiated', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onCallAccepted(Function(Map<String, dynamic>) callback) {
    _socket?.on('callAccepted', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onCallConnected(Function(Map<String, dynamic>) callback) {
    _socket?.on('callConnected', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onCallMissed(Function(Map<String, dynamic>) callback) {
    _socket?.on('callMissed', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onCallRejected(Function(Map<String, dynamic>) callback) {
    _socket?.on('callRejected', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onCallEnded(Function(Map<String, dynamic>) callback) {
    _socket?.on('callEnded', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void sendCallSignal({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required String type,
    Map<String, dynamic>? sdp,
    Map<String, dynamic>? candidate,
  }) {
    if (!_isConnected) return;
    _socket!.emit('callSignal', {
      'callId': callId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'type': type,
      if (sdp != null) 'sdp': sdp,
      if (candidate != null) 'candidate': candidate,
    });
  }

  void onCallSignal(Function(Map<String, dynamic>) callback) {
    _socket?.on('callSignal', (data) => callback(Map<String, dynamic>.from(data)));
  }
}
