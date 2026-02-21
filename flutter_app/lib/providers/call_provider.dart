import 'dart:async';

import 'package:flutter/material.dart';

import '../models/call_log_entry.dart';
import '../models/call_session.dart';
import '../services/call_service.dart';
import '../services/permission_service.dart';
import '../services/socket_service.dart';
import '../services/voice_call_service.dart';

class CallProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  final CallService _callService = CallService();
  final VoiceCallService _voiceCallService = VoiceCallService();
  final PermissionService _permissionService = PermissionService();

  String? _currentUserId;
  CallSession? _activeCall;
  CallSession? _incomingCall;
  bool _isInCall = false;
  String _callState = 'idle'; // idle|ringing|connected|ended|missed|rejected
  String? _error;

  bool _isLoadingHistory = false;
  List<CallLogEntry> _callHistory = [];
  bool _listenersInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isEndingCall = false;
  bool _hasEndedCall = false;
  bool _voiceStarted = false;

  CallSession? get activeCall => _activeCall;
  CallSession? get incomingCall => _incomingCall;
  bool get isInCall => _isInCall;
  String get callState => _callState;
  bool get isConnectedCall => _callState == 'connected';
  String? get error => _error;
  bool get isLoadingHistory => _isLoadingHistory;
  List<CallLogEntry> get callHistory => _callHistory;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  void initialize(String userId) {
    if (_listenersInitialized) return;
    _currentUserId = userId;
    unawaited(_voiceCallService.initialize(userId));
    unawaited(_loadIceServers());

    _socketService.onIncomingCall((data) {
      final incoming = CallSession.fromJson(data).copyWith(status: 'ringing');
      _incomingCall = incoming;
      _callState = 'ringing';
      _hasEndedCall = false;
      _isEndingCall = false;
      _voiceStarted = false;
      notifyListeners();
    });

    _socketService.onCallInitiated((data) {
      _activeCall = CallSession.fromJson({
        ...data,
        'callerId': _currentUserId,
      }).copyWith(status: 'ringing');
      _isInCall = true;
      _callState = 'ringing';
      _hasEndedCall = false;
      _isEndingCall = false;
      _voiceStarted = false;
      notifyListeners();
    });

    _socketService.onCallAccepted((data) {
      final callId = data['callId']?.toString() ?? '';
      if (_activeCall != null && _activeCall!.callId == callId) {
        _activeCall = _activeCall!.copyWith(
          status: 'connected',
          connectedAt: DateTime.now(),
        );
      }
      _isInCall = true;
      _callState = 'connected';
      unawaited(_startVoiceForActiveCall());
      notifyListeners();
    });

    _socketService.onCallConnected((data) {
      final callId = data['callId']?.toString() ?? '';
      if (_activeCall != null && _activeCall!.callId == callId) {
        _activeCall = _activeCall!.copyWith(
          status: 'connected',
          connectedAt: DateTime.tryParse((data['connectedAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        );
      }
      _isInCall = true;
      _callState = 'connected';
      unawaited(_startVoiceForActiveCall());
      notifyListeners();
      loadCallHistory();
    });

    _socketService.onCallMissed((data) {
      final callId = data['callId']?.toString() ?? '';
      if (_activeCall?.callId == callId || _incomingCall?.callId == callId) {
        _activeCall = null;
        _incomingCall = null;
      }
      _isInCall = false;
      _callState = 'missed';
      unawaited(_cleanupVoice());
      notifyListeners();
      loadCallHistory();
    });

    _socketService.onCallRejected((_) {
      _isInCall = false;
      _activeCall = null;
      _incomingCall = null;
      _callState = 'rejected';
      _hasEndedCall = true;
      _isEndingCall = false;
      unawaited(_cleanupVoice());
      notifyListeners();
      loadCallHistory();
    });

    _socketService.onCallEnded((data) {
      final callId = data['callId']?.toString() ?? '';
      if (_activeCall?.callId == callId || _incomingCall?.callId == callId) {
        unawaited(_handleCallEnded(remote: true));
      }
    });

    loadCallHistory();
    _listenersInitialized = true;
  }

  Future<void> loadCallHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _callHistory = await _callService.getHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<CallSession?> startCall({
    required BuildContext context,
    required List<String> participantIds,
  }) async {
    if (_currentUserId == null) {
      _error = 'Call provider is not initialized';
      notifyListeners();
      return null;
    }

    if (!_socketService.isConnected) {
      _error = 'No network socket connection. Please wait and try again.';
      notifyListeners();
      return null;
    }

    final hasPermission = await _permissionService.ensureMicrophonePermission(context);
    if (!hasPermission) {
      _error = 'Microphone permission denied.';
      notifyListeners();
      return null;
    }

    final callId = 'call-${DateTime.now().microsecondsSinceEpoch}';
    final session = CallSession(
      callId: callId,
      callerId: _currentUserId!,
      participantIds: [_currentUserId!, ...participantIds],
      isGroup: participantIds.length > 1,
      startedAt: DateTime.now(),
      status: 'calling',
    );

    _activeCall = session;
    _isInCall = true;
    _callState = 'ringing';
    _error = null;
    _hasEndedCall = false;
    _isEndingCall = false;
    _voiceStarted = false;
    notifyListeners();

    _socketService.initiateCall(
      callId: callId,
      callerId: _currentUserId!,
      participantIds: participantIds,
      isGroup: participantIds.length > 1,
    );

    return session;
  }

  Future<bool> acceptIncomingCall(BuildContext context) async {
    if (_incomingCall == null || _currentUserId == null) return false;

    final hasPermission = await _permissionService.ensureMicrophonePermission(context);
    if (!hasPermission) {
      _error = 'Microphone permission denied.';
      notifyListeners();
      return false;
    }

    _activeCall = _incomingCall!.copyWith(
      status: 'connected',
      connectedAt: DateTime.now(),
    );
    _incomingCall = null;
    _isInCall = true;
    _callState = 'connected';
    _error = null;
    _hasEndedCall = false;
    _isEndingCall = false;
    _voiceStarted = false;
    notifyListeners();

    _socketService.acceptCall(
      callId: _activeCall!.callId,
      userId: _currentUserId!,
      participantIds: _activeCall!.participantIds,
    );

    await _startVoiceForActiveCall();
    return true;
  }

  Future<void> rejectIncomingCall() async {
    if (_incomingCall == null || _currentUserId == null) return;
    _socketService.rejectCall(
      callId: _incomingCall!.callId,
      userId: _currentUserId!,
      participantIds: _incomingCall!.participantIds,
    );
    _incomingCall = null;
    _isInCall = false;
    _callState = 'rejected';
    _hasEndedCall = true;
    _isEndingCall = false;
    await _cleanupVoice();
    notifyListeners();
    loadCallHistory();
  }

  Future<void> endCall() async {
    if (_activeCall == null || _currentUserId == null) return;
    if (_isEndingCall || _hasEndedCall) return;

    _isEndingCall = true;
    notifyListeners();

    try {
      _socketService.endCall(
        callId: _activeCall!.callId,
        userId: _currentUserId!,
        participantIds: _activeCall!.participantIds,
      );
      await _handleCallEnded(remote: false);
    } finally {
      _isEndingCall = false;
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _voiceCallService.setMuted(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _voiceCallService.setSpeakerOn(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> _startVoiceForActiveCall() async {
    if (_activeCall == null || _currentUserId == null) return;
    if (_voiceStarted) return;

    try {
      _voiceStarted = true;
      await _voiceCallService.startAudio(_activeCall!);
      await _voiceCallService.setMuted(_isMuted);
      await _voiceCallService.setSpeakerOn(_isSpeakerOn);
      _error = null;
      notifyListeners();
    } catch (_) {
      _voiceStarted = false;
      _error = 'Failed to access microphone/audio for this call.';
      notifyListeners();
    }
  }

  Future<void> _handleCallEnded({required bool remote}) async {
    if (_hasEndedCall) return;

    _hasEndedCall = true;
    _isInCall = false;
    _activeCall = null;
    _incomingCall = null;
    _callState = 'ended';
    await _cleanupVoice();
    notifyListeners();
    loadCallHistory();
  }

  Future<void> _cleanupVoice() async {
    _isMuted = false;
    _isSpeakerOn = true;
    _voiceStarted = false;
    await _voiceCallService.cleanup();
    await _voiceCallService.setSpeakerOn(_isSpeakerOn);
  }

  Future<void> _loadIceServers() async {
    try {
      final iceServers = await _callService.getIceServers();
      _voiceCallService.setIceServers(iceServers);
    } catch (_) {
      // fallback STUN remains in voice service
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketService.removeCallListeners();
    unawaited(_voiceCallService.cleanup());
    super.dispose();
  }
}
