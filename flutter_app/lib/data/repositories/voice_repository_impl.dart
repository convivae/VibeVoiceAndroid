import 'dart:async';
import 'dart:typed_data';
import '../../domain/entities/asr_result.dart';
import '../../domain/repositories/voice_repository.dart';
import '../../core/config/api_config.dart';
import '../../services/audio/audio_exceptions.dart';
import '../../services/audio/audio_recorder_service.dart';
import '../../services/websocket/websocket_service.dart';
import '../../services/asr/hybrid_asr_service.dart';

/// Implementation of VoiceRepository using HybridAsrService.
/// Wires audio stream to either on-device or cloud ASR based on connectivity.
/// Per D-04: 切换逻辑在 VoiceRepository 层实现。
class VoiceRepositoryImpl implements VoiceRepository {
  final AudioRecorderService _audioRecorder;
  final WebSocketService _wsService;
  final HybridAsrService _hybridService;

  String _language = 'zh';  // Default: Mandarin (per D-15)
  final List<Uint8List> _recordedChunks = [];

  VoiceRepositoryImpl({
    required AudioRecorderService audioRecorder,
    required WebSocketService wsService,
    HybridAsrService? hybridService,
  })  : _audioRecorder = audioRecorder,
        _wsService = wsService,
        _hybridService = hybridService ?? HybridAsrService();

  @override
  String get language => _language;

  @override
  set language(String value) => _language = value;

  @override
  Stream<WsConnectionState> get connectionStateStream =>
      _wsService.connectionStateAsStream;

  @override
  WsConnectionState get connectionState =>
      _wsService.connectionState;

  /// Stream for hybrid routing status updates.
  Stream<HybridRoutingStatus> get routingStatusStream async* {
    while (true) {
      yield await _hybridService.getRoutingStatus();
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Stream<AsrResult> get transcriptionStream =>
      _wsService.messageStream.map((json) => AsrResult.fromJson(json));

  /// Internal stream for on-device transcription results.
  final _onDeviceTranscriptionController =
      StreamController<AsrResult>.broadcast();

  @override
  Future<void> connect() => _wsService.connect(ApiConfig.asrWsUrl);

  @override
  Future<void> disconnect() async {
    await _audioRecorder.stop();
    await _wsService.disconnect();
  }

  @override
  Future<void> startRecording({
    void Function(Uint8List chunk)? onChunkRecorded,
  }) async {
    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      throw MicrophonePermissionDeniedException();
    }

    // Clear previous recording
    _recordedChunks.clear();

    // Check which backend to use
    final routingStatus = await _hybridService.getRoutingStatus();

    if (routingStatus == HybridRoutingStatus.onDevice) {
      // Use on-device ASR (offline mode)
      await _startOnDeviceRecording(onChunkRecorded);
    } else {
      // Use cloud ASR (online mode)
      await _startCloudRecording(onChunkRecorded);
    }
  }

  Future<void> _startOnDeviceRecording(
    void Function(Uint8List chunk)? onChunkRecorded,
  ) async {
    // Start audio stream
    final audioStream = _audioRecorder.startStream();

    // Accumulate audio chunks
    audioStream.listen(
      (chunk) {
        _recordedChunks.add(chunk);
        onChunkRecorded?.call(chunk);
      },
      onError: (error) {
        throw RecordingException(error.toString());
      },
    );
  }

  Future<void> _startCloudRecording(
    void Function(Uint8List chunk)? onChunkRecorded,
  ) async {
    // Use existing Phase 1 WebSocket approach
    if (connectionState != WsConnectionState.connected) {
      await connect();
    }

    _wsService.sendStart(language: _language);

    final audioStream = _audioRecorder.startStream();

    audioStream.listen(
      (chunk) {
        _wsService.sendAudioChunk(chunk);
        onChunkRecorded?.call(chunk);
      },
      onError: (error) {
        throw RecordingException(error.toString());
      },
    );
  }

  @override
  Future<void> stopRecording() async {
    await _audioRecorder.stop();

    // If using on-device mode, run transcription
    final routingStatus = await _hybridService.getRoutingStatus();
    if (routingStatus == HybridRoutingStatus.onDevice) {
      // Concatenate all recorded chunks
      final totalLength = _recordedChunks.fold<int>(
        0, (sum, chunk) => sum + chunk.length);
      final audioData = Uint8List(totalLength);

      int offset = 0;
      for (final chunk in _recordedChunks) {
        audioData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Run on-device transcription
      try {
        final result = await _hybridService.transcribe(audioData, _language);
        _onDeviceTranscriptionController.add(result);
      } catch (e) {
        _onDeviceTranscriptionController.addError(e);
      }
    }
    // Cloud mode: server handles transcription automatically
  }

  @override
  Future<bool> hasPermission() => _audioRecorder.hasPermission();

  @override
  Future<bool> requestPermission() => _audioRecorder.requestPermission();

  @override
  void dispose() {
    _audioRecorder.dispose();
    _wsService.dispose();
    _hybridService.dispose();
    _onDeviceTranscriptionController.close();
  }
}
