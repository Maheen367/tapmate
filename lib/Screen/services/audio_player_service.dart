import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // Streams for UI updates
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<String?> currentUrlNotifier = ValueNotifier(null);

  void initialize() {
    _audioPlayer.onPositionChanged.listen((position) {
      positionNotifier.value = position;
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      durationNotifier.value = duration;
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _isPlaying = false;
      isPlayingNotifier.value = false;
      positionNotifier.value = Duration.zero;
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      isPlayingNotifier.value = _isPlaying;
    });
  }

  // Play voice from File - FIXED
  Future<void> playVoice(File audioFile) async {
    try {
      await stop();
      currentUrlNotifier.value = audioFile.path;

      // ✅ FIXED: Use audioFile.path (String) instead of audioFile (File)
      await _audioPlayer.play(DeviceFileSource(audioFile.path));

      debugPrint('▶️ Playing: ${audioFile.path}');
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      rethrow;
    }
  }

  // Alternative method if you want to play from path directly
  Future<void> playVoiceFromPath(String filePath) async {
    try {
      await stop();
      currentUrlNotifier.value = filePath;
      await _audioPlayer.play(DeviceFileSource(filePath));
      debugPrint('▶️ Playing: $filePath');
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      rethrow;
    }
  }

  // Play from URL
  Future<void> playFromUrl(String url) async {
    try {
      await stop();
      currentUrlNotifier.value = url;
      await _audioPlayer.play(UrlSource(url));
      debugPrint('▶️ Playing from URL: $url');
    } catch (e) {
      debugPrint('❌ Error playing from URL: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void dispose() {
    _audioPlayer.dispose();
    isPlayingNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    currentUrlNotifier.dispose();
  }
}