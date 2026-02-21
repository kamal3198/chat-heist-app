import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call_session.dart';
import 'socket_service.dart';

class VoiceCallService {
  final SocketService _socketService = SocketService();

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  String? _currentUserId;
  String? _currentCallId;
  bool _listenersInitialized = false;
  bool _renderersInitialized = false;
  bool _muted = false;
  bool _speakerOn = true;

  List<Map<String, dynamic>> _iceServers = const [
    {'urls': ['stun:stun.l.google.com:19302']},
  ];

  bool get isMuted => _muted;
  bool get isSpeakerOn => _speakerOn;

  void setIceServers(List<Map<String, dynamic>> iceServers) {
    if (iceServers.isEmpty) return;
    _iceServers = iceServers;
  }

  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _ensureRenderers();
    await Helper.setSpeakerphoneOn(_speakerOn);

    if (_listenersInitialized) return;
    _socketService.onCallSignal((data) {
      unawaited(_handleCallSignal(data));
    });
    _listenersInitialized = true;
  }

  Future<void> startAudio(CallSession session) async {
    if (_currentUserId == null || session.callId.isEmpty) return;

    _currentCallId = session.callId;
    await _ensureRenderers();
    await _ensureLocalStream();

    final peers = session.participantIds.where((id) => id.isNotEmpty && id != _currentUserId).toSet();
    for (final peerId in peers) {
      await _ensurePeerConnection(peerId);
      if (_shouldInitiateOffer(_currentUserId!, peerId)) {
        await _createAndSendOffer(peerId);
      }
    }
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        track.enabled = !_muted;
      }
    }
  }

  Future<void> setSpeakerOn(bool value) async {
    _speakerOn = value;
    await Helper.setSpeakerphoneOn(_speakerOn);
  }

  Future<void> cleanup() async {
    _currentCallId = null;

    for (final connection in _peerConnections.values) {
      await connection.close();
    }
    _peerConnections.clear();
    _pendingCandidates.clear();

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      _localStream = null;
    }

    await _disposeRenderers();
  }

  Future<void> _ensureRenderers() async {
    if (_renderersInitialized) return;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _renderersInitialized = true;
  }

  Future<void> _disposeRenderers() async {
    if (!_renderersInitialized) return;
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    _renderersInitialized = false;
  }

  Future<void> _ensureLocalStream() async {
    if (_localStream != null) {
      await setMuted(_muted);
      return;
    }

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    _localStream = stream;
    _localRenderer.srcObject = stream;
    await setMuted(_muted);
  }

  Future<RTCPeerConnection> _ensurePeerConnection(String peerId) async {
    final existing = _peerConnections[peerId];
    if (existing != null) return existing;

    final connection = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        await connection.addTrack(track, stream);
      }
    }

    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null || _currentCallId == null || _currentUserId == null) return;
      _socketService.sendCallSignal(
        callId: _currentCallId!,
        fromUserId: _currentUserId!,
        toUserId: peerId,
        type: 'ice-candidate',
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    connection.onTrack = (event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
      }
    };

    _peerConnections[peerId] = connection;
    return connection;
  }

  Future<void> _createAndSendOffer(String peerId) async {
    final connection = await _ensurePeerConnection(peerId);
    final offer = await connection.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });
    await connection.setLocalDescription(offer);

    if (_currentCallId == null || _currentUserId == null) return;

    _socketService.sendCallSignal(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: peerId,
      type: 'offer',
      sdp: {'type': offer.type, 'sdp': offer.sdp},
    );
  }

  Future<void> _handleCallSignal(Map<String, dynamic> data) async {
    if (_currentUserId == null) return;

    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty) return;
    if (_currentCallId != null && _currentCallId != callId) return;
    _currentCallId = callId;

    final fromUserId = data['fromUserId']?.toString() ?? '';
    final toUserId = data['toUserId']?.toString() ?? '';
    if (fromUserId.isEmpty || toUserId != _currentUserId) return;

    final type = data['type']?.toString() ?? '';
    await _ensureLocalStream();
    final connection = await _ensurePeerConnection(fromUserId);

    if (type == 'offer') {
      final sdp = Map<String, dynamic>.from((data['sdp'] as Map?) ?? const {});
      final remote = RTCSessionDescription(
        sdp['sdp']?.toString(),
        sdp['type']?.toString() ?? 'offer',
      );
      await connection.setRemoteDescription(remote);
      await _drainPendingCandidates(fromUserId);

      final answer = await connection.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await connection.setLocalDescription(answer);

      _socketService.sendCallSignal(
        callId: callId,
        fromUserId: _currentUserId!,
        toUserId: fromUserId,
        type: 'answer',
        sdp: {'type': answer.type, 'sdp': answer.sdp},
      );
      return;
    }

    if (type == 'answer') {
      final sdp = Map<String, dynamic>.from((data['sdp'] as Map?) ?? const {});
      final remote = RTCSessionDescription(
        sdp['sdp']?.toString(),
        sdp['type']?.toString() ?? 'answer',
      );
      await connection.setRemoteDescription(remote);
      await _drainPendingCandidates(fromUserId);
      return;
    }

    if (type == 'ice-candidate') {
      final candidateMap = Map<String, dynamic>.from((data['candidate'] as Map?) ?? const {});
      final candidate = RTCIceCandidate(
        candidateMap['candidate']?.toString(),
        candidateMap['sdpMid']?.toString(),
        candidateMap['sdpMLineIndex'] is int
            ? candidateMap['sdpMLineIndex'] as int
            : int.tryParse(candidateMap['sdpMLineIndex']?.toString() ?? ''),
      );

      final remoteDescription = await connection.getRemoteDescription();
      if (remoteDescription == null) {
        _pendingCandidates.putIfAbsent(fromUserId, () => []).add(candidate);
      } else {
        await connection.addCandidate(candidate);
      }
    }
  }

  Future<void> _drainPendingCandidates(String peerId) async {
    final connection = _peerConnections[peerId];
    if (connection == null) return;

    final pending = _pendingCandidates.remove(peerId) ?? const [];
    for (final candidate in pending) {
      await connection.addCandidate(candidate);
    }
  }

  bool _shouldInitiateOffer(String localId, String remoteId) {
    return localId.compareTo(remoteId) < 0;
  }
}
