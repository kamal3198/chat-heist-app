import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSettingsProvider with ChangeNotifier {
  static const _globalWallpaperKey = 'chat_wallpaper_global';
  static const _globalCustomKey = 'chat_wallpaper_global_custom';
  static const _perChatKey = 'chat_wallpaper_per_chat';
  static const _perChatCustomKey = 'chat_wallpaper_per_chat_custom';

  static const List<String> availableWallpapers = [
    'none',
    'mint',
    'ocean',
    'sunset',
    'dusk',
    'midnight',
    'custom',
  ];

  String _globalWallpaper = 'none';
  String? _globalCustomImageBase64;

  Map<String, String> _perChatWallpaper = {};
  Map<String, String> _perChatCustomBase64 = {};

  bool _isLoaded = false;

  String get wallpaper => _globalWallpaper;
  bool get isLoaded => _isLoaded;

  String wallpaperForChat(String chatKey) {
    return _perChatWallpaper[chatKey] ?? _globalWallpaper;
  }

  bool hasPerChatWallpaper(String chatKey) => _perChatWallpaper.containsKey(chatKey);

  String _effectiveWallpaper(String? chatKey) {
    if (chatKey == null) return _globalWallpaper;
    return _perChatWallpaper[chatKey] ?? _globalWallpaper;
  }

  String? _effectiveCustomBase64(String? chatKey) {
    final wallpaper = _effectiveWallpaper(chatKey);
    if (wallpaper != 'custom') return null;

    if (chatKey != null && _perChatWallpaper[chatKey] == 'custom') {
      return _perChatCustomBase64[chatKey] ?? _globalCustomImageBase64;
    }

    return _globalCustomImageBase64;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _globalWallpaper = prefs.getString(_globalWallpaperKey) ?? 'none';
    _globalCustomImageBase64 = prefs.getString(_globalCustomKey);

    final perChatRaw = prefs.getString(_perChatKey);
    if (perChatRaw != null && perChatRaw.isNotEmpty) {
      final map = jsonDecode(perChatRaw) as Map<String, dynamic>;
      _perChatWallpaper = map.map((k, v) => MapEntry(k, v.toString()));
    }

    final perChatCustomRaw = prefs.getString(_perChatCustomKey);
    if (perChatCustomRaw != null && perChatCustomRaw.isNotEmpty) {
      final map = jsonDecode(perChatCustomRaw) as Map<String, dynamic>;
      _perChatCustomBase64 = map.map((k, v) => MapEntry(k, v.toString()));
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setWallpaper(String wallpaper) async {
    await setGlobalWallpaper(wallpaper);
  }

  Future<void> setGlobalWallpaper(String wallpaper) async {
    _globalWallpaper = wallpaper;
    if (wallpaper != 'custom') {
      _globalCustomImageBase64 = null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setGlobalCustomWallpaperBytes(Uint8List bytes) async {
    _globalWallpaper = 'custom';
    _globalCustomImageBase64 = base64Encode(bytes);
    await _persist();
    notifyListeners();
  }

  Future<void> setChatWallpaper(
    String chatKey,
    String wallpaper,
  ) async {
    _perChatWallpaper[chatKey] = wallpaper;
    if (wallpaper != 'custom') {
      _perChatCustomBase64.remove(chatKey);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setChatCustomWallpaperBytes(String chatKey, Uint8List bytes) async {
    _perChatWallpaper[chatKey] = 'custom';
    _perChatCustomBase64[chatKey] = base64Encode(bytes);
    await _persist();
    notifyListeners();
  }

  Future<void> clearChatWallpaper(String chatKey) async {
    _perChatWallpaper.remove(chatKey);
    _perChatCustomBase64.remove(chatKey);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalWallpaperKey, _globalWallpaper);

    if (_globalCustomImageBase64 == null || _globalCustomImageBase64!.isEmpty) {
      await prefs.remove(_globalCustomKey);
    } else {
      await prefs.setString(_globalCustomKey, _globalCustomImageBase64!);
    }

    await prefs.setString(_perChatKey, jsonEncode(_perChatWallpaper));
    await prefs.setString(_perChatCustomKey, jsonEncode(_perChatCustomBase64));
  }

  BoxDecoration wallpaperPreviewDecoration(String wallpaper) {
    switch (wallpaper) {
      case 'mint':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8FFF7), Color(0xFFD4F8EC)],
          ),
        );
      case 'ocean':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F4FF), Color(0xFFD8E9FF)],
          ),
        );
      case 'sunset':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0E6), Color(0xFFFFE0CC)],
          ),
        );
      case 'dusk':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E8FF), Color(0xFFE9D5FF)],
          ),
        );
      case 'midnight':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        );
      case 'custom':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4D6), Color(0xFFFFD6A5)],
          ),
        );
      default:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        );
    }
  }

  BoxDecoration buildWallpaperDecoration(ThemeData theme, {String? chatKey}) {
    final wallpaper = _effectiveWallpaper(chatKey);

    if (wallpaper == 'custom') {
      final base64Data = _effectiveCustomBase64(chatKey);
      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        return BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(bytes),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.16),
              BlendMode.darken,
            ),
          ),
        );
      }
    }

    if (wallpaper == 'none') {
      return BoxDecoration(color: theme.scaffoldBackgroundColor);
    }

    return wallpaperPreviewDecoration(wallpaper);
  }
}

