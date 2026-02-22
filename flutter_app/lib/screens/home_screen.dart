import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/group_provider.dart';
import '../providers/message_provider.dart';
import '../config/api_config.dart';
import 'channels_screen.dart';
import 'call_history_screen.dart';
import 'login_screen.dart';
import 'chat_list_screen.dart';
import 'contacts_screen.dart';
import 'groups_screen.dart';
import 'requests_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'voice_call_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _usernameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  File? _selectedAvatarFile;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _usernameController.text = user?.username ?? '';
    _aboutController.text = user?.about ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _selectedAvatarFile = File(image.path);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.updateProfile(
      username: _usernameController.text.trim(),
      about: _aboutController.text.trim(),
      avatarFile: _selectedAvatarFile,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Profile updated' : authProvider.error ?? 'Update failed'),
      ),
    );

    if (success) {
      setState(() {
        _selectedAvatarFile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundImage: _selectedAvatarFile != null
                              ? FileImage(_selectedAvatarFile!)
                              : (user != null && user.avatar.isNotEmpty
                                  ? NetworkImage(ApiConfig.resolveMediaUrl(user.avatar)) as ImageProvider
                                  : null),
                          child: (user == null || user.avatar.isEmpty) && _selectedAvatarFile == null
                              ? const Icon(Icons.person, size: 52)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.username ?? 'User',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Member since ${user?.createdAt.year ?? ''}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aboutController,
              maxLength: 140,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'About',
                hintText: 'Write something about you',
                prefixIcon: Icon(Icons.info_outline),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: authProvider.isLoading ? null : _saveProfile,
                icon: const Icon(Icons.save),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _lastIncomingCallId;
  bool _providersInitialized = false;

  final List<Widget> _tabs = const [
    ChatListScreen(),
    ContactsScreen(),
    GroupsScreen(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  Future<void> _initializeProviders() async {
    if (!mounted || _providersInitialized) return;
    _providersInitialized = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      final userId = authProvider.currentUser!.id;
      await contactProvider.initialize(userId);
      if (!mounted) return;
      await groupProvider.loadGroups();
      if (!mounted) return;
      callProvider.initialize(userId);
      messageProvider.initialize(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final incomingCall = callProvider.incomingCall;

    if (incomingCall != null && incomingCall.callId != _lastIncomingCallId) {
      _lastIncomingCallId = incomingCall.callId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(incomingCall.isGroup ? 'Incoming Group Call' : 'Incoming Call'),
            content: const Text('Accept voice call?'),
            actions: [
              TextButton(
                onPressed: () async {
                  await callProvider.rejectIncomingCall();
                  Navigator.pop(context);
                },
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final accepted = await callProvider.acceptIncomingCall(context);
                  if (!accepted) return;
                  Navigator.pop(context);
                  final participants = incomingCall.participantIds
                      .map((id) => User(id: id, username: id == incomingCall.callerId ? 'Caller' : 'Participant', avatar: '', createdAt: DateTime.now()))
                      .toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VoiceCallScreen(
                        title: incomingCall.isGroup ? 'Group Call' : 'Voice Call',
                        isGroup: incomingCall.isGroup,
                        participants: participants,
                        onEndCall: () => callProvider.endCall(),
                      ),
                    ),
                  );
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatHeist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: 'Stories',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Channels',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Calls',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallHistoryScreen())),
          ),
          if (_selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestsScreen()));
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              } else if (value == 'logout') {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: null,
    );
  }
}


