import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../providers/channel_provider.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  Future<void> _create(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isCommunity = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Create Channel / Community'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 8),
                  TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isCommunity,
                    onChanged: (v) => setDialogState(() => isCommunity = v),
                    title: const Text('Create as Community'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
            ],
          ),
        );
      },
    );

    if (created == true && context.mounted) {
      await context.read<ChannelProvider>().create(
            name: nameController.text.trim(),
            description: descController.text.trim(),
            isCommunity: isCommunity,
          );
    }
  }

  Future<void> _publish(BuildContext context, String channelId) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Publish update'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publish')),
        ],
      ),
    );

    if (ok == true) {
      final text = controller.text.trim();
      if (text.isNotEmpty && context.mounted) {
        await context.read<ChannelProvider>().publish(channelId, text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChannelProvider()..loadAll(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Channels & Communities'),
          actions: [
            Consumer<ChannelProvider>(
              builder: (context, provider, _) => IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.loadAll,
              ),
            ),
          ],
        ),
        body: Consumer<ChannelProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(child: Text(provider.error!));
            }

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(tabs: [Tab(text: 'My'), Tab(text: 'Discover')]),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _channelList(context, provider.myChannels, isDiscover: false),
                        _channelList(context, provider.discoverChannels, isDiscover: true),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _create(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _channelList(BuildContext context, List<Channel> channels, {required bool isDiscover}) {
    if (channels.isEmpty) {
      return Center(child: Text(isDiscover ? 'No channels found' : 'No subscriptions yet'));
    }

    final provider = context.read<ChannelProvider>();

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final latestText = channel.posts.isNotEmpty ? (channel.posts.first['text'] ?? '').toString() : '';

        return ListTile(
          leading: CircleAvatar(child: Text(channel.name.isEmpty ? '?' : channel.name[0].toUpperCase())),
          title: Text(channel.name),
          subtitle: Text('${channel.kind} • ${channel.subscriberCount} members${latestText.isEmpty ? '' : '\n$latestText'}'),
          isThreeLine: latestText.isNotEmpty,
          trailing: isDiscover
              ? FilledButton.tonal(onPressed: () => provider.join(channel.id), child: const Text('Join'))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.campaign_outlined),
                      onPressed: () => _publish(context, channel.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => provider.leave(channel.id),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

