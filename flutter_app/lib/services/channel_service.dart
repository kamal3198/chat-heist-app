import '../config/api_config.dart';
import '../models/channel.dart';
import 'api_service.dart';

class ChannelService {
  final ApiService _api = ApiService();

  Future<List<Channel>> getMyChannels() async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.channels}');
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to load channels');
    }
    final list = (data['channels'] as List?) ?? [];
    return list.whereType<Map<String, dynamic>>().map(Channel.fromJson).toList();
  }

  Future<List<Channel>> discoverChannels() async {
    final response = await _api.get('${ApiConfig.baseUrl}${ApiConfig.discoverChannels}');
    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to discover channels');
    }
    final list = (data['channels'] as List?) ?? [];
    return list.whereType<Map<String, dynamic>>().map(Channel.fromJson).toList();
  }

  Future<Channel> createChannel({
    required String name,
    required String description,
    required bool isCommunity,
  }) async {
    final response = await _api.post('${ApiConfig.baseUrl}${ApiConfig.channels}', {
      'name': name,
      'description': description,
      'kind': isCommunity ? 'community' : 'channel',
      'isPrivate': false,
    });

    final data = _api.parseResponse(response);
    if (!_api.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to create channel');
    }
    return Channel.fromJson(data['channel']);
  }

  Future<void> joinChannel(String channelId) async {
    final response = await _api.post('${ApiConfig.baseUrl}${ApiConfig.joinChannel(channelId)}', {});
    if (!_api.isSuccess(response)) {
      final data = _api.parseResponse(response);
      throw Exception(data['error'] ?? 'Failed to join channel');
    }
  }

  Future<void> leaveChannel(String channelId) async {
    final response = await _api.post('${ApiConfig.baseUrl}${ApiConfig.leaveChannel(channelId)}', {});
    if (!_api.isSuccess(response)) {
      final data = _api.parseResponse(response);
      throw Exception(data['error'] ?? 'Failed to leave channel');
    }
  }

  Future<void> publishPost(String channelId, String text) async {
    final response = await _api.post('${ApiConfig.baseUrl}${ApiConfig.channelPosts(channelId)}', {
      'text': text,
    });
    if (!_api.isSuccess(response)) {
      final data = _api.parseResponse(response);
      throw Exception(data['error'] ?? 'Failed to publish post');
    }
  }
}

