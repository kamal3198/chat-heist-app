import 'user.dart';

class Status {
  final String id;
  final User user;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final List<User> views;
  final DateTime createdAt;
  final DateTime expiresAt;

  Status({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    this.views = const [],
    required this.createdAt,
    required this.expiresAt,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      id: json['_id'] ?? json['id'] ?? '',
      user: json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'])
          : User(
              id: json['user']?['_id'] ?? '',
              username: json['user']?['username'] ?? '',
              avatar: json['user']?['avatar'] ?? '',
              createdAt: DateTime.now(),
            ),
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'image',
      caption: json['caption'] ?? '',
      views: (json['views'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((e) => User.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt']).toLocal()
          : DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': user.toJson(),
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'views': views.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Status copyWith({
    String? id,
    User? user,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    List<User>? views,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return Status(
      id: id ?? this.id,
      user: user ?? this.user,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

// Grouped status by user for story viewer
class UserStatuses {
  final User user;
  final List<Status> statuses;
  final DateTime latestTimestamp;

  UserStatuses({
    required this.user,
    required this.statuses,
    required this.latestTimestamp,
  });

  factory UserStatuses.fromJson(Map<String, dynamic> json) {
    return UserStatuses(
      user: json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'])
          : User(
              id: json['user']?['_id'] ?? '',
              username: json['user']?['username'] ?? '',
              avatar: json['user']?['avatar'] ?? '',
              isOnline: json['user']?['isOnline'] ?? false,
              createdAt: DateTime.now(),
            ),
      statuses: (json['statuses'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((e) => Status.fromJson(e))
              .toList() ??
          [],
      latestTimestamp: json['latestTimestamp'] != null
          ? DateTime.parse(json['latestTimestamp']).toLocal()
          : DateTime.now(),
    );
  }

  bool get hasUnviewed {
    // For simplicity, consider all as unviewed if user's own status
    return true;
  }
}
