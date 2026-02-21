import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../services/channel_service.dart';

class ChannelProvider with ChangeNotifier {
  final ChannelService _service = ChannelService();

  bool _isLoading = false;
  String? _error;
  List<Channel> _myChannels = [];
  List<Channel> _discoverChannels = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Channel> get myChannels => _myChannels;
  List<Channel> get discoverChannels => _discoverChannels;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _myChannels = await _service.getMyChannels();
      _discoverChannels = await _service.discoverChannels();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create({required String name, required String description, required bool isCommunity}) async {
    try {
      await _service.createChannel(name: name, description: description, isCommunity: isCommunity);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> join(String channelId) async {
    await _service.joinChannel(channelId);
    await loadAll();
  }

  Future<void> leave(String channelId) async {
    await _service.leaveChannel(channelId);
    await loadAll();
  }

  Future<void> publish(String channelId, String text) async {
    await _service.publishPost(channelId, text);
    await loadAll();
  }
}

