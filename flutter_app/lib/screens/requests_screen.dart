import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/contact_provider.dart';
import '../widgets/user_avatar.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      await _loadRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    await contactProvider.loadPendingRequests();
    await contactProvider.loadSentRequests();
  }

  Future<void> _refresh() async {
    await _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedTab(),
          _buildSentTab(),
        ],
      ),
    );
  }

  Widget _buildReceivedTab() {
    return Consumer<ContactProvider>(
      builder: (context, contactProvider, child) {
        final requests = contactProvider.pendingRequests;

        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending requests',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 200), // For pull to refresh
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final sender = request.sender;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: UserAvatar(
                    user: sender,
                    radius: 28,
                    showOnlineIndicator: true,
                  ),
                  title: Text(sender.username),
                  subtitle: Text(
                    'Sent ${timeago.format(request.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Accept button
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () async {
                          final success = await contactProvider.acceptRequest(request.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success 
                                      ? 'Request accepted' 
                                      : contactProvider.error ?? 'Failed to accept',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      // Reject button
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () async {
                          final success = await contactProvider.rejectRequest(request.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success 
                                      ? 'Request rejected' 
                                      : contactProvider.error ?? 'Failed to reject',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSentTab() {
    return Consumer<ContactProvider>(
      builder: (context, contactProvider, child) {
        final requests = contactProvider.sentRequests;

        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.send,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No sent requests',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 200), // For pull to refresh
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final receiver = request.receiver;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: UserAvatar(
                    user: receiver,
                    radius: 28,
                    showOnlineIndicator: true,
                  ),
                  title: Text(receiver.username),
                  subtitle: Text(
                    'Sent ${timeago.format(request.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Chip(
                    label: const Text(
                      'Pending',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
