import '../config/api_config.dart';
import '../models/status.dart';
import 'api_service.dart';

class StatusService {
  final ApiService _api = ApiService();

  Future<List<Status>> getFeed() async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.statusFeed}');
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to load statuses');
    }
    final list = (data['statuses'] as List?) ?? [];
    return list.whereType<Map<String, dynamic>>().map(Status.fromJson).toList();
  }

  Future<void> postTextStatus(String caption) async {
    final response = await _api.post('${ApiConfig.baseUrl}${ApiConfig.createStatus}', {
      'caption': caption,
      'mediaType': 'text',
    });
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to post status');
    }
  }

  Future<void> viewStatus(String statusId) async {
    final response = await _api.put('${ApiConfig.baseUrl}${ApiConfig.viewStatus(statusId)}');
    if (!_api.isSuccess(response)) {
      final data = _api.parseResponse(response);
      throw Exception(data['error'] ?? 'Failed to view status');
    }
  }
}

