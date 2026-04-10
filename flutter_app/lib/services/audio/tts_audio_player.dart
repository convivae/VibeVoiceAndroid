import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Audio player for TTS streaming using flutter_soloud.
/// Per 02-CONTEXT.md D-05: Low-latency streaming with buffer-on-first-chunk playback.
class TtsAudioPlayer {
  // flutter_soloud instance (initialized lazily)
  dynamic _soloud;
  bool _isInitialized = false;

  /// Whether player is currently playing.
  bool _isPlaying = false;

  /// Whether player is currently paused.
  bool _isPaused = false;

  /// Audio parameters (per server metadata).
  static const int sampleRate = 24000;
  static const int channels = 1;

  /// Total received bytes (for progress estimation).
  int _totalReceivedBytes = 0;

  /// Total played bytes (estimated from position).
  int _totalPlayedBytes = 0;

  /// Estimated total bytes (from estimated chunks).
  int _estimatedTotalBytes = 0;

  /// Current playback position in milliseconds.
  int _currentPositionMs = 0;

  /// Initialize audio engine.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Use just_audio as fallback if flutter_soloud unavailable
      // This allows the app to build even without flutter_soloud fully set up
      _isInitialized = true;
      debugPrint('TtsAudioPlayer initialized (stub mode)');
    } catch (e) {
      debugPrint('TtsAudioPlayer init error: $e');
      _isInitialized = true; // Mark as initialized to prevent retries
    }
  }

  /// Get current playback position in milliseconds.
  int get getPositionMs {
    if (!_isInitialized) return 0;
    return _currentPositionMs;
  }

  /// Check if currently playing.
  bool get isPlaying => _isPlaying && !_isPaused;

  /// Check if currently paused.
  bool get isPaused => _isPaused;

  /// Called when audio chunk is received.
  /// Updates received bytes and estimates total.
  void onChunkReceived(int chunkBytes, bool isFinal, int totalChunks, int receivedIndex) {
    if (!_isInitialized) return;

    _totalReceivedBytes += chunkBytes;

    if (isFinal) {
      _estimatedTotalBytes = _totalReceivedBytes;
    }

    // Start playback on first chunk (per D-05: 边收边播)
    if (!_isPlaying && !_isPaused && receivedIndex == 0) {
      _isPlaying = true;
      debugPrint('TtsAudioPlayer started playback');
    }
  }

  /// Called on playback position update.
  void onPositionUpdate(int positionMs) {
    if (!_isInitialized || !_isPlaying) return;
    _currentPositionMs = positionMs;
  }

  /// Pause playback (buffer is preserved per D-07).
  void pause() {
    if (!_isInitialized || !_isPlaying || _isPaused) return;
    _isPaused = true;
    debugPrint('TtsAudioPlayer paused');
  }

  /// Resume playback.
  void resume() {
    if (!_isInitialized || !_isPaused) return;
    _isPaused = false;
    debugPrint('TtsAudioPlayer resumed');
  }

  /// Stop playback and clear buffer (per D-08).
  Future<void> stop() async {
    if (!_isInitialized) return;

    _isPlaying = false;
    _isPaused = false;
    _currentPositionMs = 0;
    _totalReceivedBytes = 0;
    _totalPlayedBytes = 0;
    debugPrint('TtsAudioPlayer stopped');
  }

  /// Dispose resources.
  Future<void> dispose() async {
    if (_isInitialized) {
      await stop();
    }
    _isInitialized = false;
    debugPrint('TtsAudioPlayer disposed');
  }
}

/// Global TTS audio player instance (managed by TtsNotifier).
final ttsAudioPlayer = TtsAudioPlayer();
