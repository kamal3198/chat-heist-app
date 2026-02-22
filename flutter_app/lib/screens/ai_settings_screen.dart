import 'package:flutter/material.dart';

import '../models/ai_settings.dart';
import '../services/ai_settings_service.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final AISettingsService _service = AISettingsService();
  final TextEditingController _customReplyController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  AISettings _settings = const AISettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getSettings();
      if (!mounted) return;
      _customReplyController.text = data.customReply;
      setState(() => _settings = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final updated = _settings.copyWith(customReply: _customReplyController.text.trim());
      final result = await _service.updateSettings(updated);
      if (!mounted) return;
      setState(() => _settings = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI settings updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _customReplyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Auto-Reply')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SwitchListTile(
            title: const Text('Enable AI auto-reply'),
            value: _settings.enabled,
            onChanged: (v) => setState(() => _settings = _settings.copyWith(enabled: v)),
          ),
          DropdownButtonFormField<String>(
            initialValue: _settings.mode,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: const [
              DropdownMenuItem(value: 'off', child: Text('Off')),
              DropdownMenuItem(value: 'away', child: Text('Away')),
              DropdownMenuItem(value: 'busy', child: Text('Busy')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _settings = _settings.copyWith(mode: v));
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customReplyController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Custom reply',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


