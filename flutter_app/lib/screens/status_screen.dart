import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/status_provider.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StatusProvider()..loadFeed(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Status / Stories')),
        body: Consumer<StatusProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(child: Text(provider.error!));
            }
            if (provider.statuses.isEmpty) {
              return const Center(child: Text('No active stories yet'));
            }

            return ListView.builder(
              itemCount: provider.statuses.length,
              itemBuilder: (context, index) {
                final status = provider.statuses[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(status.user.username.isEmpty ? '?' : status.user.username[0].toUpperCase())),
                  title: Text(status.user.username),
                  subtitle: Text(status.caption.isEmpty ? status.mediaType.toUpperCase() : status.caption),
                  trailing: Text('${status.expiresAt.hour.toString().padLeft(2, '0')}:${status.expiresAt.minute.toString().padLeft(2, '0')}'),
                  onTap: () => provider.markViewed(status.id),
                );
              },
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      hintText: 'Share a text story...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<StatusProvider>(
                  builder: (_, provider, __) => IconButton.filled(
                    onPressed: () async {
                      final text = _captionController.text.trim();
                      if (text.isEmpty) return;
                      final ok = await provider.postText(text);
                      if (!mounted) return;
                      if (ok) _captionController.clear();
                    },
                    icon: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

