import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/group.dart';
import 'api_service.dart';

class GroupService extends ApiService {
  Future<List<Group>> getGroups() async {
    try {
      final response = await get('${ApiConfig.baseUrl}${ApiConfig.groups}');
      if (!isSuccess(response)) return [];
      final data = parseResponse(response);
      final groups = (data['groups'] as List?) ?? const [];
      return groups
          .whereType<Map<String, dynamic>>()
          .map(Group.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<String> memberIds,
    String description = '',
  }) async {
    try {
      final response = await post(
        '${ApiConfig.baseUrl}${ApiConfig.groups}',
        {
          'name': name,
          'description': description,
          'memberIds': memberIds,
        },
      );
      return _parseGroupResponse(response, fallback: 'Failed to create group');
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    try {
      final response = await post(
        '${ApiConfig.baseUrl}${ApiConfig.addGroupMembers(groupId)}',
        {'memberIds': memberIds},
      );
      return _parseGroupResponse(response, fallback: 'Failed to add members');
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    try {
      final response = await delete(
        '${ApiConfig.baseUrl}${ApiConfig.removeGroupMember(groupId, memberId)}',
      );
      final data = parseResponse(response);
      if (!isSuccess(response)) {
        return {'success': false, 'error': data['error'] ?? 'Failed to remove member'};
      }

      if (data['deleted'] == true) {
        return {'success': true, 'deleted': true};
      }

      return {'success': true, 'group': Group.fromJson(data['group'])};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> promoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    try {
      final response = await post(
        '${ApiConfig.baseUrl}${ApiConfig.promoteGroupAdmin(groupId, memberId)}',
        {},
      );
      return _parseGroupResponse(response, fallback: 'Failed to promote admin');
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> demoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    try {
      final response = await delete(
        '${ApiConfig.baseUrl}${ApiConfig.demoteGroupAdmin(groupId, memberId)}',
      );
      return _parseGroupResponse(response, fallback: 'Failed to demote admin');
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Map<String, dynamic> _parseGroupResponse(
    http.Response response, {
    required String fallback,
  }) {
    final data = parseResponse(response);
    if (!isSuccess(response)) {
      return {
        'success': false,
        'error': data['error'] ?? fallback,
      };
    }
    return {
      'success': true,
      'group': Group.fromJson(data['group']),
    };
  }
}
