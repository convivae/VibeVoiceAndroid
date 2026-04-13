import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/entities/voice_info.dart';
import '../../domain/entities/asr_result.dart';
import '../../services/websocket/tts_websocket_service.dart';
import '../../services/audio/tts_audio_player.dart';

/// TTS state notifier that manages playback state.
/// Coordinates between TtsWebSocketService and TtsAudioPlayer per D-06.
class TtsNotifier extends StateNotifier<TtsState> {
  final TtsWebSocketService _wsService;
  final TtsAudioPlayer _audioPlayer;

  StreamSubscription<TtsMessage>? _messageSubscription;
  StreamSubscription<WsConnectionState>? _connectionSubscription;
  Timer? _progressTimer;

  TtsNotifier(this._wsService, this._audioPlayer) : super(const TtsState()) {
    _init();
  }

  void _init() {
    // Listen to WebSocket messages
    _messageSubscription = _wsService.messageStream.listen(_onMessage);

    // Listen to connection state
    _connectionSubscription = _wsService.connectionStateAsStream.listen((connState) {
      state = state.copyWith(connectionState: connState);

      if (connState == WsConnectionState.failed) {
        state = state.copyWith(
          playbackState: TtsPlaybackState.error,
          errorMessage: '连接失败，请检查网络',
        );
      }
    });

    // Initialize audio player
    _audioPlayer.init();

    // Load default voices
    loadVoices();
  }

  void _onMessage(TtsMessage message) {
    switch (message) {
      case TtsMetadata():
        _onMetadata(message);
        break;
      case TtsAudioChunk():
        _onAudioChunk(message);
        break;
      case TtsDone():
        _onDone(message);
        break;
      case TtsErrorMessage():
        _onError(message);
        break;
    }
  }

  void _onMetadata(TtsMetadata metadata) {
    state = state.copyWith(
      estimatedChunks: metadata.estimatedChunks,
      totalDurationMs: metadata.estimatedDurationMs,
    );
  }

  void _onAudioChunk(TtsAudioChunk chunk) async {
    // Update received chunks
    state = state.copyWith(receivedChunks: chunk.chunkIndex + 1);

    // Notify audio player of chunk
    _audioPlayer.onChunkReceived(
      chunk.audioData.length,
      chunk.isFinal,
      state.estimatedChunks,
      chunk.chunkIndex,
    );

    // If first chunk, start playback (per D-05: 边收边播)
    if (chunk.chunkIndex == 0) {
      state = state.copyWith(playbackState: TtsPlaybackState.playing);
      _startProgressTimer();
    }

    // If is_final, mark as complete
    if (chunk.isFinal) {
      state = state.copyWith(
        playbackState: TtsPlaybackState.stopped,
        progress: 1.0,
      );
      _stopProgressTimer();
    }
  }

  void _onDone(TtsDone done) {
    state = state.copyWith(
      playbackState: TtsPlaybackState.stopped,
      totalDurationMs: done.totalDurationMs,
      progress: 1.0,
    );
    _stopProgressTimer();
  }

  void _onError(TtsErrorMessage error) {
    state = state.copyWith(
      playbackState: TtsPlaybackState.error,
      errorMessage: '${error.code}: ${error.message}',
    );
    _stopProgressTimer();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (state.playbackState == TtsPlaybackState.playing) {
        final positionMs = _audioPlayer.getPositionMs;
        final progress = state.estimatedChunks > 0
            ? state.receivedChunks / state.estimatedChunks
            : (state.totalDurationMs > 0
                ? positionMs / state.totalDurationMs
                : 0.0);

        _audioPlayer.onPositionUpdate(positionMs);

        state = state.copyWith(
          currentPositionMs: positionMs,
          progress: progress.clamp(0.0, 1.0),
        );
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Play text with selected voice (per D-05: 边收边播).
  Future<void> play(String text, String voiceId) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(
        playbackState: TtsPlaybackState.error,
        errorMessage: '请输入要合成的文本',
      );
      return;
    }

    // Stop any existing playback
    await _stopPlayback();

    // Update state
    state = state.copyWith(
      text: text,
      voiceId: voiceId,
      playbackState: TtsPlaybackState.loading,
      receivedChunks: 0,
      estimatedChunks: 0,
      progress: 0.0,
      currentPositionMs: 0,
      totalDurationMs: 0,
      clearError: true,
    );

    // Connect and start
    try {
      await _wsService.connect();
      _wsService.sendStart(text: text, voiceId: voiceId);
    } catch (e) {
      state = state.copyWith(
        playbackState: TtsPlaybackState.error,
        errorMessage: '连接失败: $e',
      );
    }
  }

  /// Pause playback (buffer preserved per D-07).
  void pause() {
    if (state.playbackState != TtsPlaybackState.playing) return;

    _audioPlayer.pause();
    state = state.copyWith(playbackState: TtsPlaybackState.paused);
    _stopProgressTimer();
  }

  /// Resume playback.
  void resume() {
    if (state.playbackState != TtsPlaybackState.paused) return;

    _audioPlayer.resume();
    state = state.copyWith(playbackState: TtsPlaybackState.playing);
    _startProgressTimer();
  }

  /// Stop playback immediately and disconnect (per D-08).
  Future<void> stop() async {
    await _stopPlayback();
  }

  Future<void> _stopPlayback() async {
    _stopProgressTimer();
    await _wsService.disconnect();
    await _audioPlayer.stop();

    state = state.copyWith(
      playbackState: TtsPlaybackState.stopped,
      receivedChunks: 0,
      progress: 0.0,
      currentPositionMs: 0,
    );
  }

  /// Change voice selection.
  void setVoice(String voiceId, String voiceName) {
    state = state.copyWith(
      voiceId: voiceId,
      voiceName: voiceName,
    );
  }

  /// Dismiss error message.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  /// Load available voices (uses defaults per D-03).
  Future<void> loadVoices() async {
    state = state.copyWith(
      availableVoices: VoiceInfo.defaultVoices,
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _stopProgressTimer();
    _wsService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// Main TTS provider.
final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  final wsService = TtsWebSocketService();
  final audioPlayer = TtsAudioPlayer();
  return TtsNotifier(wsService, audioPlayer);
});

/// Convenience providers.
final ttsPlaybackStateProvider = Provider<TtsPlaybackState>((ref) {
  return ref.watch(ttsProvider).playbackState;
});

final ttsProgressProvider = Provider<double>((ref) {
  return ref.watch(ttsProvider).progress;
});

final ttsDurationDisplayProvider = Provider<String>((ref) {
  return ref.watch(ttsProvider).durationDisplay;
});

final ttsErrorProvider = Provider<String?>((ref) {
  return ref.watch(ttsProvider).errorMessage;
});

final availableVoicesProvider = Provider<List<VoiceInfo>>((ref) {
  return ref.watch(ttsProvider).availableVoices;
});

/// Current TTS connection state (for screen-level display).
final ttsWsConnectionStateProvider = Provider<WsConnectionState>((ref) {
  return ref.watch(ttsProvider).connectionState;
});
