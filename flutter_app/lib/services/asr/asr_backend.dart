import 'dart:typed_data';
import '../../domain/entities/asr_result.dart';

/// Abstract interface for ASR backends (D-16).
/// Both cloud and on-device implementations implement this interface.
abstract class AsrBackend {
  /// Check if this backend is currently available.
  /// For cloud: has network connection.
  /// For on-device: model downloaded AND (network unavailable OR preferred).
  bool get isAvailable;

  /// Transcribe audio data to text.
  /// [audioData]: 16kHz PCM16 audio bytes
  /// [language]: Language code ('zh' or 'en')
  Future<AsrResult> transcribe(Uint8List audioData, String language);

  /// Initialize the backend (load model, establish connection).
  /// Called once when app starts or when backend is first needed.
  Future<void> initialize();

  /// Dispose resources.
  void dispose();
}