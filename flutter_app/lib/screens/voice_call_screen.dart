import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/call_provider.dart';

class VoiceCallScreen extends StatefulWidget {
  final String title;
  final bool isGroup;
  final List<User> participants;
  final Future<void> Function() onEndCall;

  const VoiceCallScreen({
    super.key,
    required this.title,
    required this.isGroup,
    required this.participants,
    required this.onEndCall,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _timerStarted = false;
  bool _didAutoClose = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerOnce() {
    if (_timerStarted) return;
    _timerStarted = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds++;
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _statusText(String state) {
    switch (state) {
      case 'ringing':
        return 'Ringing...';
      case 'connected':
        return 'Connected';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Rejected';
      case 'ended':
        return 'Call ended';
      default:
        return 'Connecting...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final callState = callProvider.callState;
    final isMuted = callProvider.isMuted;
    final isSpeakerOn = callProvider.isSpeakerOn;

    if (callProvider.isConnectedCall) {
      _startTimerOnce();
    }

    if ((callState == 'ended' || callState == 'missed' || callState == 'rejected') &&
        !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.teal,
              child: Text(
                widget.title.isNotEmpty ? widget.title[0].toUpperCase() : 'C',
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isGroup ? 'Group voice call' : 'Voice call',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText(callState),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDuration(_seconds),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              isMuted ? 'Microphone muted' : 'Microphone active',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              isSpeakerOn ? 'Speaker active' : 'Earpiece mode',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (widget.isGroup)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.participants
                      .map((user) => Chip(
                            label: Text(user.username),
                            backgroundColor: Colors.white10,
                            labelStyle: const TextStyle(color: Colors.white),
                          ))
                      .toList(),
                ),
              ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(
                  icon: isMuted ? Icons.mic_off : Icons.mic,
                  label: isMuted ? 'Unmute' : 'Mute',
                  onTap: () => callProvider.toggleMute(),
                ),
                _controlButton(
                  icon: isSpeakerOn ? Icons.volume_up : Icons.hearing,
                  label: isSpeakerOn ? 'Speaker' : 'Earpiece',
                  onTap: () => callProvider.toggleSpeaker(),
                ),
                _controlButton(
                  icon: Icons.call_end,
                  label: 'End',
                  danger: true,
                  onTap: () async {
                    await widget.onEndCall();
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: danger ? Colors.red : Colors.white24,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
