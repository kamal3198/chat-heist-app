class AISettings {
  final bool enabled;
  final String mode;
  final String customReply;

  const AISettings({
    this.enabled = false,
    this.mode = 'off',
    this.customReply = '',
  });

  factory AISettings.fromJson(Map<String, dynamic> json) {
    return AISettings(
      enabled: json['enabled'] ?? false,
      mode: (json['mode'] ?? 'off').toString(),
      customReply: (json['customReply'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'mode': mode,
      'customReply': customReply,
    };
  }

  AISettings copyWith({
    bool? enabled,
    String? mode,
    String? customReply,
  }) {
    return AISettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      customReply: customReply ?? this.customReply,
    );
  }
}

