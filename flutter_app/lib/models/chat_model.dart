import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastTimestamp;
  final String lastSenderId;
  final String lastDeliveryStatus;
  final bool retentionEnabled;
  final int? retainDays;

  const ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.lastSenderId,
    required this.lastDeliveryStatus,
    required this.retentionEnabled,
    required this.retainDays,
  });

  factory ChatModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['lastTimestamp'];
    final retention = (data['retentionPolicy'] as Map?) ?? const {};
    return ChatModel(
      id: doc.id,
      participants: ((data['participants'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastTimestamp: ts is Timestamp ? ts.toDate() : null,
      lastSenderId: (data['lastSenderId'] ?? '').toString(),
      lastDeliveryStatus: (data['lastDeliveryStatus'] ?? 'sent').toString(),
      retentionEnabled: retention['enabled'] == true,
      retainDays: retention['retainDays'] is int
          ? retention['retainDays'] as int
          : int.tryParse((retention['retainDays'] ?? '').toString()),
    );
  }
}
