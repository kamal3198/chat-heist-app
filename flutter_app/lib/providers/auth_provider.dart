import 'package:flutter/material.dart';
import 'dart:io';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SocketService _socketService = SocketService();
  final NotificationService _notificationService = NotificationService.instance;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        _currentUser = await _authService.getCurrentUser();
        if (_currentUser != null) {
          _socketService.connect(_currentUser!.id);
          await _notificationService.initializeForUser(_currentUser!.id);
          return true;
        }
        _error = 'Saved session is invalid. Please login again.';
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result['success']) {
        _currentUser = result['user'];
        _socketService.connect(_currentUser!.id);
        await _notificationService.initializeForUser(_currentUser!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result['error'];
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(username, email, password);

      if (result['success']) {
        _currentUser = result['user'];
        _socketService.connect(_currentUser!.id);
        await _notificationService.initializeForUser(_currentUser!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result['error'];
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result['success']) {
        _currentUser = result['user'];
        _socketService.connect(_currentUser!.id);
        await _notificationService.initializeForUser(_currentUser!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result['error'];
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _socketService.disconnect();
    await _notificationService.clearForLogout();
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String username,
    required String about,
    File? avatarFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.updateProfile(
      username: username,
      about: about,
      avatarFile: avatarFile,
    );

    _isLoading = false;

    if (result['success'] == true) {
      _currentUser = result['user'] as User;
      notifyListeners();
      return true;
    }

    _error = result['error'] as String? ?? 'Failed to update profile';
    notifyListeners();
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void updateUserStatus(bool isOnline) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        isOnline: isOnline,
        lastSeen: isOnline ? null : DateTime.now(),
      );
      notifyListeners();
    }
  }
}
