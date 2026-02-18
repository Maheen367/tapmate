import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';


class VideoCallScreen extends StatefulWidget {
  final String userName;
  final dynamic userAvatar; // Can be IconData or String

  const VideoCallScreen({
    super.key,
    required this.userName,
    required this.userAvatar,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  Duration _callDuration = Duration.zero;

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration = _callDuration + const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  void _endCall() {
    Navigator.pop(context);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: 'video_call_user',
          userName: widget.userName,
          userAvatar: widget.userAvatar is String ? widget.userAvatar : '👤',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textMain,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Remote video (full screen)
            Container(
              color: AppColors.accent.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.userAvatar is IconData)
                      Icon(
                        widget.userAvatar as IconData,
                        size: 100,
                        color: AppColors.lightSurface.withOpacity(0.8),
                      )
                    else if (widget.userAvatar is String)
                      Text(
                        widget.userAvatar as String,
                        style: const TextStyle(fontSize: 100),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isVideoOff ? 'Video is off' : 'Video calling...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.lightSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Local video preview (picture-in-picture)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.textMain.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                child: _isVideoOff
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam_off,
                        size: 40,
                        color: AppColors.lightSurface,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.lightSurface.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.7), AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.lightSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),

            // Call controls (bottom)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Control buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        backgroundColor: _isMuted ? Colors.red : AppColors.lightSurface.withOpacity(0.2),
                        onTap: _toggleMute,
                      ),

                      // Video button
                      _buildControlButton(
                        icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        label: _isVideoOff ? 'Turn on' : 'Turn off',
                        backgroundColor: _isVideoOff ? Colors.red : AppColors.lightSurface.withOpacity(0.2),
                        onTap: _toggleVideo,
                      ),

                      // Speaker button
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                        backgroundColor: AppColors.lightSurface.withOpacity(0.2),
                        onTap: _toggleSpeaker,
                      ),

                      // Camera switch button
                      _buildControlButton(
                        icon: Icons.cameraswitch,
                        label: 'Switch',
                        backgroundColor: AppColors.lightSurface.withOpacity(0.2),
                        onTap: _switchCamera,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // End call button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: AppColors.lightSurface,
                        size: 30,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Additional options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSmallButton(
                        icon: Icons.person,
                        onTap: _openProfile,
                      ),
                      const SizedBox(width: 20),
                      _buildSmallButton(
                        icon: Icons.chat,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 20),
                      _buildSmallButton(
                        icon: Icons.more_vert,
                        onTap: () {
                          _showMoreOptions();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Top info bar
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.textMain.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.lightSurface,
                        size: 24,
                      ),
                    ),
                  ),

                  // Call quality indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textMain.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Good',
                          style: TextStyle(
                            color: AppColors.lightSurface,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.lightSurface,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lightSurface,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.textMain.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.lightSurface,
          size: 24,
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.textMain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: AppColors.lightSurface),
              title: const Text(
                'Record Call',
                style: TextStyle(color: AppColors.lightSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording started'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.blur_on, color: AppColors.lightSurface),
              title: const Text(
                'Blur Background',
                style: TextStyle(color: AppColors.lightSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Background blurred'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view, color: AppColors.lightSurface),
              title: const Text(
                'Grid View',
                style: TextStyle(color: AppColors.lightSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Switched to grid view'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: AppColors.lightSurface),
              title: const Text(
                'Call Info',
                style: TextStyle(color: AppColors.lightSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCallInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCallInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.textMain,
        title: const Text(
          'Call Information',
          style: TextStyle(color: AppColors.lightSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Duration', _formatDuration(_callDuration)),
            _buildInfoRow('Connection', 'Stable'),
            _buildInfoRow('Video Quality', '720p HD'),
            _buildInfoRow('Audio Codec', 'Opus'),
            _buildInfoRow('Data Used', '45 MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.lightSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

