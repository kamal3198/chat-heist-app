import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _normalize(_envBaseUrl);
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000';
    }
  }

  static String get socketUrl => baseUrl;

  static String _normalize(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String resolveMediaUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return '$baseUrl$pathOrUrl';
  }

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String getCurrentUser = '/auth/me';

  static const String getContacts = '/contacts';
  static const String sendContactRequest = '/contacts/request';
  static const String getPendingRequests = '/contacts/requests';
  static const String getSentRequests = '/contacts/requests/sent';
  static String acceptRequest(String id) => '/contacts/request/$id/accept';
  static String rejectRequest(String id) => '/contacts/request/$id/reject';
  static String removeContact(String userId) => '/contacts/$userId';

  static const String getBlockedUsers = '/blocked';
  static String blockUser(String userId) => '/blocked/$userId';
  static String unblockUser(String userId) => '/blocked/$userId';
  static String checkBlocked(String userId) => '/blocked/check/$userId';

  static const String searchUsers = '/users/search';
  static const String currentProfile = '/users/me';
  static const String aiSettings = '/users/me/ai-settings';
  static String getUserById(String id) => '/users/$id';

  static String getMessages(String contactId) => '/messages/$contactId';
  static String markMessagesAsRead(String contactId) => '/messages/read/$contactId';
  static const String uploadFile = '/messages/upload';
  static const String bulkDeleteMessages = '/messages/bulk-delete';

  static const String groups = '/groups';
  static String addGroupMembers(String groupId) => '/groups/$groupId/members';
  static String removeGroupMember(String groupId, String memberId) => '/groups/$groupId/members/$memberId';
  static String promoteGroupAdmin(String groupId, String memberId) => '/groups/$groupId/admins/$memberId';
  static String demoteGroupAdmin(String groupId, String memberId) => '/groups/$groupId/admins/$memberId';

  static const String statusFeed = '/status/feed';
  static const String createStatus = '/status';
  static String viewStatus(String id) => '/status/$id/view';

  static const String channels = '/channels';
  static const String discoverChannels = '/channels/discover';
  static String joinChannel(String id) => '/channels/$id/join';
  static String leaveChannel(String id) => '/channels/$id/leave';
  static String channelPosts(String id) => '/channels/$id/posts';

  static const String deviceSessions = '/devices';
  static String removeDeviceSession(String id) => '/devices/$id';

  static const String callsHistory = '/calls/history';
  static const String callsIceServers = '/calls/ice-servers';
}


