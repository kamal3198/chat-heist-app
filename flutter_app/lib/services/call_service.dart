import '../config/api_config.dart';
import '../models/call_log_entry.dart';
import 'api_service.dart';

class CallService {
  final ApiService _api = ApiService();

  Future<List<CallLogEntry>> getHistory({int limit = 100}) async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.callsHistory}?limit=$limit');
    final data = _api.parseResponse(response);

    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to fetch call history');
    }

    final list = (data['calls'] as List?) ?? [];
    return list.whereType<Map<String, dynamic>>().map(CallLogEntry.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getIceServers() async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.callsIceServers}');
    final data = _api.parseResponse(response);

    if (!_api.isSuccess(response)) {
      return const [
        {'urls': ['stun:stun.l.google.com:19302']},
      ];
    }

    final list = (data['iceServers'] as List?) ?? const [];
    return list.whereType<Map>().map((entry) {
      return entry.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }
}
