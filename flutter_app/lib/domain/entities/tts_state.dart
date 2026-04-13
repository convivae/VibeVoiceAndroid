import 'asr_result.dart';
import 'voice_info.dart';

/// TTS playback state enum (per 02-CONTEXT.md D-06).
enum TtsPlaybackState {
  /// No audio loaded, idle state.
  idle,

  /// Connecting to server and waiting for audio.
  loading,

  /// Audio is playing.
  playing,

  /// Audio is paused, buffer is preserved.
  paused,

  /// Playback has stopped, buffer is cleared.
  stopped,

  /// An error occurred.
  error,
}

/// Immutable TTS state for the TTS tab.
class TtsState {
  /// Current playback state.
  final TtsPlaybackState playbackState;

  /// Text being synthesized.
  final String text;

  /// Currently selected voice ID.
  final String voiceId;

  /// Currently selected voice name.
  final String voiceName;

  /// Playback progress (0.0 to 1.0).
  final double progress;

  /// Number of chunks received from server.
  final int receivedChunks;

  /// Estimated total chunks (from metadata).
  final int estimatedChunks;

  /// Number of chunks played.
  final int playedChunks;

  /// Total audio duration in milliseconds.
  final int totalDurationMs;

  /// Current playback position in milliseconds.
  final int currentPositionMs;

  /// Error message if in error state.
  final String? errorMessage;

  /// Available voices (from /voices endpoint or defaults).
  final List<VoiceInfo> availableVoices;

  /// WebSocket connection state (mirrors ASR pattern).
  final WsConnectionState connectionState;

  const TtsState({
    this.playbackState = TtsPlaybackState.idle,
    this.text = '',
    this.voiceId = 'zh_female_1',
    this.voiceName = '中文女声-温柔',
    this.progress = 0.0,
    this.receivedChunks = 0,
    this.estimatedChunks = 0,
    this.playedChunks = 0,
    this.totalDurationMs = 0,
    this.currentPositionMs = 0,
    this.errorMessage,
    this.availableVoices = const [],
    this.connectionState = WsConnectionState.disconnected,
  });

  /// Format duration display string (e.g., "00:30 / 01:00").
  String get durationDisplay {
    final currentSec = currentPositionMs ~/ 1000;
    final totalSec = totalDurationMs ~/ 1000;
    final currentMin = currentSec ~/ 60;
    final currentSecRem = currentSec % 60;
    final totalMin = totalSec ~/ 60;
    final totalSecRem = totalSec % 60;
    return '${currentMin.toString().padLeft(2, '0')}:${currentSecRem.toString().padLeft(2, '0')} / '
        '${totalMin.toString().padLeft(2, '0')}:${totalSecRem.toString().padLeft(2, '0')}';
  }

  /// Whether play button should be enabled.
  bool get canPlay =>
      playbackState == TtsPlaybackState.idle ||
      playbackState == TtsPlaybackState.stopped ||
      playbackState == TtsPlaybackState.error;

  /// Whether pause button should be enabled.
  bool get canPause => playbackState == TtsPlaybackState.playing;

  /// Whether stop button should be enabled.
  bool get canStop =>
      playbackState == TtsPlaybackState.playing ||
      playbackState == TtsPlaybackState.paused ||
      playbackState == TtsPlaybackState.loading;

  TtsState copyWith({
    TtsPlaybackState? playbackState,
    String? text,
    String? voiceId,
    String? voiceName,
    double? progress,
    int? receivedChunks,
    int? estimatedChunks,
    int? playedChunks,
    int? totalDurationMs,
    int? currentPositionMs,
    String? errorMessage,
    bool clearError = false,
    List<VoiceInfo>? availableVoices,
    WsConnectionState? connectionState,
  }) {
    return TtsState(
      playbackState: playbackState ?? this.playbackState,
      text: text ?? this.text,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      progress: progress ?? this.progress,
      receivedChunks: receivedChunks ?? this.receivedChunks,
      estimatedChunks: estimatedChunks ?? this.estimatedChunks,
      playedChunks: playedChunks ?? this.playedChunks,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      availableVoices: availableVoices ?? this.availableVoices,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}
