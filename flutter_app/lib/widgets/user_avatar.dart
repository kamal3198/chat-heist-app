import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;
  final bool showOnlineIndicator;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 24,
    this.showOnlineIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundImage: ApiConfig.resolveMediaUrl(user.avatar).isNotEmpty
              ? CachedNetworkImageProvider(ApiConfig.resolveMediaUrl(user.avatar))
              : null,
          child: user.avatar.isEmpty
              ? Text(
                  _getInitials(user.username),
                  style: TextStyle(
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
          backgroundColor: _getColorFromUsername(user.username),
        ),
        if (showOnlineIndicator && user.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getInitials(String username) {
    if (username.isEmpty) return '?';
    return username.substring(0, 1).toUpperCase();
  }

  Color _getColorFromUsername(String username) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    
    final hash = username.codeUnits.fold(0, (prev, curr) => prev + curr);
    return colors[hash % colors.length];
  }
}
