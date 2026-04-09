import 'dart:typed_data';

/// Represents a single PCM16 audio chunk captured from the microphone.
/// Produced by AudioRecorderService, consumed by WebSocketService.
class VoiceChunk {
  /// Raw PCM16 audio data (mono, 16kHz, little-endian)
  final Uint8List data;
  
  /// Timestamp when this chunk was captured (milliseconds since epoch)
  final int timestampMs;
  
  /// Duration of this chunk in milliseconds
  /// Should always be ~50ms per D-11
  final int durationMs;
  
  const VoiceChunk({
    required this.data,
    required this.timestampMs,
    this.durationMs = 50,
  });
  
  /// Number of bytes in this chunk
  int get byteLength => data.length;
  
  /// Check if chunk has valid size (approximately 1600 bytes at 16kHz mono PCM16)
  bool get isValid => data.length >= 1200 && data.length <= 2000;
}
