import 'dart:typed_data';
import '../../domain/entities/asr_result.dart';
import '../../domain/repositories/voice_repository.dart';
import '../../core/config/api_config.dart';
import '../../services/audio/audio_exceptions.dart';
import '../../services/audio/audio_recorder_service.dart';
import '../../services/websocket/websocket_service.dart';

/// Implementation of VoiceRepository using AudioRecorderService and WebSocketService.
/// Wires the audio stream to the WebSocket connection.
class VoiceRepositoryImpl implements VoiceRepository {
  final AudioRecorderService _audioRecorder;
  final WebSocketService _wsService;
  
  VoiceRepositoryImpl({
    required AudioRecorderService audioRecorder,
    required WebSocketService wsService,
  })  : _audioRecorder = audioRecorder,
        _wsService = wsService;
  
  String _language = 'zh';  // Default: Mandarin (per D-15)
  
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
  
  @override
  Stream<AsrResult> get transcriptionStream =>
      _wsService.messageStream.map((json) => AsrResult.fromJson(json));
  
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
    // Check permission
    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      throw MicrophonePermissionDeniedException();
    }
    
    // Start WebSocket if not connected
    if (connectionState != WsConnectionState.connected) {
      await connect();
    }
    
    // Send start message with language
    _wsService.sendStart(language: _language);
    
    // Start audio stream and pipe to WebSocket
    final audioStream = _audioRecorder.startStream();
    
    audioStream.listen(
      (chunk) {
        // Pipe audio chunk directly to WebSocket
        _wsService.sendAudioChunk(chunk);
        onChunkRecorded?.call(chunk);
      },
      onError: (error) {
        // Surface recording errors
        throw RecordingException(error.toString());
      },
    );
  }
  
  @override
  Future<void> stopRecording() async {
    // Stop recording — this ends the audio stream
    await _audioRecorder.stop();
    // Server will process accumulated audio and send final transcription
  }
  
  @override
  Future<bool> hasPermission() => _audioRecorder.hasPermission();
  
  @override
  Future<bool> requestPermission() => _audioRecorder.requestPermission();
  
  @override
  void dispose() {
    _audioRecorder.dispose();
    _wsService.dispose();
  }
}
