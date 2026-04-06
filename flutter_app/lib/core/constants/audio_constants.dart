/// Audio recording parameters (D-09, D-10, D-11)
/// These must match what the VibeVoice-ASR server expects.
class AudioConstants {
  /// Sample rate: 16kHz (D-10)
  static const int sampleRate = 16000;
  
  /// Mono channel (D-10)
  static const int numChannels = 1;
  
  /// 16-bit PCM (D-10)
  static const int bitsPerSample = 16;
  
  /// 50ms per chunk (D-11)
  /// Bytes per chunk = 16000 * 50 / 1000 * 2 = 1600 bytes
  static const int bytesPerChunk = 1600;
  
  /// Chunk duration in milliseconds (D-11)
  static const int chunkDurationMs = 50;
  
  /// Buffer size for audio recording
  static const int bufferSize = 4096;
}
