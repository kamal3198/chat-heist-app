import 'user.dart';

class ContactRequest {
  final String id;
  final User sender;
  final User receiver;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  ContactRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
    required this.createdAt,
  });

  factory ContactRequest.fromJson(Map<String, dynamic> json) {
    final senderData = json['sender'];
    final receiverData = json['receiver'];

    return ContactRequest(
      id: json['_id'] ?? json['id'] ?? '',
      sender: _parseUser(senderData),
      receiver: _parseUser(receiverData),
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
    );
  }

  static User _parseUser(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return User.fromJson(raw);
    }

    if (raw is String) {
      return User(
        id: raw,
        username: 'Unknown',
        avatar: '',
        createdAt: DateTime.now(),
      );
    }

    return User(
      id: '',
      username: 'Unknown',
      avatar: '',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': sender.toJson(),
      'receiver': receiver.toJson(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
