import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraCallService {
  static const String appId = "e5aa6c987ce4421db1ce9060231a5f8c";

  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  RtcEngine? _engine;

  // Initialize Agora
  Future<bool> initAgora() async {
    try {
      await [Permission.camera, Permission.microphone].request();

      _engine = createAgoraRtcEngine();
      await _engine?.initialize(RtcEngineContext(appId: appId));
      await _engine?.enableVideo();

      return true;
    } catch (e) {
      debugPrint('❌ Init error: $e');
      return false;
    }
  }

  // 🔥 Start Video Call (as CALLER)
  Future<void> startVideoCall({
    required BuildContext context,
    required String channelName,
    required String targetUserId,
    required String targetUserName,
    required String targetUserAvatar,
  }) async {
    if (_engine == null) {
      bool inited = await initAgora();
      if (!inited) return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            channelName: channelName,
            callerName: targetUserName,
            callerAvatar: targetUserAvatar,
            isVideoCall: true,
            engine: _engine!,
            isCaller: true, // 🔥 IMPORTANT: Ye CALLER hai
          ),
        ),
      );
    }
  }

  // 🔥 Start Voice Call (as CALLER)
  Future<void> startVoiceCall({
    required BuildContext context,
    required String channelName,
    required String targetUserId,
    required String targetUserName,
    required String targetUserAvatar,
  }) async {
    if (_engine == null) {
      bool inited = await initAgora();
      if (!inited) return;
    }

    await _engine?.disableVideo();

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            channelName: channelName,
            callerName: targetUserName,
            callerAvatar: targetUserAvatar,
            isVideoCall: false,
            engine: _engine!,
            isCaller: true, // 🔥 IMPORTANT: Ye CALLER hai
          ),
        ),
      );
    }
  }

  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
  }
}

// 📞 Incoming Call Screen
class IncomingCallScreen extends StatefulWidget {
  final String channelName;
  final String callerName;
  final String callerAvatar;
  final bool isVideoCall;
  final RtcEngine engine;
  final bool isCaller; // true for caller, false for receiver

  const IncomingCallScreen({
    Key? key,
    required this.channelName,
    required this.callerName,
    required this.callerAvatar,
    required this.isVideoCall,
    required this.engine,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _isCallAccepted = false;
  bool _isConnected = false;
  int? _remoteUid;
  Timer? _callTimer;
  int _callDuration = 0;

  // Call controls
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _setupEngine();

    // 🔥 Caller automatically join channel
    if (widget.isCaller) {
      debugPrint('✅ Caller - Auto joining channel');
      _joinChannel();
    } else {
      debugPrint('📞 Receiver - Waiting for accept');
    }
  }

  void _setupEngine() {
    widget.engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('✅ Joined channel');
          setState(() {
            _isConnected = true;
          });
          _startCallTimer();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('✅ User joined: $remoteUid');
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('❌ User offline');
          setState(() => _remoteUid = null);
          _showCallEnded();
        },
      ),
    );
  }

  Future<void> _joinChannel() async {
    int uid = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000;

    await widget.engine.joinChannel(
      token: "",
      channelId: widget.channelName,
      uid: uid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: widget.isVideoCall && _isCallAccepted,
        publishMicrophoneTrack: _isCallAccepted,
        autoSubscribeAudio: true,
        autoSubscribeVideo: widget.isVideoCall,
      ),
    );
  }

  // 🟢 GREEN BUTTON - Accept Call (Sirf receiver ke liye)
  Future<void> _acceptCall() async {
    debugPrint('✅ Call accepted by receiver');
    setState(() {
      _isCallAccepted = true;
    });
    await _joinChannel();
  }

  // 🔴 RED BUTTON - Decline Call (Sirf receiver ke liye)
  void _declineCall() {
    debugPrint('❌ Call declined by receiver');
    widget.engine.leaveChannel();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call declined'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _showCallEnded() {
    _callTimer?.cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call ended'),
          backgroundColor: Colors.orange,
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    }
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    _callTimer?.cancel();
    widget.engine.leaveChannel();
    Navigator.pop(context);
  }

  void _toggleCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    widget.engine.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Caller info section
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Caller avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isConnected ? Colors.green : Colors.orange,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isConnected
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3)),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        backgroundImage: widget.callerAvatar.isNotEmpty
                            ? NetworkImage(widget.callerAvatar)
                            : null,
                        child: widget.callerAvatar.isEmpty
                            ? Text(
                          widget.callerName.isNotEmpty
                              ? widget.callerName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                          ),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Caller name
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Call status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (_isConnected
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isConnected
                            ? 'Connected'
                            : (widget.isCaller ? 'Ringing...' : 'Incoming Call...'),
                        style: TextStyle(
                          color: _isConnected ? Colors.green : Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Call timer
                    if (_isConnected) ...[
                      const SizedBox(height: 10),
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 🟢🔴 RECEIVER - Accept/Decline Buttons
            if (!widget.isCaller && !_isCallAccepted) ...[
              const Spacer(flex: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 🔴 Decline button
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red,
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.call_end, color: Colors.white, size: 35),
                            onPressed: _declineCall,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Decline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // 🟢 Accept button
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green,
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              widget.isVideoCall ? Icons.videocam : Icons.call,
                              color: Colors.white,
                              size: 35,
                            ),
                            onPressed: _acceptCall,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.isVideoCall ? 'Accept Video' : 'Accept',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
            ],

            // 🔴 CALLER - End Call button
            if (widget.isCaller && !_isConnected)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red,
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 35),
                        onPressed: _endCall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'End Call',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Call controls (after connected)
            if (_isCallAccepted && _isConnected)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute button
                        _buildControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          color: _isMuted ? Colors.red : Colors.white,
                          onTap: () {
                            setState(() => _isMuted = !_isMuted);
                            widget.engine.muteLocalAudioStream(_isMuted);
                          },
                        ),

                        // End call button
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                            onPressed: _endCall,
                          ),
                        ),

                        // Speaker/Camera button
                        widget.isVideoCall
                            ? _buildControlButton(
                          icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                          label: _isCameraOn ? 'Video On' : 'Video Off',
                          color: _isCameraOn ? Colors.white : Colors.red,
                          onTap: () {
                            setState(() => _isCameraOn = !_isCameraOn);
                            widget.engine.muteLocalVideoStream(!_isCameraOn);
                          },
                        )
                            : _buildControlButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                          color: _isSpeakerOn ? Colors.white : Colors.red,
                          onTap: () {
                            setState(() => _isSpeakerOn = !_isSpeakerOn);
                            widget.engine.setEnableSpeakerphone(_isSpeakerOn);
                          },
                        ),
                      ],
                    ),
                    // Camera flip button
                    if (widget.isVideoCall)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _buildControlButton(
                          icon: Icons.flip_camera_ios,
                          label: 'Flip Camera',
                          color: Colors.white,
                          onTap: _toggleCamera,
                          isSmall: true,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSmall ? 60 : 70,
          height: isSmall ? 60 : 70,
          decoration: BoxDecoration(
            color: Colors.grey[800]?.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: isSmall ? 28 : 32),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }
}