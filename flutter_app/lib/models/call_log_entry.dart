import 'user.dart';

class CallLogEntry {
  final String id;
  final String callId;
  final User caller;
  final List<User> participants;
  final bool isGroup;
  final String status;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const CallLogEntry({
    required this.id,
    required this.callId,
    required this.caller,
    required this.participants,
    required this.isGroup,
    required this.status,
    required this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    User parseUser(dynamic data) {
      if (data is Map<String, dynamic>) {
        return User.fromJson(data);
      }
      return User(id: '', username: 'Unknown', avatar: '', createdAt: DateTime.now());
    }

    final participants = (json['participants'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList() ??
        [];

    return CallLogEntry(
      id: (json['_id'] ?? '').toString(),
      callId: (json['callId'] ?? '').toString(),
      caller: parseUser(json['caller']),
      participants: participants,
      isGroup: json['isGroup'] == true,
      status: (json['status'] ?? 'ended').toString(),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt']).toLocal()
          : DateTime.now(),
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt']).toLocal()
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt']).toLocal()
          : null,
      durationSeconds: (json['durationSeconds'] ?? 0) as int,
    );
  }
}
