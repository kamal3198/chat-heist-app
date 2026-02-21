import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'current_user';
  static const _deviceSessionIdKey = 'device_session_id';
  static const _deviceIdKey = 'device_id';
  static const Duration _requestTimeout = Duration(seconds: 15);

  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String _connectionError(Object error) {
    if (error is SocketException || error is HttpException) {
      return 'Cannot reach server at ${ApiConfig.baseUrl}. '
          'Start backend and ensure mobile uses your machine IP via --dart-define=API_BASE_URL=http://YOUR_IP:3000';
    }
    if (error is TimeoutException) {
      return 'Request timed out while connecting to ${ApiConfig.baseUrl}. Check backend/network and try again.';
    }
    if (error is fb.FirebaseAuthException) {
      return error.message ?? 'Firebase authentication failed';
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

  Future<void> _persistSession(Map<String, dynamic> data) async {
    if (data['token'] != null) {
      await _storage.write(key: _tokenKey, value: data['token'].toString());
    }
    if (data['user'] != null) {
      await _storage.write(key: _userKey, value: jsonEncode(data['user']));
    }
    if (data['sessionId'] != null) {
      await _storage.write(key: _deviceSessionIdKey, value: data['sessionId'].toString());
    }
  }

  Future<Map<String, dynamic>> _syncSessionWithBackend({
    required String idToken,
    String? username,
    String? email,
  }) async {
    final meta = await _deviceMeta();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.firebaseSession}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        ...meta,
      }),
    ).timeout(_requestTimeout);

    final data = _safeJson(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _persistSession(data);
      return {
        'success': true,
        'token': data['token'],
        'user': User.fromJson(data['user']),
      };
    }

    return {
      'success': false,
      'error': data['error'] ?? 'Authentication sync failed',
    };
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
      return {'error': 'Unexpected server response'};
    } catch (_) {
      return {'error': 'Server returned invalid response'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        return {
          'success': false,
          'error': 'Failed to get Firebase ID token',
        };
      }

      return await _syncSessionWithBackend(
        idToken: idToken,
        email: credential.user?.email,
      );
    } catch (e) {
      return {
        'success': false,
        'error': _connectionError(e),
      };
    }
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      final normalizedUsername = username.trim().toLowerCase();
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null && normalizedUsername.isNotEmpty) {
        await credential.user!.updateDisplayName(normalizedUsername);
      }

      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        return {
          'success': false,
          'error': 'Failed to get Firebase ID token',
        };
      }

      return await _syncSessionWithBackend(
        idToken: idToken,
        username: normalizedUsername,
        email: email,
      );
    } catch (e) {
      return {
        'success': false,
        'error': _connectionError(e),
      };
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {
          'success': false,
          'error': 'Google sign-in canceled',
        };
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        return {
          'success': false,
          'error': 'Failed to get Google Firebase token',
        };
      }

      return await _syncSessionWithBackend(
        idToken: idToken,
        email: userCredential.user?.email,
      );
    } catch (e) {
      return {
        'success': false,
        'error': _connectionError(e),
      };
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final headers = await authHeaders();
      if (!headers.containsKey('Authorization')) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getCurrentUser}'),
        headers: headers,
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = _safeJson(response.body);
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

  Future<String?> getSessionId() async {
    return await _storage.read(key: _deviceSessionIdKey);
  }

  Future<String?> getToken() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        final token = await currentUser.getIdToken();
        if (token != null) {
          await _storage.write(key: _tokenKey, value: token);
          return token;
        }
      }
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return await _storage.read(key: _tokenKey);
    }
  }

  Future<Map<String, String>> authHeaders({bool includeContentType = true}) async {
    final headers = <String, String>{
      if (includeContentType) 'Content-Type': 'application/json',
    };

    final token = await getToken();
    final sessionId = await getSessionId();

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['x-session-id'] = sessionId;
    }

    return headers;
  }

  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
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
      final headers = await authHeaders(includeContentType: false);
      if (!headers.containsKey('Authorization')) {
        return {
          'success': false,
          'error': 'Not authenticated',
        };
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.currentProfile}'),
      );

      request.headers.addAll(headers);

      if (username != null) request.fields['username'] = username;
      if (about != null) request.fields['about'] = about;
      if (avatarFile != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));
      }

      final streamedResponse = await request.send();
      final body = await streamedResponse.stream.bytesToString();
      final data = _safeJson(body);

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
