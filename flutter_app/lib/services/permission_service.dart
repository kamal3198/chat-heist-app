import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> ensureMicrophonePermission(BuildContext context) async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    await _showPermissionDialog(context, permanentlyDenied: status.isPermanentlyDenied);
    return false;
  }

  Future<void> _showPermissionDialog(
    BuildContext context, {
    required bool permanentlyDenied,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: Text(
          permanentlyDenied
              ? 'Microphone access is permanently denied. Enable it in app settings to place voice calls.'
              : 'Microphone access is required to place or accept voice calls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (permanentlyDenied)
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
}
