class CallSession {
  final String callId;
  final String callerId;
  final List<String> participantIds;
  final bool isGroup;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final String status;

  const CallSession({
    required this.callId,
    required this.callerId,
    required this.participantIds,
    required this.isGroup,
    required this.startedAt,
    this.connectedAt,
    this.status = 'ringing',
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    final participantsRaw = json['participantIds'] as List? ?? const [];
    return CallSession(
      callId: json['callId']?.toString() ?? '',
      callerId: json['callerId']?.toString() ?? '',
      participantIds: participantsRaw.map((e) => e.toString()).toList(),
      isGroup: json['isGroup'] == true,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      connectedAt: json['connectedAt'] != null
          ? DateTime.tryParse(json['connectedAt'].toString())?.toLocal()
          : null,
      status: json['status']?.toString() ?? 'ringing',
    );
  }

  CallSession copyWith({
    DateTime? connectedAt,
    String? status,
  }) {
    return CallSession(
      callId: callId,
      callerId: callerId,
      participantIds: participantIds,
      isGroup: isGroup,
      startedAt: startedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      status: status ?? this.status,
    );
  }
}
