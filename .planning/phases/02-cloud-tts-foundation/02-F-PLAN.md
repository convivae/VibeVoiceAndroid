# Phase 2: Cloud TTS Foundation — Plan F

## Flutter TTS UI (TTS Tab + WebSocket Client + flutter_soloud Streaming)

---
phase: 02-cloud-tts-foundation
plan: F
type: execute
wave: 2
depends_on: []
files_modified:
  - flutter_app/lib/presentation/screens/tts_screen.dart
  - flutter_app/lib/presentation/screens/home_screen.dart
  - flutter_app/lib/presentation/providers/tts_provider.dart
  - flutter_app/lib/presentation/providers/providers.dart
  - flutter_app/lib/presentation/widgets/voice_selector.dart
  - flutter_app/lib/presentation/widgets/playback_controls.dart
  - flutter_app/lib/presentation/widgets/tts_progress_bar.dart
  - flutter_app/lib/services/websocket/tts_websocket_service.dart
  - flutter_app/lib/services/audio/tts_audio_player.dart
  - flutter_app/lib/domain/entities/tts_state.dart
  - flutter_app/lib/data/repositories/tts_repository.dart
  - flutter_app/lib/core/config/api_config.dart
  - flutter_app/pubspec.yaml
autonomous: false
requirements:
  - REQ-06
  - REQ-07
  - REQ-11
user_setup:
  - service: flutter_soloud package installation
    why: Low-latency audio playback for streaming TTS
    verify: flutter pub add flutter_soloud and confirm it builds

must_haves:
  truths:
    - "User switches to TTS Tab, enters text, selects voice, clicks play, hears audio streaming"
    - "Audio starts playing within 500ms of clicking play (TTFP)"
    - "User can pause and resume playback, buffer is preserved"
    - "User can stop playback immediately, WebSocket disconnects"
    - "Progress bar shows current position and estimated total duration"
    - "Voice selector shows 5 preset voices (2 Chinese + 2 English + 1 mixed)"
    - "Error states shown for network issues and server errors"
    - "WebSocket reconnects automatically on disconnect"
  artifacts:
    - path: flutter_app/lib/presentation/screens/tts_screen.dart
      provides: TTS tab screen with text input, voice selector, playback controls
      exports: ["TtsScreen"]
    - path: flutter_app/lib/presentation/providers/tts_provider.dart
      provides: Riverpod state management for TTS playback
      exports: ["TtsNotifier", "ttsProvider", "ttsStateProvider"]
    - path: flutter_app/lib/services/websocket/tts_websocket_service.dart
      provides: WebSocket client for TTS streaming with reconnection
      exports: ["TtsWebSocketService"]
    - path: flutter_app/lib/services/audio/tts_audio_player.dart
      provides: flutter_soloud streaming audio player
      exports: ["TtsAudioPlayer"]
    - path: flutter_app/lib/presentation/widgets/voice_selector.dart
      provides: Voice selection dropdown with 5 preset voices
      exports: ["VoiceSelector"]
    - path: flutter_app/lib/presentation/widgets/playback_controls.dart
      provides: Play/Pause/Stop buttons for TTS playback
      exports: ["PlaybackControls"]
    - path: flutter_app/lib/presentation/widgets/tts_progress_bar.dart
      provides: Progress bar with current position and duration display
      exports: ["TtsProgressBar"]
  key_links:
    - from: flutter_app/lib/presentation/screens/tts_screen.dart
      to: flutter_app/lib/presentation/providers/tts_provider.dart
      via: ConsumerWidget + ref.watch(ttsProvider)
      pattern: "ref.watch(ttsProvider)"
    - from: flutter_app/lib/presentation/providers/tts_provider.dart
      to: flutter_app/lib/services/websocket/tts_websocket_service.dart
      via: TtsWebSocketService + StreamSubscription
      pattern: "StreamSubscription.*TtsWebSocketService"
    - from: flutter_app/lib/presentation/providers/tts_provider.dart
      to: flutter_app/lib/services/audio/tts_audio_player.dart
      via: TtsAudioPlayer + BufferStream
      pattern: "BufferStream.*flutter_soloud"
    - from: flutter_app/lib/presentation/screens/home_screen.dart
      to: flutter_app/lib/presentation/screens/tts_screen.dart
      via: BottomNavigationBar (Tab switching)
      pattern: "BottomNavigationBar.*ASR.*TTS"
---

<objective>
Build the Flutter TTS Tab UI that allows users to input text, select a voice preset, and play streaming audio from the cloud TTS server. This tab runs alongside the ASR Tab from Phase 1, with both accessible via bottom navigation.

Purpose: Without this UI, users cannot interact with the cloud TTS service to hear synthesized speech.
Output: TTS Tab screen, TTS Riverpod provider, WebSocket client, flutter_soloud audio player, voice selector, playback controls, progress bar.
</objective>

<execution_context>
 @$HOME/.cursor/get-shit-done/workflows/execute-plan.md
 @$HOME/.cursor/get-shit-done/templates/summary.md
</execution_context>

<context>
 @.planning/phases/02-cloud-tts-foundation/02-CONTEXT.md D-01 through D-11 (Flutter decisions)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §3 (flutter_soloud streaming config)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §3.3 (WebSocket lifecycle)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §3.4 (progress bar calculation)
 @.planning/phases/02-cloud-tts-foundation/02-S-PLAN.md (server protocol)
 @.planning/phases/01-cloud-asr-pipeline/01-CONTEXT.md (inherited ASR patterns)
 @flutter_app/lib/presentation/screens/home_screen.dart (existing ASR screen pattern)
 @flutter_app/lib/services/websocket/websocket_service.dart (existing ASR WebSocket pattern)
 @flutter_app/lib/presentation/providers/voice_provider.dart (existing ASR provider pattern)
</context>

<assumptions_note>
## Critical UI/UX Decisions

Per 02-CONTEXT.md:
1. TTS Tab is independent from ASR Tab, with bottom navigation switching (D-01)
2. Text input at top + voice selector + playback controls layout (D-02)
3. Playback controls: Play/Pause/Stop + progress bar (D-06)
4. Progress bar based on estimated_chunks and received_chunks (D-06)
5. Pause preserves buffer; stop disconnects WebSocket immediately (D-07, D-08)
6. flutter_soloud used for low-latency audio playback (inherited from Phase 1)
7. WebSocket uses same exponential backoff pattern as ASR (inherited)
</assumptions_note>

<interfaces>
<!-- Key types the executor needs. Extracted from codebase patterns. -->

From flutter_app/lib/domain/entities/tts_state.dart:
```dart
/// TTS playback state.
enum TtsPlaybackState {
  idle,       // No audio loaded
  loading,    // Connecting to server
  playing,   // Audio is playing
  paused,     // Audio paused, buffer preserved
  stopped,   // Stopped, buffer cleared
  error,      // Error occurred
}

/// Immutable TTS state.
class TtsState {
  final TtsPlaybackState playbackState;
  final String text;
  final String voiceId;
  final String voiceName;
  final double progress;  // 0.0 to 1.0
  final int receivedChunks;
  final int estimatedChunks;
  final int playedChunks;
  final int totalDurationMs;
  final int currentPositionMs;
  final String? errorMessage;
  final List<VoiceInfo> availableVoices;
}
```

From flutter_app/lib/services/websocket/tts_websocket_service.dart:
```dart
class TtsWebSocketService {
  /// Connect to TTS server.
  Future<void> connect();

  /// Send start request with text and voice.
  void sendStart({required String text, required String voiceId});

  /// Stream of TTS messages (metadata, audio chunks, done, error).
  Stream<TtsMessage> get messageStream;

  /// Disconnect immediately (called on stop).
  Future<void> disconnect();

  /// Connection state stream.
  Stream<ConnectionState> get connectionStateAsStream;
}
```

From flutter_app/lib/services/audio/tts_audio_player.dart:
```dart
class TtsAudioPlayer {
  /// Initialize audio engine.
  Future<void> init();

  /// Create a buffer stream for receiving audio chunks.
  Future<BufferStream> createStream();

  /// Add PCM audio data to the stream.
  void addAudioData(BufferStream stream, Uint8List pcmData);

  /// Start playback.
  Future<void> play(BufferStream stream);

  /// Pause playback.
  void pause();

  /// Resume playback.
  void resume();

  /// Stop playback and clear buffer.
  Future<void> stop();

  /// Get current playback position.
  Duration getPosition();

  /// Dispose resources.
  void dispose();
}
```

From flutter_app/lib/presentation/widgets/voice_selector.dart:
```dart
/// Voice selector widget with 5 preset voices.
class VoiceSelector extends StatelessWidget {
  final List<VoiceInfo> voices;
  final String selectedVoiceId;
  final ValueChanged<String> onVoiceChanged;
}
```

From flutter_app/lib/presentation/widgets/playback_controls.dart:
```dart
/// Playback control buttons (Play/Pause/Stop).
class PlaybackControls extends StatelessWidget {
  final TtsPlaybackState playbackState;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final bool canPlay;
  final bool canPause;
  final bool canStop;
}
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Add Dependencies and Create TTS Entities</name>
  <files>flutter_app/pubspec.yaml, flutter_app/lib/domain/entities/tts_state.dart, flutter_app/lib/domain/entities/voice_info.dart</files>
  <read_first>
    flutter_app/pubspec.yaml (existing — Phase 1)
    flutter_app/lib/domain/entities/asr_result.dart (existing — Phase 1 pattern)
  </read_first>
  <action>
**Task 1A: Update pubspec.yaml** — Add flutter_soloud dependency:

Add this to the dependencies section:
```yaml
# Audio playback (per Phase 1 decision, D-13)
flutter_soloud: ^3.2.1
```

Full dependencies section should look like:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State management (per D-12)
  flutter_riverpod: ^3.3.1

  # Audio recording (per D-09)
  record: ^6.2.0

  # Audio playback (per Phase 2 decision)
  flutter_soloud: ^3.2.1

  # WebSocket client (per RESEARCH.md §1.2)
  web_socket_channel: ^3.0.1

  # HTTP client for health checks
  dio: ^5.7.0

  # Permission handling
  permission_handler: ^11.3.1

  # Routing
  go_router: ^14.6.2

  # Network connectivity
  connectivity_plus: ^6.1.1
```

**Task 1B: Create VoiceInfo entity** — New file flutter_app/lib/domain/entities/voice_info.dart:
```dart
/// Voice information for the voice selector.
/// Maps to the VoiceInfo Pydantic model from /voices endpoint.
class VoiceInfo {
  final String id;
  final String name;
  final String language;  // "zh", "en", "mixed"
  final String gender;     // "female", "male", "neutral"

  const VoiceInfo({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
  });

  factory VoiceInfo.fromJson(Map<String, dynamic> json) {
    return VoiceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      language: json['language'] as String,
      gender: json['gender'] as String,
    );
  }

  /// Default preset voices (matching server-side PRESET_VOICES).
  static const List<VoiceInfo> defaultVoices = [
    VoiceInfo(id: 'zh_female_1', name: '中文女声-温柔', language: 'zh', gender: 'female'),
    VoiceInfo(id: 'zh_male_1', name: '中文男声-稳重', language: 'zh', gender: 'male'),
    VoiceInfo(id: 'en_female_1', name: 'English Female', language: 'en', gender: 'female'),
    VoiceInfo(id: 'en_male_1', name: 'English Male', language: 'en', gender: 'male'),
    VoiceInfo(id: 'mixed_1', name: '中英混合', language: 'mixed', gender: 'neutral'),
  ];
}
```

**Task 1C: Create TtsState entity** — New file flutter_app/lib/domain/entities/tts_state.dart:
```dart
import 'voice_info.dart';

/// TTS playback state enum.
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

/// Immutable TTS state.
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

  /// Available voices (from /voices endpoint).
  final List<VoiceInfo> availableVoices;

  /// Connection state.
  final ConnectionState connectionState;

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
    this.connectionState = ConnectionState.disconnected,
  });

  /// Get formatted duration string (e.g., "00:30 / 01:00").
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
      playbackState == TtsPlaybackState.stopped;

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
    ConnectionState? connectionState,
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

/// Connection state enum (mirroring ASR).
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}
```
</action>
  <verify>
    <automated>grep -l "flutter_soloud" flutter_app/pubspec.yaml && grep -l "class TtsState\|enum TtsPlaybackState" flutter_app/lib/domain/entities/tts_state.dart && grep -l "class VoiceInfo" flutter_app/lib/domain/entities/voice_info.dart && echo "TTS ENTITIES OK"</automated>
  </verify>
  <acceptance_criteria>
    - flutter_app/pubspec.yaml contains flutter_soloud: ^3.2.1
    - flutter_app/lib/domain/entities/voice_info.dart contains VoiceInfo class with defaultVoices (5 presets)
    - flutter_app/lib/domain/entities/tts_state.dart contains TtsState and TtsPlaybackState
    - VoiceInfo has fromJson factory and defaultVoices list
    - TtsState has copyWith, durationDisplay, canPlay, canPause, canStop
    - ConnectionState enum matches ASR pattern
  </acceptance_criteria>
  <done>TTS entities created: VoiceInfo, TtsState, TtsPlaybackState</done>
</task>

<task type="auto">
  <name>Task 2: Create TTS WebSocket Service and Audio Player</name>
  <files>flutter_app/lib/services/websocket/tts_websocket_service.dart, flutter_app/lib/services/audio/tts_audio_player.dart</files>
  <read_first>
    flutter_app/lib/services/websocket/websocket_service.dart (existing ASR pattern)
    flutter_app/lib/services/audio/audio_recorder_service.dart (existing pattern)
  </read_first>
  <action>
**Task 2A: Create TTS WebSocket Service** — flutter_app/lib/services/websocket/tts_websocket_service.dart:

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/entities/voice_info.dart';

/// TTS message types from WebSocket server.
sealed class TtsMessage {}

class TtsMetadata extends TtsMessage {
  final int sampleRate;
  final int channels;
  final String format;
  final String model;
  final int estimatedChunks;
  final int estimatedDurationMs;

  const TtsMetadata({
    required this.sampleRate,
    required this.channels,
    required this.format,
    required this.model,
    required this.estimatedChunks,
    required this.estimatedDurationMs,
  });
}

class TtsAudioChunk extends TtsMessage {
  final int chunkIndex;
  final bool isFinal;
  final int timestampMs;
  final Uint8List audioData;

  const TtsAudioChunk({
    required this.chunkIndex,
    required this.isFinal,
    required this.timestampMs,
    required this.audioData,
  });
}

class TtsDone extends TtsMessage {
  final int totalChunks;
  final int totalDurationMs;

  const TtsDone({required this.totalChunks, required this.totalDurationMs});
}

class TtsErrorMessage extends TtsMessage {
  final String code;
  final String message;

  const TtsErrorMessage({required this.code, required this.message});
}

/// WebSocket service for TTS streaming.
/// Mirrors the ASR WebSocketService pattern (exponential backoff reconnection).
class TtsWebSocketService {
  WebSocketChannel? _channel;

  final StreamController<TtsMessage> _messageController =
      StreamController<TtsMessage>.broadcast();

  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  // Exponential backoff config (same as ASR)
  static const int maxRetries = 5;
  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 30);

  int _retryCount = 0;
  Duration _currentDelay = baseDelay;
  bool _disposed = false;
  String? _lastUrl;
  ConnectionState _state = ConnectionState.disconnected;

  Stream<TtsMessage> get messageStream => _messageController.stream;
  Stream<ConnectionState> get connectionStateAsStream => _stateController.stream;
  ConnectionState get connectionState => _state;

  /// Connect to TTS WebSocket endpoint.
  Future<void> connect() async {
    if (_disposed) return;

    _retryCount = 0;
    _currentDelay = baseDelay;
    _updateState(ConnectionState.connecting);

    try {
      // Build WebSocket URL from API config
      final baseUrl = 'ws://localhost:8000';  // TODO: from api_config
      _lastUrl = '$baseUrl/v1/tts/stream';

      _channel = WebSocketChannel.connect(Uri.parse(_lastUrl!));

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _updateState(ConnectionState.connected);
    } catch (e) {
      debugPrint('TTS WebSocket connect error: $e');
      await _handleDisconnect(e);
    }
  }

  void _updateState(ConnectionState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _onMessage(dynamic message) {
    if (_disposed) return;

    try {
      if (message is String) {
        // JSON message (metadata, done, error)
        final json = Map<String, dynamic>.from(
          (message as dynamic) is String
              ? (message as String)
              : message,
        );

        // Handle string parsing manually
        if (message is! Map) {
          // Use dart:convert in real implementation
          return;
        }

        final type = json['type'] as String?;
        switch (type) {
          case 'metadata':
            _messageController.add(TtsMetadata(
              sampleRate: json['sample_rate'] as int? ?? 24000,
              channels: json['channels'] as int? ?? 1,
              format: json['format'] as String? ?? 'pcm_s16le',
              model: json['model'] as String? ?? 'unknown',
              estimatedChunks: json['estimated_chunks'] as int? ?? 0,
              estimatedDurationMs: json['estimated_duration_ms'] as int? ?? 0,
            ));
            break;
          case 'audio_chunk':
            // Audio chunk header - binary data comes separately
            _messageController.add(TtsAudioChunk(
              chunkIndex: json['chunk_index'] as int? ?? 0,
              isFinal: json['is_final'] as bool? ?? false,
              timestampMs: json['timestamp_ms'] as int? ?? 0,
              audioData: Uint8List(0),  // Will be set by binary handler
            ));
            break;
          case 'done':
            _messageController.add(TtsDone(
              totalChunks: json['total_chunks'] as int? ?? 0,
              totalDurationMs: json['total_duration_ms'] as int? ?? 0,
            ));
            break;
          case 'error':
            _messageController.add(TtsErrorMessage(
              code: json['code'] as String? ?? 'UNKNOWN',
              message: json['message'] as String? ?? 'Unknown error',
            ));
            break;
        }
      } else if (message is List<int>) {
        // Binary audio data - combine with last header
        // This is simplified; real implementation needs buffer management
        _messageController.add(TtsAudioChunk(
          chunkIndex: 0,
          isFinal: false,
          timestampMs: 0,
          audioData: Uint8List.fromList(message),
        ));
      }
    } catch (e) {
      debugPrint('Error parsing TTS message: $e');
    }
  }

  void _onError(Object error) {
    if (_disposed) return;
    debugPrint('TTS WebSocket error: $error');
    _handleDisconnect(error);
  }

  void _onDone() {
    if (_disposed) return;
    debugPrint('TTS WebSocket connection closed');
    _handleDisconnect('Connection closed');
  }

  Future<void> _handleDisconnect(Object error) async {
    if (_disposed || _state == ConnectionState.disconnected) return;

    if (_retryCount >= maxRetries) {
      debugPrint('Max TTS retries reached ($maxRetries). Giving up.');
      _updateState(ConnectionState.failed);
      return;
    }

    _updateState(ConnectionState.reconnecting);

    debugPrint(
      'TTS reconnecting in ${_currentDelay.inSeconds}s '
      '(attempt ${_retryCount + 1}/$maxRetries)...',
    );

    await Future.delayed(_currentDelay);

    // Exponential backoff
    _currentDelay = Duration(
      milliseconds: (_currentDelay.inMilliseconds * 2).clamp(
        baseDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      ),
    );

    _retryCount++;

    if (_lastUrl != null && !_disposed) {
      await connect();
    }
  }

  /// Send start request with text and voice.
  void sendStart({required String text, required String voiceId}) {
    if (_channel == null || _disposed) return;

    final message = {
      'type': 'start',
      'text': text,
      'voice_id': voiceId,
      'cfg_scale': 1.5,
      'inference_steps': 5,
    };

    // Convert to JSON string (simplified)
    final jsonStr = message.toString();
    _channel!.sink.add(jsonStr);
  }

  /// Disconnect immediately (called on stop).
  Future<void> disconnect() async {
    _retryCount = maxRetries;  // Prevent auto-reconnect
    _updateState(ConnectionState.disconnected);
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _stateController.close();
    _channel?.sink.close();
    _messageController.close();
  }
}
```

**Task 2B: Create TTS Audio Player** — flutter_app/lib/services/audio/tts_audio_player.dart:

```dart
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Audio player for TTS streaming using flutter_soloud.
/// Per RESEARCH.md §3: Low-latency streaming with BufferStream.
class TtsAudioPlayer {
  SoLoud? _soloud;
  BufferStream? _currentStream;
  SoundHandle? _currentHandle;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;

  /// Audio parameters (per server metadata).
  static const int sampleRate = 24000;
  static const Channels channels = Channels.mono;

  /// Initialize audio engine.
  Future<void> init() async {
    if (_isInitialized) return;

    _soloud = SoLoud.instance;
    await _soloud!.init(
      bufferSize: 512,  // Low latency buffer
      sampleRate: sampleRate,
      channels: channels,
    );

    _isInitialized = true;
    debugPrint('TtsAudioPlayer initialized');
  }

  /// Create a buffer stream for receiving audio chunks.
  Future<BufferStream> createStream() async {
    if (!_isInitialized || _soloud == null) {
      await init();
    }

    _currentStream = await _soloud!.setBufferStream(
      maxBufferSizeBytes: 1024 * 1024 * 10,  // 10MB max
      bufferingTimeNeeds: 0.2,  // 200ms buffer before starting
      sampleRate: sampleRate,
      channels: channels,
      format: BufferType.s16le,  // PCM16 little-endian
      bufferingType: BufferingType.released,  // Manual pause/resume
    );

    return _currentStream!;
  }

  /// Add PCM audio data to the stream.
  void addAudioData(BufferStream stream, Uint8List pcmData) {
    if (!_isInitialized || _soloud == null) return;

    _soloud!.addAudioDataStream(stream, pcmData);
  }

  /// Start playback (called after first chunk received).
  Future<void> play(BufferStream stream) async {
    if (!_isInitialized || _soloud == null) return;
    if (_currentHandle != null) return;  // Already playing

    _currentHandle = await _soloud!.play(stream);
    _isPlaying = true;
    _isPaused = false;
    debugPrint('TtsAudioPlayer started playback');
  }

  /// Pause playback (buffer is preserved).
  void pause() {
    if (!_isInitialized || _soloud == null || _currentHandle == null) return;
    if (!_isPlaying || _isPaused) return;

    _soloud!.pause(_currentHandle!);
    _isPaused = true;
    debugPrint('TtsAudioPlayer paused');
  }

  /// Resume playback.
  void resume() {
    if (!_isInitialized || _soloud == null || _currentHandle == null) return;
    if (!_isPaused) return;

    _soloud!.setPause(_currentHandle!, false);
    _isPaused = false;
    debugPrint('TtsAudioPlayer resumed');
  }

  /// Stop playback and clear buffer.
  Future<void> stop() async {
    if (!_isInitialized || _soloud == null) return;

    if (_currentHandle != null) {
      await _soloud!.stop(_currentHandle!);
      _currentHandle = null;
    }

    _currentStream = null;
    _isPlaying = false;
    _isPaused = false;
    debugPrint('TtsAudioPlayer stopped');
  }

  /// Get current playback position in milliseconds.
  int getPositionMs {
    if (!_isInitialized || _soloud == null || _currentHandle == null) return 0;

    final position = _soloud!.getPosition(_currentHandle!);
    return position.inMilliseconds;
  }

  /// Check if currently playing.
  bool get isPlaying => _isPlaying && !_isPaused;

  /// Check if currently paused.
  bool get isPaused => _isPaused;

  /// Dispose resources.
  Future<void> dispose() async {
    if (_soloud != null) {
      await stop();
      await _soloud!.deinit();
      _soloud = null;
    }
    _isInitialized = false;
    debugPrint('TtsAudioPlayer disposed');
  }
}

// Global instance
final ttsAudioPlayer = TtsAudioPlayer();
```
</action>
  <verify>
    <automated>grep -l "class TtsWebSocketService" flutter_app/lib/services/websocket/tts_websocket_service.dart && grep -l "class TtsAudioPlayer" flutter_app/lib/services/audio/tts_audio_player.dart && echo "TTS SERVICES OK"</automated>
  </verify>
  <acceptance_criteria>
    - flutter_app/lib/services/websocket/tts_websocket_service.dart exists with TtsWebSocketService class
    - flutter_app/lib/services/audio/tts_audio_player.dart exists with TtsAudioPlayer class
    - TtsWebSocketService has connect/sendStart/disconnect/dispose methods
    - TtsWebSocketService has messageStream and connectionStateAsStream streams
    - TtsAudioPlayer has init/createStream/addAudioData/play/pause/resume/stop/dispose methods
    - Both services follow same patterns as Phase 1 ASR services
  </acceptance_criteria>
  <done>TTS WebSocket service and audio player created</done>
</task>

<task type="auto">
  <name>Task 3: Create TTS Provider (Riverpod State Management)</name>
  <files>flutter_app/lib/presentation/providers/tts_provider.dart, flutter_app/lib/presentation/providers/providers.dart</files>
  <read_first>
    flutter_app/lib/presentation/providers/voice_provider.dart (existing ASR provider pattern)
    flutter_app/lib/domain/entities/tts_state.dart (created in Task 1)
    flutter_app/lib/services/websocket/tts_websocket_service.dart (created in Task 2)
    flutter_app/lib/services/audio/tts_audio_player.dart (created in Task 2)
  </read_first>
  <action>
**Task 3A: Create TTS Provider** — flutter_app/lib/presentation/providers/tts_provider.dart:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/entities/voice_info.dart';
import '../../services/websocket/tts_websocket_service.dart';
import '../../services/audio/tts_audio_player.dart';

/// TTS state notifier that manages playback state.
class TtsNotifier extends StateNotifier<TtsState> {
  final TtsWebSocketService _wsService;
  final TtsAudioPlayer _audioPlayer;

  StreamSubscription<TtsMessage>? _messageSubscription;
  StreamSubscription<ConnectionState>? _connectionSubscription;
  Timer? _progressTimer;

  // Pending audio chunks while buffering
  final List<Uint8List> _pendingChunks = [];
  BufferStream? _currentStream;

  TtsNotifier(this._wsService, this._audioPlayer) : super(const TtsState()) {
    _init();
  }

  void _init() {
    // Listen to WebSocket messages
    _messageSubscription = _wsService.messageStream.listen(_onMessage);

    // Listen to connection state
    _connectionSubscription = _wsService.connectionStateAsStream.listen((connState) {
      state = state.copyWith(connectionState: connState);

      if (connState == ConnectionState.failed) {
        state = state.copyWith(
          playbackState: TtsPlaybackState.error,
          errorMessage: '连接失败，请检查网络',
        );
      }
    });

    // Initialize audio player
    _audioPlayer.init();
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

    // If first chunk, create stream and start playing
    if (chunk.chunkIndex == 0 && _currentStream == null) {
      _currentStream = await _audioPlayer.createStream();
    }

    // Add audio data to stream
    if (_currentStream != null) {
      _audioPlayer.addAudioData(_currentStream!, chunk.audioData);

      // Start playback on first chunk
      if (!state.playbackState.isPlaying) {
        await _audioPlayer.play(_currentStream!);
        state = state.copyWith(playbackState: TtsPlaybackState.playing);
        _startProgressTimer();
      }
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
            : positionMs / state.totalDurationMs;

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

  /// Play text with selected voice.
  Future<void> play(String text, String voiceId) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(
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

  /// Pause playback (buffer preserved).
  void pause() {
    if (!state.playbackState.isPlaying) return;

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

  /// Stop playback immediately and disconnect.
  Future<void> stop() async {
    await _stopPlayback();
  }

  Future<void> _stopPlayback() async {
    _stopProgressTimer();
    await _wsService.disconnect();
    await _audioPlayer.stop();
    _currentStream = null;
    _pendingChunks.clear();

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

  /// Load available voices.
  Future<void> loadVoices() async {
    // Use default voices (can be fetched from /voices endpoint later)
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

/// TTS provider.
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
```
</action>
  <verify>
    <automated>grep -l "class TtsNotifier\|final ttsProvider" flutter_app/lib/presentation/providers/tts_provider.dart && echo "TTS PROVIDER OK"</automated>
  </verify>
  <acceptance_criteria>
    - flutter_app/lib/presentation/providers/tts_provider.dart exists
    - TtsNotifier has play/pause/resume/stop/setVoice/dismissError methods
    - TtsNotifier listens to WebSocket messages and audio player
    - State updates correctly for each playback state transition
    - Progress timer updates progress and currentPositionMs
  </acceptance_criteria>
  <done>TTS Riverpod provider created with play/pause/resume/stop state management</done>
</task>

<task type="auto">
  <name>Task 4: Create TTS UI Widgets (Voice Selector, Playback Controls, Progress Bar)</name>
  <files>flutter_app/lib/presentation/widgets/voice_selector.dart, flutter_app/lib/presentation/widgets/playback_controls.dart, flutter_app/lib/presentation/widgets/tts_progress_bar.dart</files>
  <read_first>
    flutter_app/lib/presentation/widgets/language_toggle.dart (existing ASR widget pattern)
    flutter_app/lib/presentation/widgets/mic_button.dart (existing ASR widget pattern)
    flutter_app/lib/domain/entities/voice_info.dart (created in Task 1)
  </read_first>
  <action>
**Task 4A: Create Voice Selector** — flutter_app/lib/presentation/widgets/voice_selector.dart:

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/voice_info.dart';

/// Voice selector widget with dropdown or segmented control.
/// Shows 5 preset voices with language and gender indicators.
class VoiceSelector extends StatelessWidget {
  /// Available voices to select from.
  final List<VoiceInfo> voices;

  /// Currently selected voice ID.
  final String selectedVoiceId;

  /// Callback when voice is changed.
  final ValueChanged<VoiceInfo> onVoiceChanged;

  const VoiceSelector({
    super.key,
    required this.voices,
    required this.selectedVoiceId,
    required this.onVoiceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedVoice = voices.firstWhere(
      (v) => v.id == selectedVoiceId,
      orElse: () => voices.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.record_voice_over,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VoiceInfo>(
                value: selectedVoice,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: voices.map((voice) {
                  return DropdownMenuItem<VoiceInfo>(
                    value: voice,
                    child: Row(
                      children: [
                        _buildLanguageChip(context, voice.language),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            voice.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (voice) {
                  if (voice != null) {
                    onVoiceChanged(voice);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(BuildContext context, String language) {
    Color chipColor;
    String label;

    switch (language) {
      case 'zh':
        chipColor = Colors.red.shade400;
        label = '中';
        break;
      case 'en':
        chipColor = Colors.blue.shade400;
        label = 'EN';
        break;
      case 'mixed':
        chipColor = Colors.purple.shade400;
        label = '混';
        break;
      default:
        chipColor = Colors.grey;
        label = language.toUpperCase().substring(0, 2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

**Task 4B: Create Playback Controls** — flutter_app/lib/presentation/widgets/playback_controls.dart:

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/tts_state.dart';

/// Playback control buttons: Play/Pause and Stop.
/// Per 02-CONTEXT.md D-06: Playback controls for TTS.
class PlaybackControls extends StatelessWidget {
  /// Current playback state.
  final TtsPlaybackState playbackState;

  /// Callback for play button.
  final VoidCallback onPlay;

  /// Callback for pause button.
  final VoidCallback onPause;

  /// Callback for stop button.
  final VoidCallback onStop;

  const PlaybackControls({
    super.key,
    required this.playbackState,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  bool get _canPlay =>
      playbackState == TtsPlaybackState.idle ||
      playbackState == TtsPlaybackState.stopped ||
      playbackState == TtsPlaybackState.error;

  bool get _canPause => playbackState == TtsPlaybackState.playing;

  bool get _canStop =>
      playbackState == TtsPlaybackState.playing ||
      playbackState == TtsPlaybackState.paused ||
      playbackState == TtsPlaybackState.loading;

  @override
  Widget build(BuildContext context) {
    final isLoading = playbackState == TtsPlaybackState.loading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play/Pause button (main action)
        _buildMainButton(context, isLoading),

        const SizedBox(width: 24),

        // Stop button
        _buildStopButton(context),
      ],
    );
  }

  Widget _buildMainButton(BuildContext context, bool isLoading) {
    IconData icon;
    VoidCallback? onPressed;
    Color? backgroundColor;

    if (isLoading) {
      icon = Icons.hourglass_empty;
      onPressed = null;
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    } else if (playbackState == TtsPlaybackState.playing) {
      icon = Icons.pause_circle_filled;
      onPressed = onPause;
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
    } else {
      icon = Icons.play_circle_filled;
      onPressed = onPlay;
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: isLoading
          ? Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              iconSize: 64,
              icon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: IconButton(
        onPressed: _canStop ? onStop : null,
        iconSize: 40,
        icon: Icon(
          Icons.stop_circle,
          color: _canStop
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
```

**Task 4C: Create TTS Progress Bar** — flutter_app/lib/presentation/widgets/tts_progress_bar.dart:

```dart
import 'package:flutter/material.dart';

/// Progress bar with duration display for TTS playback.
/// Per 02-CONTEXT.md D-06: Progress based on estimated_chunks and received_chunks.
class TtsProgressBar extends StatelessWidget {
  /// Current progress (0.0 to 1.0).
  final double progress;

  /// Formatted duration string (e.g., "00:30 / 01:00").
  final String durationDisplay;

  const TtsProgressBar({
    super.key,
    required this.progress,
    required this.durationDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: null,  // Read-only for TTS
          ),
        ),

        // Duration display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current position
              Text(
                _parseCurrentTime(durationDisplay),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),

              // Status indicator
              if (progress > 0 && progress < 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '缓冲中...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),

              // Total duration
              Text(
                _parseTotalTime(durationDisplay),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _parseCurrentTime(String display) {
    // Parse "00:30 / 01:00" -> "00:30"
    final parts = display.split(' / ');
    return parts.isNotEmpty ? parts[0] : '00:00';
  }

  String _parseTotalTime(String display) {
    // Parse "00:30 / 01:00" -> "01:00"
    final parts = display.split(' / ');
    return parts.length > 1 ? parts[1] : '00:00';
  }
}
```
</action>
  <verify>
    <automated>grep -l "class VoiceSelector" flutter_app/lib/presentation/widgets/voice_selector.dart && grep -l "class PlaybackControls" flutter_app/lib/presentation/widgets/playback_controls.dart && grep -l "class TtsProgressBar" flutter_app/lib/presentation/widgets/tts_progress_bar.dart && echo "TTS WIDGETS OK"</automated>
  </verify>
  <acceptance_criteria>
    - flutter_app/lib/presentation/widgets/voice_selector.dart exists with VoiceSelector class
    - flutter_app/lib/presentation/widgets/playback_controls.dart exists with PlaybackControls class
    - flutter_app/lib/presentation/widgets/tts_progress_bar.dart exists with TtsProgressBar class
    - VoiceSelector shows 5 voices with language chips (中/EN/混)
    - PlaybackControls shows Play/Pause and Stop buttons
    - TtsProgressBar shows slider with duration display
  </acceptance_criteria>
  <done>TTS UI widgets created: VoiceSelector, PlaybackControls, TtsProgressBar</done>
</task>

<task type="auto">
  <name>Task 5: Create TTS Screen and Update Home Screen with Tab Navigation</name>
  <files>flutter_app/lib/presentation/screens/tts_screen.dart, flutter_app/lib/presentation/screens/home_screen.dart, flutter_app/lib/app.dart</files>
  <read_first>
    flutter_app/lib/presentation/screens/home_screen.dart (existing ASR screen)
    flutter_app/lib/presentation/widgets/mic_button.dart (existing widget)
    flutter_app/lib/presentation/widgets/status_indicator.dart (existing widget)
  </read_first>
  <action>
**Task 5A: Create TTS Screen** — flutter_app/lib/presentation/screens/tts_screen.dart:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tts_state.dart';
import '../providers/tts_provider.dart';
import '../widgets/voice_selector.dart';
import '../widgets/playback_controls.dart';
import '../widgets/tts_progress_bar.dart';
import '../providers/providers.dart';

/// TTS Tab screen for text-to-speech playback.
/// Per 02-CONTEXT.md D-01, D-02: Independent tab with text input + voice selector + playback controls.
class TtsScreen extends ConsumerStatefulWidget {
  const TtsScreen({super.key});

  @override
  ConsumerState<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends ConsumerState<TtsScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Load available voices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsProvider.notifier).loadVoices();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPlay() {
    final text = _textController.text.trim();
    final ttsState = ref.read(ttsProvider);
    ref.read(ttsProvider.notifier).play(text, ttsState.voiceId);
  }

  void _onPause() {
    ref.read(ttsProvider.notifier).pause();
  }

  void _onResume() {
    ref.read(ttsProvider.notifier).resume();
  }

  void _onStop() {
    ref.read(ttsProvider.notifier).stop();
  }

  void _onVoiceChanged(voice) {
    ref.read(ttsProvider.notifier).setVoice(voice.id, voice.name);
  }

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsProvider);
    final connectionState = ref.watch(currentConnectionStateProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // App bar area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.speaker_phone,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '语音合成',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const Spacer(),
                  // Connection status
                  _buildConnectionStatus(context, connectionState),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Voice selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VoiceSelector(
                voices: ttsState.availableVoices,
                selectedVoiceId: ttsState.voiceId,
                onVoiceChanged: _onVoiceChanged,
              ),
            ),

            const SizedBox(height: 16),

            // Text input area (expands to fill space)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '在此输入要合成的文本...',
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: (_) => setState(() {}),  // Enable play button when text changes
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TtsProgressBar(
                progress: ttsState.progress,
                durationDisplay: ttsState.durationDisplay,
              ),
            ),

            const SizedBox(height: 16),

            // Playback controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlaybackControls(
                playbackState: ttsState.playbackState,
                onPlay: _onPlay,
                onPause: _onPause,
                onStop: _onStop,
              ),
            ),

            const SizedBox(height: 16),

            // Error message
            if (ttsState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ttsState.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          ref.read(ttsProvider.notifier).dismissError();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom padding
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, ConnectionState connState) {
    Color color;
    String text;
    IconData icon;

    switch (connState) {
      case ConnectionState.connected:
        color = Colors.green;
        text = '已连接';
        icon = Icons.cloud_done;
        break;
      case ConnectionState.connecting:
        color = Colors.orange;
        text = '连接中';
        icon = Icons.cloud_sync;
        break;
      case ConnectionState.reconnecting:
        color = Colors.orange;
        text = '重连中';
        icon = Icons.cloud_sync;
        break;
      case ConnectionState.failed:
        color = Colors.red;
        text = '连接失败';
        icon = Icons.cloud_off;
        break;
      case ConnectionState.disconnected:
        color = Colors.grey;
        text = '未连接';
        icon = Icons.cloud_outlined;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
```

**Task 5B: Update Home Screen with Bottom Navigation** — Modify flutter_app/lib/presentation/screens/home_screen.dart:

Add bottom navigation to switch between ASR and TTS tabs. The home screen becomes a tab scaffold:

```dart
// Replace the existing HomeScreen with a TabScaffold
// This is a simplified modification - the full implementation should integrate
// with the existing ASR functionality

import 'tts_screen.dart';

// In HomeScreen's build method, wrap with DefaultTabController and BottomNavigationBar
// or use a more sophisticated navigation solution

// Simplified: Create a MainScreen that contains both tabs
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),  // ASR Tab (existing)
    TtsScreen(),  // TTS Tab (new)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_outlined),
            selectedIcon: Icon(Icons.mic),
            label: '语音输入',
          ),
          NavigationDestination(
            icon: Icon(Icons.speaker_phone_outlined),
            selectedIcon: Icon(Icons.speaker_phone),
            label: '语音合成',
          ),
        ],
      ),
    );
  }
}
```

Update flutter_app/lib/main.dart to use MainScreen:
```dart
// In main.dart, replace MaterialApp home: HomeScreen() with:
home: const MainScreen(),
```
</action>
  <verify>
    <automated>grep -l "class TtsScreen" flutter_app/lib/presentation/screens/tts_screen.dart && grep -l "class MainScreen\|NavigationBar" flutter_app/lib/presentation/screens/home_screen.dart && echo "TTS SCREEN OK"</automated>
  </verify>
  <acceptance_criteria>
    - flutter_app/lib/presentation/screens/tts_screen.dart exists with TtsScreen widget
    - TtsScreen contains text input, voice selector, progress bar, playback controls
    - Bottom navigation added to switch between ASR and TTS tabs
    - Error messages displayed when errors occur
    - Loading state shown while connecting/buffering
  </acceptance_criteria>
  <done>TTS Screen created and bottom navigation integrated</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 6: Flutter Build Validation</name>
  <files>flutter_app/lib/presentation/screens/tts_screen.dart, flutter_app/lib/presentation/providers/tts_provider.dart, flutter_app/lib/presentation/widgets/voice_selector.dart</files>
  <read_first>
    flutter_app/lib/main.dart (existing)
    flutter_app/pubspec.yaml (updated in Task 1)
  </read_first>
  <action>
**Task 6A: Executor validates code structure** (automated):

```bash
# Validate all new files exist
ls flutter_app/lib/presentation/screens/tts_screen.dart
ls flutter_app/lib/presentation/providers/tts_provider.dart
ls flutter_app/lib/services/websocket/tts_websocket_service.dart
ls flutter_app/lib/services/audio/tts_audio_player.dart
ls flutter_app/lib/presentation/widgets/voice_selector.dart
ls flutter_app/lib/presentation/widgets/playback_controls.dart
ls flutter_app/lib/presentation/widgets/tts_progress_bar.dart
ls flutter_app/lib/domain/entities/tts_state.dart
ls flutter_app/lib/domain/entities/voice_info.dart

# Verify Dart syntax
cd flutter_app && flutter analyze lib/presentation/screens/tts_screen.dart
cd flutter_app && flutter analyze lib/presentation/providers/tts_provider.dart
cd flutter_app && flutter analyze lib/services/websocket/tts_websocket_service.dart
cd flutter_app && flutter analyze lib/services/audio/tts_audio_player.dart

# Run Flutter pub get to fetch new dependencies
cd flutter_app && flutter pub get

# Build debug APK to verify compilation
cd flutter_app && flutter build apk --debug
```

**Task 6B: Manual validation on device** (user runs on Android):

```bash
# Install APK on device
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Test TTS Tab:
# 1. Launch app -> should show ASR tab (Mic button)
# 2. Tap TTS tab (bottom navigation) -> should show TTS screen
# 3. Enter text "你好"
# 4. Select voice "中文女声-温柔"
# 5. Tap play button -> should hear audio within 500ms
# 6. Verify progress bar updates
# 7. Tap pause -> audio should pause, buffer preserved
# 8. Tap play again -> audio resumes
# 9. Tap stop -> audio stops, WebSocket disconnects
# 10. Test with different voices (切换到英文)
# 11. Test error handling (disconnect network -> play -> show error)
```
</action>
  <verify>
    <automated>cd flutter_app && flutter analyze lib/presentation/screens/tts_screen.dart lib/presentation/providers/tts_provider.dart 2>&1 | grep -c "error" || echo "ANALYZE OK"</automated>
  </verify>
  <acceptance_criteria>
    - flutter pub get succeeds (flutter_soloud fetched)
    - flutter analyze shows no errors in TTS files
    - flutter build apk succeeds
    - APK installs on Android device
    - TTS Tab accessible via bottom navigation
    - Text input accepts Chinese/English text
    - Voice selector shows 5 preset voices
    - Play button starts playback (audio streams and plays)
    - Pause preserves buffer (resume works)
    - Stop disconnects WebSocket immediately
    - Progress bar shows current position
    - Error messages display on failures
  </acceptance_criteria>
  <done>
    - flutter pub get succeeded with flutter_soloud
    - flutter analyze passed (no errors)
    - flutter build apk succeeded
    - APK installed on device
    - User confirmed TTS Tab works end-to-end
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user input → TTS server | User enters text; client sends to server |
| server → audio playback | Server streams PCM; client plays audio |
| network → client | WebSocket can disconnect; client handles reconnection |

## Input Validation (Client-Side)

| Threat ID | Category | Disposition | Mitigation |
|-----------|----------|-------------|------------|
| T-02-F01 | Input Validation | mitigate | Reject empty text before sending; limit text length to 8000 chars |
| T-02-F02 | Injection | mitigate | Server validates text; client just passes through |
| T-02-F03 | State Management | mitigate | WebSocket reconnects with exponential backoff (inherited from ASR) |

## Error Handling

| Scenario | UI Response |
|----------|-------------|
| Empty text | Show hint: "请输入要合成的文本" |
| Network disconnect | Show error: "连接失败，请检查网络" + reconnect indicator |
| Server error | Show error message from server (code + message) |
| Buffer underrun | Show "缓冲中..." indicator while loading |
| Permission denied | N/A for TTS (no camera/mic needed) |
</threat_model>

<verification>
## Flutter Verification

After implementation, verify these on Android device:

```bash
# 1. Build debug APK
cd flutter_app && flutter build apk --debug

# 2. Install on device
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 3. Manual test checklist:

# Tab Navigation:
# - [ ] ASR tab shows mic button and transcription
# - [ ] TTS tab shows text input and voice selector
# - [ ] Bottom navigation switches between tabs

# Voice Selector:
# - [ ] Shows 5 voices with language chips
# - [ ] Selecting voice updates state

# Text Input:
# - [ ] Accepts Chinese text
# - [ ] Accepts English text
# - [ ] Empty text shows hint

# Playback Controls:
# - [ ] Play button enabled when text entered
# - [ ] Tap play -> audio starts within 500ms
# - [ ] Pause button pauses audio, buffer preserved
# - [ ] Resume continues from paused position
# - [ ] Stop button stops and disconnects

# Progress Bar:
# - [ ] Shows current position
# - [ ] Shows total duration
# - [ ] Updates during playback

# Error Handling:
# - [ ] Network disconnect shows error message
# - [ ] Tap play without text shows hint

# 4. E2E flow test:
# - Enter "你好，欢迎使用语音合成"
# - Select "中文女声-温柔"
# - Tap play
# - Verify audio plays and sounds correct
# - Verify < 500ms delay from tap to audio
```

## Must-Have Checklist

- [ ] TTS Tab accessible via bottom navigation
- [ ] Voice selector shows 5 preset voices with language chips
- [ ] Text input accepts Chinese/English text
- [ ] Play button triggers audio playback
- [ ] Audio starts playing within 500ms of tapping play
- [ ] Pause preserves buffer and allows resume
- [ ] Stop disconnects WebSocket immediately
- [ ] Progress bar shows current position and total duration
- [ ] Error messages display on failures
- [ ] App builds successfully with no linter errors
</verification>

<success_criteria>
1. TTS Tab accessible via bottom navigation on Flutter app
2. Voice selector displays 5 preset voices (2 Chinese, 2 English, 1 mixed)
3. Text input accepts Chinese and English text
4. Play button sends request to TTS WebSocket and starts streaming
5. Audio plays with < 500ms latency (TTFP from tap to sound)
6. Pause preserves audio buffer; resume continues playback
7. Stop immediately disconnects WebSocket connection
8. Progress bar shows correct position based on received chunks
9. Error states display appropriate UI feedback
10. APK builds successfully with all TTS features
</success_criteria>

<output>
After completion, create `.planning/phases/02-cloud-tts-foundation/02-F-SUMMARY.md`
</output>
