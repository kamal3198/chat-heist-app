import '../config/api_config.dart';
import '../models/user.dart';
import '../models/contact_request.dart';
import 'api_service.dart';

class ContactService extends ApiService {
  // Get accepted contacts
  Future<List<User>> getContacts() async {
    try {
      final response = await get('${ApiConfig.baseUrl}${ApiConfig.getContacts}');
      
      if (isSuccess(response)) {
        final data = parseResponse(response);
        final List contacts = data['contacts'] ?? [];
        return contacts.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get contacts error: $e');
      return [];
    }
  }

  // Send contact request
  Future<Map<String, dynamic>> sendContactRequest(String receiverId) async {
    try {
      final response = await post(
        '${ApiConfig.baseUrl}${ApiConfig.sendContactRequest}',
        {'receiverId': receiverId},
      );

      final data = parseResponse(response);

      if (isSuccess(response)) {
        return {
          'success': true,
          'request': ContactRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Get pending requests (received)
  Future<List<ContactRequest>> getPendingRequests() async {
    try {
      final response = await get('${ApiConfig.baseUrl}${ApiConfig.getPendingRequests}');
      
      if (isSuccess(response)) {
        final data = parseResponse(response);
        final List requests = data['requests'] ?? [];
        return requests.map((json) => ContactRequest.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get pending requests error: $e');
      return [];
    }
  }

  // Get sent requests
  Future<List<ContactRequest>> getSentRequests() async {
    try {
      final response = await get('${ApiConfig.baseUrl}${ApiConfig.getSentRequests}');
      
      if (isSuccess(response)) {
        final data = parseResponse(response);
        final List requests = data['requests'] ?? [];
        return requests.map((json) => ContactRequest.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get sent requests error: $e');
      return [];
    }
  }

  // Accept contact request
  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    try {
      final response = await put(
        '${ApiConfig.baseUrl}${ApiConfig.acceptRequest(requestId)}',
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
          'error': data['error'] ?? 'Failed to accept request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Reject contact request
  Future<Map<String, dynamic>> rejectRequest(String requestId) async {
    try {
      final response = await put(
        '${ApiConfig.baseUrl}${ApiConfig.rejectRequest(requestId)}',
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
          'error': data['error'] ?? 'Failed to reject request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Remove contact
  Future<Map<String, dynamic>> removeContact(String userId) async {
    try {
      final response = await delete(
        '${ApiConfig.baseUrl}${ApiConfig.removeContact(userId)}',
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
          'error': data['error'] ?? 'Failed to remove contact',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  // Search users
  Future<List<Map<String, dynamic>>> searchUsers(String username) async {
    try {
      final encodedUsername = Uri.encodeQueryComponent(username.trim());
      final response = await get(
        '${ApiConfig.baseUrl}${ApiConfig.searchUsers}?username=$encodedUsername',
      );
      
      if (isSuccess(response)) {
        final data = parseResponse(response);
        final List users = data['users'] ?? [];
        return users.cast<Map<String, dynamic>>();
      }
      final data = parseResponse(response);
      print('Search users failed (${response.statusCode}): ${data['error'] ?? response.body}');
      return [];
    } catch (e) {
      print('Search users error: $e');
      return [];
    }
  }
}
