import 'package:cloud_firestore/cloud_firestore.dart';

enum DeliveryStatus {
  sent,
  seen,
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String type;
  final DeliveryStatus deliveryStatus;
  final DateTime sentAt;
  final DateTime? seenAt;
  final List<String> deletedFor;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.type,
    required this.deliveryStatus,
    required this.sentAt,
    required this.seenAt,
    required this.deletedFor,
  });

  factory MessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final sentTs = data['sentAt'] ?? data['timestamp'];
    final seenTs = data['seenAt'];
    final statusRaw = (data['deliveryStatus'] ?? '').toString();
    final resolvedStatus = switch (statusRaw) {
      'seen' => DeliveryStatus.seen,
      _ => DeliveryStatus.sent,
    };

    return MessageModel(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      deliveryStatus: resolvedStatus,
      sentAt: sentTs is Timestamp ? sentTs.toDate() : DateTime.now(),
      seenAt: seenTs is Timestamp ? seenTs.toDate() : null,
      deletedFor: ((data['deletedFor'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  bool get isSeen => deliveryStatus == DeliveryStatus.seen;
  bool get isImage => type == 'image';

  bool isDeletedFor(String uid) => deletedFor.contains(uid);
}
