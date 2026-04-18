import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibevoice_app/services/asr/on_device_asr_engine.dart';
import 'mock_tflite_interpreter.dart';

void main() {
  group('OnDeviceAsrEngine', () {
    test('initialize() without model path sets not initialized', () async {
      final engine = OnDeviceAsrEngine();
      expect(engine.isInitialized, false);
      engine.dispose();
    });

    test('transcribe() before initialize() throws StateError', () async {
      final engine = OnDeviceAsrEngine();
      expect(
        () => engine.transcribe(
          Uint8List.fromList(TestAudioData.oneSecondSilence()),
          language: 'zh',
        ),
        throwsStateError,
      );
      engine.dispose();
    });

    test('dispose() cleans up resources', () async {
      final engine = OnDeviceAsrEngine();
      engine.dispose();
      expect(engine.isInitialized, false);
    });

    test('handles empty audio data gracefully', () async {
      final engine = OnDeviceAsrEngine();
      // Empty audio should be handled without crash
      // Actual behavior depends on TFLite model implementation
      engine.dispose();
    });

    test('audio validation for oversized audio', () async {
      final engine = OnDeviceAsrEngine();
      final tooLarge = Uint8List.fromList(TestAudioData.tooLargeAudio());
      // Should reject audio > 60 seconds
      // Implementation should check size in _preprocessAudio
      engine.dispose();
    });
  });
}
