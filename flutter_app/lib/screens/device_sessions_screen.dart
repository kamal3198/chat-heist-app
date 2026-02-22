import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/device_session.dart';
import '../services/device_session_service.dart';

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  final DeviceSessionService _service = DeviceSessionService();

  bool _loading = true;
  String? _error;
  List<DeviceSession> _sessions = [];
  String? _currentSessionId;

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
      final (sessions, currentSessionId) = await _service.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _currentSessionId = currentSessionId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _remove(String id) async {
    await _service.removeSession(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linked Devices')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isCurrent = session.id == _currentSessionId;
                      return ListTile(
                        leading: Icon(isCurrent ? Icons.devices : Icons.smartphone),
                        title: Text(session.deviceName),
                        subtitle: Text('${session.platform} • Last active ${DateFormat.yMMMd().add_jm().format(session.lastActiveAt)}'),
                        trailing: isCurrent
                            ? const Chip(label: Text('Current'))
                            : IconButton(
                                icon: const Icon(Icons.logout),
                                onPressed: () => _remove(session.id),
                              ),
                      );
                    },
                  ),
                ),
    );
  }
}

