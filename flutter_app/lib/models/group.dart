import 'user.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final List<User> members;
  final List<User> admins;
  final User? createdBy;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.avatar,
    required this.members,
    required this.admins,
    required this.createdBy,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    final membersJson = (json['members'] as List?) ?? const [];
    final adminsJson = (json['admins'] as List?) ?? const [];

    return Group(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      members: membersJson
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList(),
      admins: adminsJson
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList(),
      createdBy: json['createdBy'] is Map<String, dynamic>
          ? User.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}
