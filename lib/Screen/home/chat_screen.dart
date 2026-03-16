import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/home/video_call_screen.dart';
import 'package:tapmate/Screen/services/chat_service.dart';
import 'package:tapmate/Screen/services/audio_player_service.dart';
import 'package:tapmate/Screen/home/video_player_screen.dart';
// 🔥 Agora Call Service
import '../../auth_provider.dart';
import '../../theme_provider.dart';

import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import '../../utils/settings_provider.dart';
import '../services/call_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialChatId;
  final String? initialUserId;
  final String? initialUserName;
  final String? initialUserAvatar;

  const ChatScreen({
    super.key,
    this.initialChatId,
    this.initialUserId,
    this.initialUserName,
    this.initialUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  final ChatService _chatService = ChatService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final ImagePicker _imagePicker = ImagePicker();

  // 🔥 Agora Call Service instance
  final AgoraCallService _callService = AgoraCallService();

  String _currentChatId = "";
  String _currentUserId = "";
  Map<String, dynamic> _currentChatUser = {};
  List<Map<String, dynamic>> _chatUsers = [];
  bool _isLoading = true;

  bool _isEmojiPickerVisible = false;
  final FocusNode _messageFocusNode = FocusNode();

  // For calls tab
  int _missedCallsCount = 0;

  // Add sending flag to prevent double messages
  bool _isSending = false;
  bool _isSendingMedia = false;

  // Track processed message IDs to prevent duplicates
  final Set<String> _processedMessageIds = {};

  // Voice recording variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  bool _isUploadingVoice = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Waveform animation variables
  final List<double> _waveformHeights = List.filled(30, 5.0);
  Timer? _waveformTimer;
  final Random _random = Random();

  // 👇 BLOCK USER VARIABLES
  bool _isBlocked = false;
  bool _isBlocker = false;
  bool _isCheckingBlock = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize audio player
    _audioPlayerService.initialize();

    if (widget.initialChatId != null && widget.initialUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openChatWithUser(
          widget.initialChatId!,
          widget.initialUserId!,
          widget.initialUserName ?? 'User',
          widget.initialUserAvatar ?? '👤',
        );
      });
    } else {
      _initializeChat();
    }

    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        setState(() {
          _isEmojiPickerVisible = false;
        });
      }
    });

    // Listen to missed calls
    _chatService.getUnreadMissedCallsCount().listen((count) {
      if (mounted) {
        setState(() {
          _missedCallsCount = count;
        });
      }
    });

    // Check and request permissions for recording
    _checkPermissions();
  }

  // 👇 ADD THIS FUNCTION - Check block status
  Future<void> _checkBlockStatus() async {
    if (_currentUserId.isEmpty) {
      setState(() => _isCheckingBlock = false);
      return;
    }

    try {
      final isBlocked = await _chatService.isUserBlocked(_currentUserId);
      final isBlocker = await _chatService.isUserBlocker(_currentUserId);

      if (mounted) {
        setState(() {
          _isBlocked = isBlocked;
          _isBlocker = isBlocker;
          _isCheckingBlock = false;
        });
      }
    } catch (e) {
      print('Error checking block status: $e');
      setState(() => _isCheckingBlock = false);
    }
  }

  // Check recording permissions
  Future<void> _checkPermissions() async {
    try {
      PermissionStatus micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        print('❌ Microphone permission denied');
      }

      // Also request storage permission for Android
      if (Platform.isAndroid) {
        PermissionStatus storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          print('❌ Storage permission denied');
        }
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  void _openChatWithUser(
      String chatId,
      String userId,
      String userName,
      String userAvatar,
      ) {
    setState(() {
      _currentChatId = chatId;
      _currentUserId = userId;
      _currentChatUser = {
        'chatId': chatId,
        'userId': userId,
        'name': userName,
        'avatar': userAvatar,
        'profilePic': null,
      };
      _isLoading = false;
      // Clear processed IDs when switching chats
      _processedMessageIds.clear();
    });

    _chatService.markMessagesAsRead(chatId);

    // 👇 Check block status when opening chat
    _checkBlockStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _messageFocusNode.dispose();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayerService.dispose();

    // 🔥 Dispose call service
    _callService.dispose();

    _chatService.updateOnlineStatus(false);
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _chatService.updateOnlineStatus(true);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _openChat(Map<String, dynamic> user) {
    setState(() {
      _currentChatId = user['chatId'];
      _currentUserId = user['userId'];
      _currentChatUser = user;
      // Clear processed IDs when opening new chat
      _processedMessageIds.clear();
    });

    _chatService.markMessagesAsRead(_currentChatId);

    // 👇 Check block status when opening chat
    _checkBlockStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _goBackToChatList() {
    setState(() {
      _currentChatId = "";
      _currentUserId = "";
      _currentChatUser = {};
      _isEmojiPickerVisible = false;
      // Clear processed IDs when going back
      _processedMessageIds.clear();
    });
  }

  // 👇 UPDATE _sendMessage function with block checks
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentChatId.isEmpty || _isSending) return;

    // 👇 BLOCK CHECKS
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have blocked this user. Unblock to send messages.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot message this user.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _isSending = true;

    try {
      await _chatService.sendMessage(_currentChatId, message);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isSending = false;
      }
    }
  }

  // Start recording voice message
  Future<void> _startRecording() async {
    // 👇 BLOCK CHECK
    if (_isBlocked || _isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBlocked ? 'You have blocked this user' : 'You cannot message this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Check permission
      PermissionStatus status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission denied'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Check if already recording
      if (await _audioRecorder.isRecording()) {
        return;
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording with correct parameters
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = filePath;
        _recordingDuration = 0;
      });

      // Start timer to update recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isRecording && mounted) {
          setState(() {
            _recordingDuration++;
          });
        } else {
          timer.cancel();
        }
      });

      // Start waveform animation timer
      _startWaveformAnimation();

    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Waveform animation
  void _startWaveformAnimation() {
    _waveformTimer?.cancel();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        for (int i = 0; i < _waveformHeights.length; i++) {
          // Random heights between 5 and 25 to simulate voice
          _waveformHeights[i] = 5 + _random.nextInt(20).toDouble();
        }
      });
    });
  }

  // Stop recording and send voice message
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording || _currentChatId.isEmpty) return;

    _recordingTimer?.cancel();
    _waveformTimer?.cancel();

    setState(() {
      _isUploadingVoice = true;
      _isRecording = false;
    });

    try {
      final path = await _audioRecorder.stop();
      if (path != null && mounted) {
        File audioFile = File(path);
        if (await audioFile.exists()) {
          // Get file size
          final fileSize = await audioFile.length();

          // Don't send empty or too large files (max 5MB)
          if (fileSize > 5 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice message too large (max 5MB)'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          if (fileSize < 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording too short'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // Upload and send voice message with duration
          await _chatService.sendVoiceMessage(
            _currentChatId,
            audioFile,
            duration: _recordingDuration,
          );

          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploadingVoice = false;
        _recordingPath = null;
        _recordingDuration = 0;
      });
    }
  }

  // Cancel recording
  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();

    try {
      await _audioRecorder.stop();
      if (_recordingPath != null) {
        File(_recordingPath!).delete();
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    } finally {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = 0;
      });
    }
  }

  // Play voice message
  Future<void> _playVoiceMessage(String audioUrl) async {
    if (audioUrl.isEmpty) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download from Cloudinary
      File? audioFile = await _chatService.downloadVoiceMessage(audioUrl);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (audioFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download voice message'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Play the audio - Pass File object directly
      await _audioPlayerService.playVoice(audioFile);

      // Show playing indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.play_arrow, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Playing voice message...'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    // 👇 BLOCK CHECK
    if (_isBlocked || _isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBlocked ? 'You have blocked this user' : 'You cannot message this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() => _isSendingMedia = true);

        File imageFile = File(pickedFile.path);
        await _chatService.sendImageMessage(_currentChatId, imageFile);

        setState(() => _isSendingMedia = false);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _isSendingMedia = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Pick video from gallery
  Future<void> _pickVideo() async {
    // 👇 BLOCK CHECK
    if (_isBlocked || _isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBlocked ? 'You have blocked this user' : 'You cannot message this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (pickedFile != null && mounted) {
        setState(() => _isSendingMedia = true);

        File videoFile = File(pickedFile.path);
        await _chatService.sendVideoMessage(_currentChatId, videoFile);

        setState(() => _isSendingMedia = false);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _isSendingMedia = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Take photo with camera
  Future<void> _takePhoto() async {
    // 👇 BLOCK CHECK
    if (_isBlocked || _isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBlocked ? 'You have blocked this user' : 'You cannot message this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() => _isSendingMedia = true);

        File imageFile = File(pickedFile.path);
        await _chatService.sendImageMessage(_currentChatId, imageFile);

        setState(() => _isSendingMedia = false);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _isSendingMedia = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Record video with camera
  Future<void> _recordVideo() async {
    // 👇 BLOCK CHECK
    if (_isBlocked || _isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBlocked ? 'You have blocked this user' : 'You cannot message this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 1),
      );

      if (pickedFile != null && mounted) {
        setState(() => _isSendingMedia = true);

        File videoFile = File(pickedFile.path);
        await _chatService.sendVideoMessage(_currentChatId, videoFile);

        setState(() => _isSendingMedia = false);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _isSendingMedia = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record video: $e'), backgroundColor: Colors.red),
      );
    }
  }

// 🔥 ULTIMATE FIXED: Document picker with guaranteed working
  Future<void> _pickDocument() async {
    // 👇 BLOCK CHECK
    if (_isBlocked || _isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBlocked ? 'You have blocked this user' : 'You cannot message this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isSendingMedia = true);

      FilePickerResult? result;
      String? errorMessage;

      // METHOD 1: withData true (Android 11+)
      try {
        print('📁 Trying method 1 (withData)...');
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx',
            'ppt', 'pptx', 'zip', 'rar', 'jpg', 'jpeg', 'png'
          ],
          allowMultiple: false,
          withData: true,
        );
        if (result != null) print('✅ Method 1 succeeded');
      } catch (e) {
        errorMessage = e.toString();
        print('❌ Method 1 failed: $e');
      }

      // METHOD 2: Without withData
      if (result == null) {
        try {
          print('📁 Trying method 2 (without withData)...');
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx',
              'ppt', 'pptx', 'zip', 'rar'
            ],
            allowMultiple: false,
          );
          if (result != null) print('✅ Method 2 succeeded');
        } catch (e) {
          print('❌ Method 2 failed: $e');
        }
      }

      // METHOD 3: Any file type
      if (result == null) {
        try {
          print('📁 Trying method 3 (any file)...');
          result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            allowMultiple: false,
          );
          if (result != null) print('✅ Method 3 succeeded');
        } catch (e) {
          print('❌ Method 3 failed: $e');
        }
      }

      // METHOD 4: Image picker as fallback
      if (result == null) {
        try {
          print('📁 Trying method 4 (image picker)...');
          final XFile? pickedFile = await _imagePicker.pickMedia();
          if (pickedFile != null) {
            final bytes = await pickedFile.readAsBytes();
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${pickedFile.name}');
            await tempFile.writeAsBytes(bytes);

            await _chatService.sendDocumentMessage(_currentChatId, tempFile);

            try { await tempFile.delete(); } catch (_) {}

            if (mounted) {
              setState(() => _isSendingMedia = false);
              _scrollToBottom();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📄 ${pickedFile.name} sent'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return;
          }
        } catch (e) {
          print('❌ Method 4 failed: $e');
        }
      }

      if (result != null && mounted) {
        PlatformFile file = result.files.first;

        // If we have bytes (Android 11+)
        if (file.bytes != null) {
          print('✅ Using bytes method');
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);

          // Verify file was created
          if (await tempFile.exists()) {
            print('✅ Temp file created: ${tempFile.path}');
            print('📏 Size: ${await tempFile.length()} bytes');

            await _chatService.sendDocumentMessage(_currentChatId, tempFile);
            try { await tempFile.delete(); } catch (_) {}
          }
        }
        // If we have path
        else if (file.path != null) {
          print('✅ Using path method');
          try {
            final bytes = await File(file.path!).readAsBytes();
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${file.name}');
            await tempFile.writeAsBytes(bytes);
            await _chatService.sendDocumentMessage(_currentChatId, tempFile);
            try { await tempFile.delete(); } catch (_) {}
          } catch (e) {
            print('❌ Error reading file: $e');
            throw Exception('Cannot read file');
          }
        }

        if (mounted) {
          setState(() => _isSendingMedia = false);
          _scrollToBottom();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📄 ${file.name} sent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isSendingMedia = false);

        // Show specific error message
        String userMessage = 'No file selected';
        if (errorMessage != null) {
          if (errorMessage.contains('permission')) {
            userMessage = 'Storage permission denied';
          } else if (errorMessage.contains('cancel')) {
            userMessage = 'Selection cancelled';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSendingMedia = false);
      print('❌ Document pick error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 NEW: Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
            'Please grant storage permission to pick documents. '
                'Go to app settings to enable permission.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Open document
  Future<void> _openDocument(String documentUrl, String fileName) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download document
      File? documentFile = await _chatService.downloadDocumentFile(documentUrl, fileName);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (documentFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download document'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if file exists
      if (!await documentFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show options to open/share
      _showDocumentOptions(documentFile);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🔥 UPDATED: Show document options with working features
  void _showDocumentOptions(File documentFile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share, color: AppColors.primary),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(context);
                await _shareDocument(documentFile);
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser, color: AppColors.primary),
              title: const Text('Open with...'),
              onTap: () {
                Navigator.pop(context);
                _openDocumentWith(documentFile);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 NEW: Share document
  Future<void> _shareDocument(File documentFile) async {
    try {
      final XFile file = XFile(documentFile.path);
      await Share.shareXFiles(
        [file],
        text: 'Check out this document',
      );
    } catch (e) {
      debugPrint('❌ Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing document'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 NEW: Open document with external app
  Future<void> _openDocumentWith(File documentFile) async {
    try {
      final result = await OpenFilex.open(documentFile.path);

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open this file type'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error opening: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method for file icons
  String _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '📕';
      case 'doc':
      case 'docx':
        return '📘';
      case 'xls':
      case 'xlsx':
        return '📗';
      case 'ppt':
      case 'pptx':
        return '📙';
      case 'txt':
        return '📄';
      case 'zip':
      case 'rar':
        return '🗜️';
      default:
        return '📎';
    }
  }

  // Show image preview
  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show video player
  void _showVideoPlayer(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
    });
    if (_isEmojiPickerVisible) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      _messageFocusNode.unfocus();
    } else {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    setState(() {
      _messageController.text = _messageController.text + emoji.emoji;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      String text = _messageController.text;
      if (text.isNotEmpty) {
        _messageController.text = text.substring(0, text.length - 1);
      }
    });
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteMessage(_currentChatId, messageId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete message: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _forwardMessage(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          children: [
            const Text(
              'Forward Message',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatService.getChats(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final users = snapshot.data!
                      .where((u) => u['userId'] != _currentUserId)
                      .toList();

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          backgroundImage: user['profilePic'] != null
                              ? NetworkImage(user['profilePic'])
                              : null,
                          child: user['profilePic'] == null
                              ? Text(
                            user['avatar'] ?? '👤',
                            style: const TextStyle(fontSize: 20),
                          )
                              : null,
                        ),
                        title: Text(user['name'] ?? 'Unknown'),
                        subtitle: Text('@${user['username'] ?? 'username'}'),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await _chatService.forwardMessage(
                              _currentChatId,
                              message['id'],
                              user['userId'],
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Message forwarded to ${user['name']}',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                  Text('Failed to forward message: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: userId,
          userName: _currentChatUser['name'] ?? 'User',
          userAvatar: _currentChatUser['avatar'] ?? '👤',
        ),
      ),
    );
  }


// 🔥 UPDATED: Video call method with Agora
  void _startVideoCall() async {
    // 👇 BLOCK CHECK
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call a blocked user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has blocked you'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String channelName = 'call_${_currentChatId}_${DateTime.now().millisecondsSinceEpoch}';

    // Get user avatar
    String userAvatar = _currentChatUser['profilePic'] ?? _currentChatUser['avatar'] ?? '';

    await _callService.startVideoCall(
      context: context,
      channelName: channelName,
      targetUserId: _currentUserId,
      targetUserName: _currentChatUser['name'] ?? 'User',
      targetUserAvatar: userAvatar,
    );

    // Call log in Firestore
    await _chatService.logCall(
      otherUserId: _currentUserId,
      callType: 'video',
      callStatus: 'completed',
      duration: 0,
    );
  }

// 🔥 UPDATED: Voice call method with Agora
  void _startVoiceCall() async {
    // 👇 BLOCK CHECK
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call a blocked user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isBlocker) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has blocked you'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String channelName = 'call_${_currentChatId}_${DateTime.now().millisecondsSinceEpoch}';

    // Get user avatar
    String userAvatar = _currentChatUser['profilePic'] ?? _currentChatUser['avatar'] ?? '';

    await _callService.startVoiceCall(
      context: context,
      channelName: channelName,
      targetUserId: _currentUserId,
      targetUserName: _currentChatUser['name'] ?? 'User',
      targetUserAvatar: userAvatar,
    );

    await _chatService.logCall(
      otherUserId: _currentUserId,
      callType: 'voice',
      callStatus: 'completed',
      duration: 0,
    );
  }

  void _showUserOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.videocam, color: AppColors.primary, size: 28),
              title: const Text('Video Call', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _startVideoCall();
              },
            ),
            ListTile(
              leading: Icon(Icons.call, color: Colors.green, size: 28),
              title: const Text('Voice Call', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _startVoiceCall();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red, size: 28),
              title: const Text(
                'Block User',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _blockUser();
              },
            ),
            ListTile(
              leading: Icon(Icons.report, color: Colors.orange, size: 28),
              title: const Text('Report User', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _reportUser();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.notifications_off,
                color: AppColors.primary,
                size: 28,
              ),
              title: const Text(
                'Mute Notifications',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _muteNotifications();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 👇 UPDATE _blockUser function
  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block ${_currentChatUser['name'] ?? 'this user'}?\n\n'
              'They will not be able to:\n'
              '• Send you messages\n'
              '• View your profile\n'
              '• Follow you\n'
              '• See your posts',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 👇 Use SettingsProvider to block user
                final settingsProvider = Provider.of<SettingsProvider>(
                    context,
                    listen: false
                );
                await settingsProvider.settingsService.blockUser(_currentUserId);

                setState(() => _isBlocked = true);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${_currentChatUser['name'] ?? 'User'} has been blocked'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to block user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please select a reason for reporting this user:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                hint: const Text('Select reason'),
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(
                      value: 'harassment', child: Text('Harassment')),
                  DropdownMenuItem(
                      value: 'inappropriate',
                      child: Text('Inappropriate content')),
                  DropdownMenuItem(value: 'fake', child: Text('Fake account')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() => selectedReason = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedReason == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a reason'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                Navigator.pop(context);
                try {
                  await _chatService.reportUser(
                    _currentUserId,
                    reason: selectedReason,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit report: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Submit Report',
                style: TextStyle(color: AppColors.lightSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _muteNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mute Notifications'),
        content: const Text('Mute notifications for this chat for 7 days?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.muteChat(_currentChatId, mute: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications muted for 7 days'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to mute notifications: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Mute',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
          'Are you sure you want to clear all messages in this conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.clearConversation(_currentChatId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conversation cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear conversation: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REQUEST HANDLERS ====================

  void _acceptRequest(String requestId, String senderId) async {
    try {
      await _chatService.acceptFriendRequest(requestId, senderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _rejectRequest(String requestId) async {
    try {
      await _chatService.rejectFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendFriendRequest(String userId) async {
    try {
      await _chatService.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== CALL HANDLERS ====================

  void _markMissedCallsAsRead() async {
    await _chatService.markMissedCallsAsRead();
    if (mounted) {
      setState(() {
        _missedCallsCount = 0;
      });
    }
  }

  // 🔥 UPDATED: Call user method
  void _callUser(String userId, String userName, String callType) async {
    String channelName = 'call_${_currentChatId}_${DateTime.now().millisecondsSinceEpoch}';

    // Get user avatar
    String userAvatar = _currentChatUser['profilePic'] ?? _currentChatUser['avatar'] ?? '';

    if (callType == 'video') {
      await _callService.startVideoCall(
        context: context,
        channelName: channelName,
        targetUserId: userId,
        targetUserName: userName,
        targetUserAvatar: userAvatar,
      );

      await _chatService.logCall(
        otherUserId: userId,
        callType: 'video',
        callStatus: 'completed',
        duration: 0,
      );
    } else {
      await _callService.startVoiceCall(
        context: context,
        channelName: channelName,
        targetUserId: userId,
        targetUserName: userName,
        targetUserAvatar: userAvatar,
      );

      await _chatService.logCall(
        otherUserId: userId,
        callType: 'voice',
        callStatus: 'completed',
        duration: 0,
      );
    }
  }

  Widget _buildNavItem(
      IconData icon,
      String label,
      bool isActive,
      BuildContext context,
      bool isDarkMode,
      ) {
    return GestureDetector(
      onTap: () {
        if (label == 'Home') {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (label == 'Discover') {
          Navigator.pushReplacementNamed(context, '/search');
        } else if (label == 'Feed') {
          Navigator.pushReplacementNamed(context, '/feed');
        } else if (label == 'Message') {
          // Already on chat
        } else if (label == 'Profile') {
          Navigator.pushReplacementNamed(context, '/profile');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? AppColors.primary
                : (isDarkMode ? Colors.grey[600]! : Colors.grey),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? AppColors.primary
                  : (isDarkMode ? Colors.grey[600]! : Colors.grey),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // 👇 ADD THIS FUNCTION - Blocked View
  Widget _buildBlockedView(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isBlocked ? Icons.block : Icons.do_not_disturb,
              size: 80,
              color: _isBlocked ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              _isBlocked ? 'You blocked this user' : 'You cannot message this user',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isBlocked
                  ? 'You have blocked this user. Unblock to start messaging again.'
                  : 'This user has blocked you. You cannot send messages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            if (_isBlocked)
              ElevatedButton.icon(
                onPressed: () async {
                  final provider = Provider.of<SettingsProvider>(
                      context,
                      listen: false
                  );
                  await provider.unblockUser(_currentUserId);
                  setState(() {
                    _isBlocked = false;
                    _isBlocker = false;
                  });
                },
                icon: const Icon(Icons.block_outlined),
                label: const Text('Unblock User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGuest = authProvider.isGuest;
    final isDarkMode = themeProvider.isDarkMode;

    if (isGuest) {
      return _buildGuestView(isDarkMode);
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor:
        isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDarkMode),
              if (_currentChatId.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : AppColors.lightSurface,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor:
                    isDarkMode ? Colors.grey[400]! : Colors.grey,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      const Tab(text: 'Chats'),
                      const Tab(text: 'Requests'),
                      Tab(
                        child: Stack(
                          children: [
                            const Text('Calls'),
                            if (_missedCallsCount > 0)
                              Positioned(
                                right: -8,
                                top: -8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _missedCallsCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _currentChatId.isEmpty
                    ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatsTab(isDarkMode),
                    _buildRequestsTab(isDarkMode),
                    _buildCallsTab(isDarkMode),
                  ],
                )
                    : _buildChatDetailView(isDarkMode), // 👈 This will handle blocked view
              ),
              if (_currentChatId.isEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : AppColors.lightSurface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          Icons.home_rounded,
                          'Home',
                          false,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.explore_rounded,
                          'Discover',
                          false,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.feed_rounded,
                          'Feed',
                          false,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.message_rounded,
                          'Message',
                          true,
                          context,
                          isDarkMode,
                        ),
                        _buildNavItem(
                          Icons.person_rounded,
                          'Profile',
                          false,
                          context,
                          isDarkMode,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestView(bool isDarkMode) {
    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                    isDarkMode ? AppColors.lightSurface : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please sign in to access messages and chat with other users.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(
                      color: AppColors.lightSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.lightSurface,
            ),
            onPressed: () {
              if (_currentChatId.isNotEmpty) {
                setState(() {
                  _isEmojiPickerVisible = false;
                });
                _goBackToChatList();
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          Expanded(
            child: Row(
              children: [
                if (_currentChatId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _viewUserProfile(_currentUserId),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.lightSurface,
                      backgroundImage: _currentChatUser['profilePic'] != null
                          ? NetworkImage(_currentChatUser['profilePic'])
                          : null,
                      child: _currentChatUser['profilePic'] == null
                          ? Text(
                        _currentChatUser['avatar'] ?? '👤',
                        style: const TextStyle(fontSize: 20),
                      )
                          : null,
                    ),
                  ),
                if (_currentChatId.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentChatId.isEmpty
                            ? "Messages"
                            : _currentChatUser['name'] ?? 'User',
                        style: const TextStyle(
                          color: AppColors.lightSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_currentChatId.isNotEmpty && !_isBlocked && !_isBlocker)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(_currentUserId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            bool isOnline = false;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var data = snapshot.data!.data();
                              if (data != null) {
                                Map<String, dynamic> userData =
                                data as Map<String, dynamic>;
                                isOnline = userData['isOnline'] ?? false;
                              }
                            }
                            return Text(
                              isOnline ? 'Online' : 'Offline',
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_currentChatId.isEmpty)
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.lightSurface),
              onPressed: () {
                Navigator.pushNamed(context, '/search');
              },
            )
          else if (!_isBlocked && !_isBlocker) // 👇 Only show options if not blocked
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.lightSurface),
              onSelected: (value) {
                if (value == 'video_call') {
                  _startVideoCall();
                } else if (value == 'voice_call') {
                  _startVoiceCall();
                } else if (value == 'clear_chat') {
                  _clearConversation();
                } else if (value == 'block') {
                  _blockUser();
                } else if (value == 'mute') {
                  _muteNotifications();
                } else if (value == 'report') {
                  _reportUser();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'video_call',
                  child: Row(
                    children: [
                      Icon(Icons.videocam, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Video Call'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'voice_call',
                  child: Row(
                    children: [
                      Icon(Icons.call, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Voice Call'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Mute Notifications'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Report User'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Block User'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChatsTab(bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color:
              isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search conversations...",
                      hintStyle: TextStyle(
                        color:
                        isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: isDarkMode
                          ? AppColors.lightSurface
                          : AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: SizedBox.shrink())
              : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getChats(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 10),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              List<Map<String, dynamic>> chats = snapshot.data!;

              if (_searchController.text.isNotEmpty) {
                chats = chats.where((chat) {
                  return chat['name'].toString().toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ) ||
                      chat['username'].toString().toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      );
                }).toList();
              }

              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: isDarkMode
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No conversations found'
                            : 'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.lightSurface
                              : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Try a different search term'
                            : 'Start a conversation with someone!',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]!
                              : Colors.grey[600]!,
                        ),
                      ),
                      if (_searchController.text.isEmpty) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/search'),
                          icon: const Icon(Icons.search),
                          label: const Text('Find People to Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return _buildChatListItem(chat, isDarkMode);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> chat, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _openChat(chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: chat['profilePic'] != null
                      ? NetworkImage(chat['profilePic'])
                      : null,
                  child: chat['profilePic'] == null
                      ? Text(
                    chat['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 24),
                  )
                      : null,
                ),
                if (chat['is_online'] == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? const Color(0xFF2C2C2C)
                              : AppColors.lightSurface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (chat['is_muted'] == true)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat['name']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.lightSurface
                                : AppColors.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat['last_message_time'] != null)
                        Text(
                          _formatTime(chat['last_message_time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['last_message']?.toString() ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[300]!
                                : Colors.grey[700]!,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((chat['unread_count'] ?? 0) > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat['unread_count'].toString(),
                            style: const TextStyle(
                              color: AppColors.lightSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(bool isDarkMode) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 60, color: Colors.red),
                const SizedBox(height: 10),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!;

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_disabled,
                  size: 80,
                  color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                ),
                const SizedBox(height: 20),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'When someone sends you a friend request, it will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/search'),
                  icon: const Icon(Icons.search),
                  label: const Text('Find People'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF2C2C2C)
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _viewUserProfile(request['sender_id']),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          backgroundImage: request['profilePic'] != null
                              ? NetworkImage(request['profilePic'])
                              : null,
                          child: request['profilePic'] == null
                              ? Text(
                            request['avatar'] ?? '👤',
                            style: const TextStyle(fontSize: 24),
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    request['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? AppColors.lightSurface
                                          : AppColors.accent,
                                    ),
                                  ),
                                ),
                                if (request['timestamp'] != null)
                                  Text(
                                    _formatRequestTime(request['timestamp']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                                    ),
                                  ),
                              ],
                            ),
                            if (request['username'] != null)
                              Text(
                                '@${request['username']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey[400]!
                                      : Colors.grey[600]!,
                                ),
                              ),
                            if (request['bio'] != null && request['bio'].isNotEmpty)
                              Text(
                                request['bio'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.grey[500]!
                                      : Colors.grey[700]!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptRequest(
                            request['request_id'],
                            request['sender_id'],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectRequest(
                            request['request_id'],
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// Helper method for request time
  String _formatRequestTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildCallsTab(bool isDarkMode) {
    return Column(
      children: [
        if (_missedCallsCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call_missed, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_missedCallsCount missed calls',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _markMissedCallsAsRead,
                  child: const Text('Mark as read'),
                ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getCallHistory(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 10),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final calls = snapshot.data!;

              if (calls.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.call_end,
                        size: 80,
                        color:
                        isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No call history',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.lightSurface
                              : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your call history will appear here',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]!
                              : Colors.grey[600]!,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: calls.length,
                itemBuilder: (context, index) {
                  final call = calls[index];
                  return _buildCallListItem(call, isDarkMode);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCallListItem(Map<String, dynamic> call, bool isDarkMode) {
    IconData callIcon;
    Color callColor;
    String statusText = '';

    if (call['call_type'] == 'video') {
      callIcon = Icons.videocam;
    } else {
      callIcon = Icons.call;
    }

    if (call['call_status'] == 'missed') {
      callColor = Colors.red;
      statusText = 'Missed';
    } else if (call['call_status'] == 'rejected') {
      callColor = Colors.orange;
      statusText = 'Rejected';
    } else {
      callColor = Colors.green;
      statusText = 'Completed';
    }

    String direction = call['is_outgoing'] ? 'Outgoing' : 'Incoming';
    String duration = call['duration'] > 0
        ? _chatService.formatDuration(call['duration'])
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage: call['profilePic'] != null
                ? NetworkImage(call['profilePic'])
                : null,
            child: call['profilePic'] == null
                ? Text(
              call['avatar'] ?? '👤',
              style: const TextStyle(fontSize: 20),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                    isDarkMode ? AppColors.lightSurface : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      callIcon,
                      size: 14,
                      color: callColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$direction • $statusText',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCallTime(call['timestamp']),
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                ),
              ),
              if (duration.isNotEmpty)
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 👇 UPDATE _buildChatDetailView with block checks
  Widget _buildChatDetailView(bool isDarkMode) {
    // 👇 Add block checks
    if (_isCheckingBlock) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isBlocked || _isBlocker) {
      return _buildBlockedView(isDarkMode);
    }

    return Column(
      children: [
        Expanded(
          child: _currentChatId.isEmpty
              ? const Center(child: Text('No chat selected'))
              : StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(
                'messages_${_currentChatId}_${DateTime.now().millisecondsSinceEpoch}'),
            stream: _chatService.getMessages(_currentChatId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 10),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final messages = snapshot.data!;

              final uniqueMessages = <Map<String, dynamic>>[];
              final seenIds = <String>{};

              for (var msg in messages) {
                final id = msg['id']?.toString() ?? '';
                if (!seenIds.contains(id)) {
                  seenIds.add(id);
                  uniqueMessages.add(msg);
                }
              }

              if (uniqueMessages.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[300]!,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.lightSurface
                                : AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Send a message to start the conversation!',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            _messageController.text = 'Hi there! 👋';
                            _sendMessage();
                          },
                          icon: const Icon(Icons.waving_hand),
                          label: const Text('Say Hello'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: uniqueMessages.length,
                itemBuilder: (context, index) {
                  final message = uniqueMessages[index];
                  final isSent = message['is_sent'] == true;

                  return _buildMessageBubble(
                    message,
                    isSent,
                    isDarkMode,
                    index,
                  );
                },
              );
            },
          ),
        ),

        // Message input with fixed heights
        _buildMessageInput(isDarkMode),

        if (_isEmojiPickerVisible)
          Container(
            height: 300,
            color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            child: EmojiPicker(
              onEmojiSelected: (Category? category, Emoji emoji) {
                _onEmojiSelected(emoji);
              },
              onBackspacePressed: _onBackspacePressed,
              config: const Config(),
            ),
          ),
      ],
    );
  }

  // Message Bubble Builder
  Widget _buildMessageBubble(
      Map<String, dynamic> message,
      bool isSent,
      bool isDarkMode,
      int index,
      ) {
    // Deleted message bubble for received messages
    if (message['is_deleted'] == true && !isSent) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage: _currentChatUser['profilePic'] != null
                    ? NetworkImage(_currentChatUser['profilePic'])
                    : null,
                child: _currentChatUser['profilePic'] == null
                    ? Text(
                  _currentChatUser['avatar']?.toString() ?? '👤',
                  style: const TextStyle(fontSize: 16),
                )
                    : null,
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                  isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'This message was deleted',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color:
                        isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Voice message bubble
    if (message['type'] == 'voice') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
          isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isSent)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: _currentChatUser['profilePic'] != null
                      ? NetworkImage(_currentChatUser['profilePic'])
                      : null,
                  child: _currentChatUser['profilePic'] == null
                      ? Text(
                    _currentChatUser['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 16),
                  )
                      : null,
                ),
              ),
            Flexible(
              child: GestureDetector(
                onTap: () => _playVoiceMessage(message['audioUrl'] ?? ''),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSent
                        ? AppColors.primary.withOpacity(0.9)
                        : (isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : Colors.grey[200]!),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSent ? 18 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.audio_file,
                            size: 24,
                            color: isSent ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Voice message',
                            style: TextStyle(
                              color: isSent ? Colors.white : AppColors.textMain,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDuration(message['duration'] ?? 0),
                            style: TextStyle(
                              fontSize: 11,
                              color: isSent
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatMessageTime(message['timestamp']),
                            style: TextStyle(
                              fontSize: 11,
                              color: isSent
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Media message bubble (image/video)
    if (message['type'] == 'media') {
      String mediaType = message['mediaType'] ?? 'image';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isSent)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: _currentChatUser['profilePic'] != null
                      ? NetworkImage(_currentChatUser['profilePic'])
                      : null,
                  child: _currentChatUser['profilePic'] == null
                      ? Text(
                    _currentChatUser['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 16),
                  )
                      : null,
                ),
              ),
            Flexible(
              child: GestureDetector(
                onTap: () {
                  if (mediaType == 'image') {
                    _showImagePreview(message['mediaUrl']);
                  } else {
                    _showVideoPlayer(message['mediaUrl']);
                  }
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isSent
                        ? AppColors.primary.withOpacity(0.9)
                        : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200]!),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSent ? 18 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Media preview
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                        child: mediaType == 'image'
                            ? Image.network(
                          message['mediaUrl'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 50),
                              ),
                            );
                          },
                        )
                            : Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.network(
                              message['mediaUrl'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                );
                              },
                            ),
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              mediaType == 'image' ? '📷 Image' : '🎥 Video',
                              style: TextStyle(
                                color: isSent ? Colors.white : AppColors.textMain,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatMessageTime(message['timestamp']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSent
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (isSent) ...[
                                  const SizedBox(width: 4),
                                  if (message['is_read'] == true)
                                    const Icon(Icons.done_all, size: 14, color: Colors.blue)
                                  else if (message['is_delivered'] == true)
                                    Icon(Icons.done_all, size: 14, color: isSent
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey)
                                  else
                                    Icon(Icons.done, size: 14, color: isSent
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Document message bubble
    if (message['type'] == 'document') {
      String fileName = message['documentName'] ?? 'Document';
      String fileExtension = message['documentExtension'] ?? 'file';
      String fileIcon = _getFileIcon(fileExtension);
      int fileSize = message['documentSize'] ?? 0;
      String sizeText = fileSize > 0 ? '${(fileSize / 1024).toStringAsFixed(1)} KB' : '';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isSent)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: _currentChatUser['profilePic'] != null
                      ? NetworkImage(_currentChatUser['profilePic'])
                      : null,
                  child: _currentChatUser['profilePic'] == null
                      ? Text(
                    _currentChatUser['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 16),
                  )
                      : null,
                ),
              ),
            Flexible(
              child: GestureDetector(
                onTap: () => _openDocument(message['documentUrl'], fileName),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSent
                        ? AppColors.primary.withOpacity(0.9)
                        : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200]!),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isSent ? 18 : 4),
                      bottomRight: Radius.circular(isSent ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fileIcon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName.length > 20
                                      ? '${fileName.substring(0, 20)}...'
                                      : fileName,
                                  style: TextStyle(
                                    color: isSent ? Colors.white : AppColors.textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (sizeText.isNotEmpty)
                                  Text(
                                    sizeText,
                                    style: TextStyle(
                                      color: isSent
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📄 Document',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSent
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _formatMessageTime(message['timestamp']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSent
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey[600],
                                ),
                              ),
                              if (isSent) ...[
                                const SizedBox(width: 4),
                                if (message['is_read'] == true)
                                  const Icon(Icons.done_all, size: 14, color: Colors.blue)
                                else if (message['is_delivered'] == true)
                                  Icon(Icons.done_all, size: 14, color: isSent
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey)
                                else
                                  Icon(Icons.done, size: 14, color: isSent
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Regular message bubble
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _viewUserProfile(message['sender_id']),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: _currentChatUser['profilePic'] != null
                      ? NetworkImage(_currentChatUser['profilePic'])
                      : null,
                  child: _currentChatUser['profilePic'] == null
                      ? Text(
                    _currentChatUser['avatar']?.toString() ?? '👤',
                    style: const TextStyle(fontSize: 16),
                  )
                      : null,
                ),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message['type'] != 'voice' && message['type'] != 'media' && message['type'] != 'document') ...[
                          ListTile(
                            leading: Icon(Icons.content_copy,
                                color: AppColors.primary),
                            title: const Text('Copy'),
                            onTap: () {
                              _copyMessage(message['message'].toString());
                              Navigator.pop(context);
                            },
                          ),
                        ],
                        ListTile(
                          leading: Icon(Icons.share, color: AppColors.primary),
                          title: const Text('Forward'),
                          onTap: () {
                            _forwardMessage(message);
                            Navigator.pop(context);
                          },
                        ),
                        if (isSent)
                          ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: () {
                              _deleteMessage(message['id']);
                              Navigator.pop(context);
                            },
                          ),
                        ListTile(
                          leading: Icon(Icons.info_outline,
                              color: AppColors.primary),
                          title: const Text('Message Info'),
                          onTap: () {
                            Navigator.pop(context);
                            _showMessageInfo(message);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSent
                          ? AppColors.primary
                          : (isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : Colors.grey[200]!),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isSent ? 18 : 4),
                        bottomRight: Radius.circular(isSent ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message['is_forwarded'] == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share,
                                  size: 12,
                                  color: isSent
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Forwarded',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSent
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          message['message'].toString(),
                          style: TextStyle(
                            color: isSent
                                ? Colors.white
                                : (isDarkMode ? Colors.white : Colors.black87),
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMessageTime(message['timestamp']),
                              style: TextStyle(
                                fontSize: 11,
                                color: isSent
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey[600],
                              ),
                            ),
                            if (isSent) ...[
                              const SizedBox(width: 4),
                              if (message['is_read'] == true)
                                const Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: Colors.blue,
                                )
                              else if (message['is_delivered'] == true)
                                Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: isSent
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey,
                                )
                              else
                                Icon(
                                  Icons.done,
                                  size: 14,
                                  color: isSent
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey,
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isSent)
                    Positioned(
                      left: -6,
                      bottom: 0,
                      child: ClipPath(
                        clipper: _MessageTailClipper(isSent: false),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF2C2C2C)
                                : Colors.grey[200]!,
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: -6,
                      bottom: 0,
                      child: ClipPath(
                        clipper: _MessageTailClipper(isSent: true),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isSent) const SizedBox(width: 45),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showMessageInfo(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Sent', message['time'].toString()),
            if (message['is_delivered'] == true)
              _buildInfoRow('Delivered', message['time'].toString()),
            if (message['is_read'] == true)
              _buildInfoRow('Read', message['time'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 20),
          Text(value),
        ],
      ),
    );
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24 && date.day == now.day) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours < 48 && date.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Message Input with waveform and NO SHRINKING
  Widget _buildMessageInput(bool isDarkMode) {
    // 👇 If blocked, don't show input
    if (_isBlocked || _isBlocker) {
      return const SizedBox();
    }

    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        ),
        height: 90,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.stop, color: Colors.white, size: 24),
                onPressed: _stopRecordingAndSend,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        _waveformHeights.length,
                            (index) => Container(
                          width: 3,
                          height: _waveformHeights[index],
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white : AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _cancelRecording,
            ),
          ],
        ),
      );
    }

    if (_isUploadingVoice || _isSendingMedia) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        ),
        height: 60,
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isUploadingVoice ? 'Sending voice message...' : 'Sending media...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Normal input UI
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 44,
                maxHeight: 120,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      _isEmojiPickerVisible
                          ? Icons.keyboard
                          : Icons.emoji_emotions_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    onPressed: _toggleEmojiPicker,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.attach_file, color: AppColors.primary, size: 24),
                    onPressed: _showAttachmentOptions,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(
                          color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                          fontSize: 15,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: (text) {
                          setState(() {});
                        },
                        onTap: () {
                          if (_isEmojiPickerVisible) {
                            setState(() {
                              _isEmojiPickerVisible = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  if (_messageController.text.trim().isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.send, color: AppColors.primary, size: 24),
                      onPressed: _isSending ? null : _sendMessage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.mic_none, color: AppColors.primary, size: 24),
                      onPressed: _startRecording,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Attachment options with all media choices
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _showMediaPickerOptions();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _showCameraOptions();
              },
            ),
            ListTile(
              leading: Icon(Icons.mic, color: AppColors.primary),
              title: const Text('Voice Message'),
              onTap: () {
                Navigator.pop(context);
                _startRecording();
              },
            ),
            // Document option with actual functionality
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: AppColors.primary),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Media picker options
  void _showMediaPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image, color: AppColors.primary),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: AppColors.primary),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Camera options
  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: AppColors.primary),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _recordVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  String _formatCallTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _MessageTailClipper extends CustomClipper<Path> {
  final bool isSent;

  _MessageTailClipper({required this.isSent});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isSent) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}