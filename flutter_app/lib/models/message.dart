import 'user.dart';

class Message {
  final String id;
  final User sender;
  final User receiver;
  final String text;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String? clientMessageId;
  final String status; // sent, delivered, read
  final DateTime timestamp;

  Message({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.text,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.clientMessageId,
    required this.status,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      sender: User.fromJson(json['sender']),
      receiver: User.fromJson(json['receiver']),
      text: json['text'] ?? '',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileType: json['fileType'],
      clientMessageId: json['clientMessageId'],
      status: json['status'] ?? 'sent',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp']).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': sender.toJson(),
      'receiver': receiver.toJson(),
      'text': text,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'clientMessageId': clientMessageId,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Message copyWith({
    String? id,
    User? sender,
    User? receiver,
    String? text,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? clientMessageId,
    String? status,
    DateTime? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      text: text ?? this.text,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  
  bool get isImage {
    if (fileType == null) return false;
    return fileType!.startsWith('image/');
  }

  bool get isSticker => text.startsWith('[sticker]');

  String get stickerText {
    if (!isSticker) return text;
    return text.replaceFirst('[sticker]', '').trim();
  }
}
