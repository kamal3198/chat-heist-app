import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/call_provider.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      await context.read<CallProvider>().loadCallHistory();
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  IconData _icon(String status) {
    switch (status) {
      case 'missed':
        return Icons.call_missed;
      case 'rejected':
        return Icons.call_end;
      case 'connected':
      case 'ended':
        return Icons.call;
      default:
        return Icons.phone_in_talk_outlined;
    }
  }

  Color _color(String status, BuildContext context) {
    switch (status) {
      case 'missed':
      case 'rejected':
        return Colors.red;
      case 'connected':
      case 'ended':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: Consumer<CallProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingHistory) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.callHistory.isEmpty) {
            return const Center(child: Text('No calls yet'));
          }

          return RefreshIndicator(
            onRefresh: provider.loadCallHistory,
            child: ListView.builder(
              itemCount: provider.callHistory.length,
              itemBuilder: (context, index) {
                final entry = provider.callHistory[index];
                final icon = _icon(entry.status);
                final color = _color(entry.status, context);
                final title = entry.isGroup ? 'Group Call' : entry.caller.username;
                final subtitle = '${entry.status.toUpperCase()} • ${DateFormat.yMMMd().add_jm().format(entry.startedAt)}';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: Text(
                    _formatDuration(entry.durationSeconds),
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

