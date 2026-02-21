import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../models/user.dart';
import '../widgets/user_avatar.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final results = await contactProvider.searchUsers(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _handleRequestAction({
    required String userId,
    required String requestStatus,
    String? requestId,
  }) async {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    bool success = false;

    if (requestStatus == 'received') {
      if (requestId == null || requestId.isEmpty) {
        success = false;
      } else {
        success = await contactProvider.acceptRequest(requestId);
      }
    } else {
      success = await contactProvider.sendContactRequest(userId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? requestStatus == 'received'
                    ? 'Request accepted'
                    : 'Contact request sent'
                : contactProvider.error ?? 'Failed to send request',
          ),
        ),
      );

      if (success) {
        // Refresh search to update button states
        _searchUsers(_searchController.text);
      }
    }
  }

  String _getButtonText(String requestStatus) {
    switch (requestStatus) {
      case 'none':
        return 'Add Contact';
      case 'sent':
        return 'Request Sent';
      case 'received':
        return 'Accept Request';
      case 'accepted':
        return 'Already Contact';
      case 'blocked':
        return 'Blocked';
      default:
        return 'Add Contact';
    }
  }

  Color? _getButtonColor(BuildContext context, String requestStatus) {
    switch (requestStatus) {
      case 'sent':
        return Colors.grey;
      case 'received':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'blocked':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  bool _isButtonEnabled(String requestStatus) {
    return requestStatus == 'none' || requestStatus == 'received';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
          ),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Search for users'
                                  : 'No users found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Try a different username',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final userData = _searchResults[index];
                          final user = User.fromJson(userData);
                          final requestStatus = userData['requestStatus'] as String? ?? 'none';
                          final requestId = userData['requestId'] as String?;

                          return ListTile(
                            leading: UserAvatar(
                              user: user,
                              radius: 28,
                              showOnlineIndicator: true,
                            ),
                            title: Text(user.username),
                            subtitle: Text(
                              user.isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: user.isOnline
                                    ? Colors.green
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: _isButtonEnabled(requestStatus)
                                  ? () => _handleRequestAction(
                                        userId: user.id,
                                        requestStatus: requestStatus,
                                        requestId: requestId,
                                      )
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getButtonColor(context, requestStatus),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                _getButtonText(requestStatus),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
