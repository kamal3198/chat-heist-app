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
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final results = await contactProvider.searchUsers(query);
    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
      _searchError = contactProvider.error;
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
      case 'self':
        return 'You';
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
      case 'self':
        return Colors.blueGrey;
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
                            _searchError = null;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hint: Your own account appears as "You" and cannot be added as a contact.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                _searchError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      )
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
                          final subtitle = requestStatus == 'self'
                              ? 'This is your account'
                              : (user.isOnline ? 'Online' : 'Offline');

                          return ListTile(
                            leading: UserAvatar(
                              user: user,
                              radius: 28,
                              showOnlineIndicator: true,
                            ),
                            title: Text(user.username),
                            subtitle: Text(
                              subtitle,
                              style: TextStyle(
                                color: requestStatus == 'self'
                                    ? Colors.blueGrey
                                    : (user.isOnline ? Colors.green : Colors.grey),
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
