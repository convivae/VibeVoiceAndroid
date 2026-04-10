import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/entities/asr_result.dart';
import '../../domain/entities/voice_info.dart';

/// TTS message types from WebSocket server (per 02-S-PLAN.md protocol).
sealed class TtsMessage {}

/// Server sends this before first audio chunk.
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

/// Server sends this after each audio chunk (JSON header before binary).
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

/// Server sends when streaming is complete.
class TtsDone extends TtsMessage {
  final int totalChunks;
  final int totalDurationMs;

  const TtsDone({required this.totalChunks, required this.totalDurationMs});
}

/// Server sends on error.
class TtsErrorMessage extends TtsMessage {
  final String code;
  final String message;

  const TtsErrorMessage({required this.code, required this.message});
}

/// WebSocket service for TTS streaming.
/// Mirrors the ASR WebSocketService pattern with exponential backoff (D-18).
class TtsWebSocketService {
  WebSocketChannel? _channel;

  final StreamController<TtsMessage> _messageController =
      StreamController<TtsMessage>.broadcast();

  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  /// Exponential backoff config (same as ASR per D-18).
  static const int maxRetries = 5;
  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 30);

  int _retryCount = 0;
  Duration _currentDelay = baseDelay;
  bool _disposed = false;
  String? _lastUrl;
  ConnectionState _state = ConnectionState.disconnected;

  /// Pending audio chunk header (JSON) waiting for binary data.
  Map<String, dynamic>? _pendingChunkHeader;
  bool _expectingBinary = false;

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
      final baseUrl = 'ws://localhost:8000'; // TODO: from api_config
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
        // JSON message (metadata, done, error, or audio_chunk header)
        final json = jsonDecode(message) as Map<String, dynamic>;
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
            // Binary audio data follows this JSON header
            _pendingChunkHeader = json;
            _expectingBinary = true;
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
        // Binary audio data — pair with pending header
        if (_expectingBinary && _pendingChunkHeader != null) {
          _messageController.add(TtsAudioChunk(
            chunkIndex: _pendingChunkHeader!['chunk_index'] as int? ?? 0,
            isFinal: _pendingChunkHeader!['is_final'] as bool? ?? false,
            timestampMs: _pendingChunkHeader!['timestamp_ms'] as int? ?? 0,
            audioData: Uint8List.fromList(message),
          ));
          _pendingChunkHeader = null;
          _expectingBinary = false;
        }
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

    _channel!.sink.add(jsonEncode(message));
  }

  /// Disconnect immediately (called on stop per D-08).
  Future<void> disconnect() async {
    _retryCount = maxRetries; // Prevent auto-reconnect
    _updateState(ConnectionState.disconnected);
    _pendingChunkHeader = null;
    _expectingBinary = false;
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
