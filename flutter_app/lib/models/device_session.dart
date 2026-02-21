class DeviceSession {
  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String appVersion;
  final DateTime lastActiveAt;

  const DeviceSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.lastActiveAt,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: (json['_id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? 'Unknown device').toString(),
      platform: (json['platform'] ?? 'unknown').toString(),
      appVersion: (json['appVersion'] ?? '1.0.0').toString(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt']).toLocal()
          : DateTime.now(),
    );
  }
}

