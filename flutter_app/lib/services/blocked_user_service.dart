import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class BlockedUserService extends ApiService {
  // Get blocked users
  Future<List<User>> getBlockedUsers() async {
    try {
      final response = await get('${ApiConfig.baseUrl}${ApiConfig.getBlockedUsers}');
      
      if (isSuccess(response)) {
        final data = parseResponse(response);
        final List users = data['blockedUsers'] ?? [];
        return users.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get blocked users error: $e');
      return [];
    }
  }

  // Block a user
  Future<Map<String, dynamic>> blockUser(String userId) async {
    try {
      final response = await post(
        '${ApiConfig.baseUrl}${ApiConfig.blockUser(userId)}',
        {},
      );

      final data = parseResponse(response);

      if (isSuccess(response)) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to block user',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Unblock a user
  Future<Map<String, dynamic>> unblockUser(String userId) async {
    try {
      final response = await delete(
        '${ApiConfig.baseUrl}${ApiConfig.unblockUser(userId)}',
      );

      final data = parseResponse(response);

      if (isSuccess(response)) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to unblock user',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Check if user is blocked
  Future<Map<String, dynamic>?> checkBlocked(String userId) async {
    try {
      final response = await get(
        '${ApiConfig.baseUrl}${ApiConfig.checkBlocked(userId)}',
      );
      
      if (isSuccess(response)) {
        return parseResponse(response);
      }
      return null;
    } catch (e) {
      print('Check blocked error: $e');
      return null;
    }
  }
}
