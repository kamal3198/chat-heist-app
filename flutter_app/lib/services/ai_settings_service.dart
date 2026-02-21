import '../config/api_config.dart';
import '../models/ai_settings.dart';
import 'api_service.dart';

class AISettingsService {
  final ApiService _api = ApiService();

  Future<AISettings> getSettings() async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.aiSettings}');
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to fetch AI settings');
    }
    return AISettings.fromJson(data['aiSettings'] ?? {});
  }

  Future<AISettings> updateSettings(AISettings settings) async {
    final response = await _api.put('${ApiConfig.baseUrl}${ApiConfig.aiSettings}', settings.toJson());
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to update AI settings');
    }
    return AISettings.fromJson(data['aiSettings'] ?? {});
  }
}

