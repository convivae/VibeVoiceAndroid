import 'dart:typed_data';
import '../../domain/entities/asr_result.dart';
import 'asr_backend.dart';

/// Cloud ASR backend using WebSocket (Phase 1 implementation as AsrBackend).
/// Wraps existing VoiceRepositoryImpl functionality.
class CloudAsrBackend implements AsrBackend {
  // TODO: Wire up to existing WebSocket service
  // For now, this is a placeholder that delegates to Phase 1 implementation

  @override
  bool get isAvailable {
    // Cloud is available when network is connected
    // TODO: Implement proper connectivity check using connectivity_plus
    return true;
  }

  @override
  Future<void> initialize() async {
    // Initialize WebSocket connection
    // TODO: Delegate to existing WebSocketService
  }

  @override
  Future<AsrResult> transcribe(Uint8List audioData, String language) async {
    // TODO: Implement WebSocket transcription
    // - Connect to ASR WebSocket
    // - Stream audio chunks
    // - Return final result
    throw UnimplementedError('CloudAsrBackend.transcribe() not yet implemented');
  }

  @override
  void dispose() {
    // Clean up WebSocket connection
  }
}