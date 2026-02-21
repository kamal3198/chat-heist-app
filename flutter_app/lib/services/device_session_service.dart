import '../config/api_config.dart';
import '../models/device_session.dart';
import 'api_service.dart';

class DeviceSessionService {
  final ApiService _api = ApiService();

  Future<(List<DeviceSession>, String?)> listSessions() async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.deviceSessions}');
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to load sessions');
    }

    final sessions = ((data['sessions'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(DeviceSession.fromJson)
        .toList();

    return (sessions, data['currentSessionId']?.toString());
  }

  Future<void> removeSession(String sessionId) async {
    final response = await _api.delete('${ApiConfig.baseUrl}${ApiConfig.removeDeviceSession(sessionId)}');
    if (!_api.isSuccess(response)) {
      final data = _api.parseResponse(response);
      throw Exception(data['error'] ?? 'Failed to remove session');
    }
  }
}

