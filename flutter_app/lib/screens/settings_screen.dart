import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/chat_settings_provider.dart';
import '../providers/theme_provider.dart';
import 'ai_settings_screen.dart';
import 'device_sessions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _readReceipts = true;
  bool _mediaAutoDownload = true;
  bool _enterToSend = false;

  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatSettingsProvider = Provider.of<ChatSettingsProvider>(context);
    final currentWallpaper = chatSettingsProvider.wallpaper;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionCard(
            title: 'Account',
            children: [
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Privacy'),
                subtitle: Text('Last seen, profile photo, blocked users'),
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('AI auto-reply'),
                subtitle: const Text('Away, busy, and custom auto-reply modes'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AISettingsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.devices_outlined),
                title: const Text('Linked devices'),
                subtitle: const Text('Manage active sessions on desktop and mobile'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceSessionsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Chats',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.done_all),
                title: const Text('Read receipts'),
                subtitle: const Text('Send and receive read receipts'),
                value: _readReceipts,
                onChanged: (value) => setState(() => _readReceipts = value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.file_download_outlined),
                title: const Text('Media auto-download'),
                subtitle: const Text('Automatically download media'),
                value: _mediaAutoDownload,
                onChanged: (value) => setState(() => _mediaAutoDownload = value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.keyboard_outlined),
                title: const Text('Enter key sends'),
                subtitle: const Text('Press Enter to send messages'),
                value: _enterToSend,
                onChanged: (value) => setState(() => _enterToSend = value),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Theme'),
                subtitle: Text(_themeLabel(themeProvider.mode)),
                onTap: () => _showThemeDialog(context, themeProvider),
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper_outlined),
                title: const Text('Global chat wallpaper'),
                subtitle: Text(_wallpaperLabel(currentWallpaper)),
                trailing: OutlinedButton(
                  onPressed: () => _showWallpaperPicker(context, chatSettingsProvider),
                  child: const Text('Change'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('Preview thumbnails', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ChatSettingsProvider.availableWallpapers
                      .map((wallpaper) => _wallpaperPreviewTile(
                            wallpaper: wallpaper,
                            selected: wallpaper == currentWallpaper,
                            provider: chatSettingsProvider,
                            onTap: () async {
                              if (wallpaper == 'custom') {
                                final bytes = await _pickWallpaperFromGallery();
                                if (bytes == null) return;
                                await chatSettingsProvider.setGlobalCustomWallpaperBytes(bytes);
                              } else {
                                await chatSettingsProvider.setGlobalWallpaper(wallpaper);
                              }
                            },
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Help',
            children: const [
              ListTile(leading: Icon(Icons.help_outline), title: Text('Help Center')),
              ListTile(leading: Icon(Icons.info_outline), title: Text('App info'), subtitle: Text('ChatHeist v1.1.0')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _wallpaperPreviewTile({
    required String wallpaper,
    required bool selected,
    required ChatSettingsProvider provider,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 86,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          children: [
            Container(
              height: 52,
              decoration: provider.wallpaperPreviewDecoration(wallpaper).copyWith(borderRadius: BorderRadius.circular(10)),
              child: wallpaper == 'custom' ? const Center(child: Icon(Icons.photo_library_outlined)) : null,
            ),
            const SizedBox(height: 6),
            Text(_wallpaperLabel(wallpaper), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemeDialog(BuildContext context, ThemeProvider themeProvider) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(themeProvider.mode == AppThemeMode.system ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: const Text('System default'),
              onTap: () async {
                await themeProvider.setThemeMode(AppThemeMode.system);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(themeProvider.mode == AppThemeMode.light ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: const Text('Light'),
              onTap: () async {
                await themeProvider.setThemeMode(AppThemeMode.light);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(themeProvider.mode == AppThemeMode.dark ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: const Text('Dark'),
              onTap: () async {
                await themeProvider.setThemeMode(AppThemeMode.dark);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWallpaperPicker(BuildContext context, ChatSettingsProvider provider) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Global Wallpaper', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ChatSettingsProvider.availableWallpapers
                    .map((wallpaper) => _wallpaperPreviewTile(
                          wallpaper: wallpaper,
                          selected: provider.wallpaper == wallpaper,
                          provider: provider,
                          onTap: () async {
                            if (wallpaper == 'custom') {
                              final bytes = await _pickWallpaperFromGallery();
                              if (bytes == null) return;
                              await provider.setGlobalCustomWallpaperBytes(bytes);
                            } else {
                              await provider.setGlobalWallpaper(wallpaper);
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _pickWallpaperFromGallery() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return null;
    return image.readAsBytes();
  }

  String _themeLabel(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => 'System default',
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
    };
  }

  String _wallpaperLabel(String wallpaper) {
    switch (wallpaper) {
      case 'mint':
        return 'Mint';
      case 'ocean':
        return 'Ocean';
      case 'sunset':
        return 'Sunset';
      case 'dusk':
        return 'Dusk';
      case 'midnight':
        return 'Midnight';
      case 'custom':
        return 'Custom';
      default:
        return 'Default';
    }
  }
}

