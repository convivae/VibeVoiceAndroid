import 'dart:typed_data';
import '../entities/asr_result.dart';

/// Repository interface for voice recording and ASR transcription.
/// Abstracts over the audio recorder and WebSocket service.
/// This is the interface — implementation is in voice_repository_impl.dart.
abstract class VoiceRepository {
  /// Current connection state
  Stream<WsConnectionState> get connectionStateStream;
  WsConnectionState get connectionState;
  
  /// Stream of transcription results from the server
  Stream<AsrResult> get transcriptionStream;
  
  /// Current language setting
  String get language;
  set language(String value);
  
  /// Connect to the ASR WebSocket server
  Future<void> connect();
  
  /// Disconnect from the server
  Future<void> disconnect();
  
  /// Start recording audio and streaming to server.
  /// Call this when user presses and holds the mic button.
  /// [onChunkRecorded] is called for each audio chunk.
  Future<void> startRecording({
    void Function(Uint8List chunk)? onChunkRecorded,
  });
  
  /// Stop recording audio.
  /// This triggers the server to run final ASR and send result.
  Future<void> stopRecording();
  
  /// Check if microphone permission is granted
  Future<bool> hasPermission();
  
  /// Request microphone permission
  Future<bool> requestPermission();
  
  /// Dispose resources
  void dispose();
}
