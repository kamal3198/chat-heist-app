import 'user.dart';

class Channel {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final String kind;
  final User creator;
  final List<User> admins;
  final List<User> subscribers;
  final List<Map<String, dynamic>> posts;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Channel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatar = '',
    this.kind = 'channel',
    required this.creator,
    this.admins = const [],
    this.subscribers = const [],
    this.posts = const [],
    this.isPrivate = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    User parseUser(dynamic value) {
      if (value is Map<String, dynamic>) return User.fromJson(value);
      return User(id: '', username: '', avatar: '', createdAt: DateTime.now());
    }

    final postsList = (json['posts'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    return Channel(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'channel',
      creator: parseUser(json['creator']),
      admins: (json['admins'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(User.fromJson)
              .toList() ??
          [],
      subscribers: (json['subscribers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(User.fromJson)
              .toList() ??
          [],
      posts: postsList,
      isPrivate: json['isPrivate'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  int get subscriberCount => subscribers.length;

  bool isAdmin(String userId) => admins.any((admin) => admin.id == userId);
}

