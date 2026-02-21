import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'current_user';
  static const _deviceSessionIdKey = 'device_session_id';
  static const _deviceIdKey = 'device_id';
  static const Duration _requestTimeout = Duration(seconds: 12);

  String _connectionError(Object error) {
    if (error is SocketException || error is HttpException) {
      return 'Cannot reach server at ${ApiConfig.baseUrl}. '
          'Start backend and ensure mobile uses your machine IP via --dart-define=API_BASE_URL=http://YOUR_IP:3000';
    }
    if (error is TimeoutException) {
      return 'Request timed out while connecting to ${ApiConfig.baseUrl}. Check backend/network and try again.';
    }
    return 'Connection error: $error';
  }

  Future<Map<String, String>> _deviceMeta() async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final deviceName = kIsWeb
        ? 'Web Browser'
        : '${defaultTargetPlatform.name}-${Platform.operatingSystemVersion.split(' ').firstOrNull ?? 'device'}';

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'appVersion': '1.0.0',
    };
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final meta = await _deviceMeta();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          ...meta,
        }),
      ).timeout(_requestTimeout);

      Map<String, dynamic> data;
      try {
        final parsed = jsonDecode(response.body);
        data = parsed is Map<String, dynamic> ? parsed : {'error': 'Unexpected server response'};
      } catch (_) {
        data = {'error': 'Server returned invalid response'};
      }

      if (response.statusCode == 200) {
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _userKey, value: jsonEncode(data['user']));
        if (data['sessionId'] != null) {
          await _storage.write(key: _deviceSessionIdKey, value: data['sessionId'].toString());
        }

        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': _connectionError(e),
      };
    }
  }

  Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final meta = await _deviceMeta();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          ...meta,
        }),
      ).timeout(_requestTimeout);

      Map<String, dynamic> data;
      try {
        final parsed = jsonDecode(response.body);
        data = parsed is Map<String, dynamic> ? parsed : {'error': 'Unexpected server response'};
      } catch (_) {
        data = {'error': 'Server returned invalid response'};
      }

      if (response.statusCode == 201) {
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _userKey, value: jsonEncode(data['user']));
        if (data['sessionId'] != null) {
          await _storage.write(key: _deviceSessionIdKey, value: data['sessionId'].toString());
        }

        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': _connectionError(e),
      };
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getCurrentUser}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        await _storage.write(key: _userKey, value: jsonEncode(data['user']));
        return user;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User?> getSavedUser() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _deviceSessionIdKey);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? about,
    File? avatarFile,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated',
        };
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.currentProfile}'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (username != null) request.fields['username'] = username;
      if (about != null) request.fields['about'] = about;
      if (avatarFile != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));
      }

      final streamedResponse = await request.send();
      final body = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(body);

      if (streamedResponse.statusCode == 200) {
        await _storage.write(key: _userKey, value: jsonEncode(data['user']));
        return {
          'success': true,
          'user': User.fromJson(data['user']),
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Failed to update profile',
      };
    } catch (e) {
      return {
        'success': false,
        'error': _connectionError(e),
      };
    }
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}


