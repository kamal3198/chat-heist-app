import 'package:flutter/foundation.dart';

import '../models/status.dart';
import '../services/status_service.dart';

class StatusProvider with ChangeNotifier {
  final StatusService _service = StatusService();

  bool _isLoading = false;
  String? _error;
  List<Status> _statuses = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Status> get statuses => _statuses;

  Future<void> loadFeed() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _statuses = await _service.getFeed();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> postText(String caption) async {
    try {
      await _service.postTextStatus(caption);
      await loadFeed();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> markViewed(String statusId) async {
    try {
      await _service.viewStatus(statusId);
    } catch (_) {}
  }
}

