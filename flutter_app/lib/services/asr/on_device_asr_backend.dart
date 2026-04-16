import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/asr_result.dart';
import 'asr_backend.dart';
import 'on_device_asr_engine.dart';

/// On-device ASR backend using TFLite (D-16).
/// Falls back to cloud when model not available or network available.
class OnDeviceAsrBackend implements AsrBackend {
  final OnDeviceAsrEngine _engine;
  final String _modelFileName = 'vibevoice_asr.tflite';

  bool _isInitialized = false;
  bool _modelDownloaded = false;

  OnDeviceAsrBackend({
    OnDeviceAsrEngine? engine,
  }) : _engine = engine ?? OnDeviceAsrEngine();

  /// Get the local path for the model file.
  Future<String> _getLocalModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models/$_modelFileName';
  }

  /// Check if the model is downloaded.
  Future<bool> isModelDownloaded() async {
    final path = await _getLocalModelPath();
    return File(path).existsSync();
  }

  @override
  bool get isAvailable {
    // Returns true if: model downloaded AND (no network OR preference for on-device)
    // For now, just check model exists
    return _modelDownloaded;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check if model is downloaded
    final modelPath = await _getLocalModelPath();
    _modelDownloaded = File(modelPath).existsSync();

    if (!_modelDownloaded) {
      throw StateError('Model not downloaded. Call download first.');
    }

    await _engine.initialize(modelPath);
    _isInitialized = true;
  }

  @override
  Future<AsrResult> transcribe(Uint8List audioData, String language) async {
    if (!_isInitialized) {
      await initialize();
    }

    return _engine.transcribe(audioData, language: language);
  }

  @override
  void dispose() {
    _engine.dispose();
    _isInitialized = false;
    _modelDownloaded = false;
  }
}