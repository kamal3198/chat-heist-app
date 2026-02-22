import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/contact_request.dart';
import '../services/contact_service.dart';
import '../services/blocked_user_service.dart';
import '../services/socket_service.dart';

class ContactProvider with ChangeNotifier {
  final ContactService _contactService = ContactService();
  final BlockedUserService _blockedUserService = BlockedUserService();
  final SocketService _socketService = SocketService();

  List<User> _contacts = [];
  List<ContactRequest> _pendingRequests = [];
  List<ContactRequest> _sentRequests = [];
  List<User> _blockedUsers = [];
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  bool _initializing = false;
  String? _initializedUserId;
  bool _socketListenersBound = false;

  List<User> get contacts => _contacts;
  List<ContactRequest> get pendingRequests => _pendingRequests;
  List<ContactRequest> get sentRequests => _sentRequests;
  List<User> get blockedUsers => _blockedUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;

  // Initialize and load contacts
  Future<void> initialize(String userId) async {
    if (_initializing) return;
    if (_initialized && _initializedUserId == userId) return;

    _initializing = true;
    _setLoading(true, notify: true);

    try {
      await loadContacts(notify: false);
      await loadPendingRequests(notify: false);
      await loadSentRequests(notify: false);
      await loadBlockedUsers(notify: false);

      if (!_socketListenersBound) {
        _setupSocketListeners();
        _socketListenersBound = true;
      }

      _initialized = true;
      _initializedUserId = userId;
    } finally {
      _initializing = false;
      _setLoading(false, notify: true);
    }
  }

  // Setup socket listeners
  void _setupSocketListeners() {
    _socketService.onContactRequest((data) {
      final request = ContactRequest.fromJson(data['request']);
      _pendingRequests.insert(0, request);
      notifyListeners();
    });

    _socketService.onRequestAccepted((data) {
      final request = ContactRequest.fromJson(data['request']);
      // Remove from sent requests
      _sentRequests.removeWhere((r) => r.id == request.id);
      // Add to contacts
      unawaited(loadContacts());
      notifyListeners();
    });

    _socketService.onUserBlocked((blockerId) {
      // Remove from contacts if blocked by someone
      unawaited(loadContacts());
      notifyListeners();
    });
  }

  // Load accepted contacts
  Future<void> loadContacts({bool notify = true}) async {
    _setLoading(true, notify: notify);
    _error = null;

    try {
      _contacts = await _contactService.getContacts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false, notify: notify);
      if (notify) notifyListeners();
    }
  }

  // Load pending requests (received)
  Future<void> loadPendingRequests({bool notify = true}) async {
    try {
      _pendingRequests = await _contactService.getPendingRequests();
      if (notify) notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (notify) notifyListeners();
    }
  }

  // Load sent requests
  Future<void> loadSentRequests({bool notify = true}) async {
    try {
      _sentRequests = await _contactService.getSentRequests();
      if (notify) notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (notify) notifyListeners();
    }
  }

  // Load blocked users
  Future<void> loadBlockedUsers({bool notify = true}) async {
    try {
      _blockedUsers = await _blockedUserService.getBlockedUsers();
      if (notify) notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (notify) notifyListeners();
    }
  }

  // Send contact request
  Future<bool> sendContactRequest(String receiverId) async {
    final result = await _contactService.sendContactRequest(receiverId);
    if (result['success']) {
      await loadSentRequests();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Accept contact request
  Future<bool> acceptRequest(String requestId) async {
    final result = await _contactService.acceptRequest(requestId);
    if (result['success']) {
      _pendingRequests.removeWhere((r) => r.id == requestId);
      await loadContacts();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Reject contact request
  Future<bool> rejectRequest(String requestId) async {
    final result = await _contactService.rejectRequest(requestId);
    if (result['success']) {
      _pendingRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Remove contact
  Future<bool> removeContact(String userId) async {
    final result = await _contactService.removeContact(userId);
    if (result['success']) {
      _contacts.removeWhere((c) => c.id == userId);
      notifyListeners();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Block user
  Future<bool> blockUser(String userId) async {
    final result = await _blockedUserService.blockUser(userId);
    if (result['success']) {
      _contacts.removeWhere((c) => c.id == userId);
      await loadBlockedUsers();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Unblock user
  Future<bool> unblockUser(String userId) async {
    final result = await _blockedUserService.unblockUser(userId);
    if (result['success']) {
      _blockedUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // Search users
  Future<List<Map<String, dynamic>>> searchUsers(String username) async {
    final normalized = username.trim();
    if (normalized.length < 2) return [];
    return await _contactService.searchUsers(normalized);
  }

  // Update contact online status
  void updateContactOnlineStatus(String userId, bool isOnline) {
    final index = _contacts.indexWhere((c) => c.id == userId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(
        isOnline: isOnline,
        lastSeen: isOnline ? null : DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    _initialized = false;
    _initializing = false;
    _initializedUserId = null;
    _socketListenersBound = false;
    super.dispose();
  }

  void _setLoading(bool value, {required bool notify}) {
    if (_isLoading == value) return;
    _isLoading = value;
    if (notify) notifyListeners();
  }
}
