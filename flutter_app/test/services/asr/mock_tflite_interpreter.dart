/// Mock TFLite Interpreter for unit testing.
/// Allows testing OnDeviceAsrEngine without an actual TFLite model.
class MockTFLiteInterpreter {
  final bool shouldSucceed;
  final String outputText;
  final Duration inferenceDelay;
  final Exception? error;

  MockTFLiteInterpreter({
    this.shouldSucceed = true,
    this.outputText = '测试转写结果',
    this.inferenceDelay = Duration.zero,
    this.error,
  });

  /// Simulate inference delay.
  Future<String> runInference(List<int> audioData) async {
    if (inferenceDelay > Duration.zero) {
      await Future.delayed(inferenceDelay);
    }

    if (error != null) {
      throw error!;
    }

    if (!shouldSucceed) {
      throw Exception('Mock inference failed');
    }

    return outputText;
  }
}

/// Mock TFLite package functions.
class MockTfliteFlutter {
  static bool gpuEnabled = false;
  static bool nnApiEnabled = false;

  static void reset() {
    gpuEnabled = false;
    nnApiEnabled = false;
  }
}

/// Test data generators.
class TestAudioData {
/// Generate 1 second of 16kHz PCM16 audio (all zeros).
  static List<int> oneSecondSilence() {
    return List.filled(16000 * 2, 0);
  }

  /// Generate 60 seconds of 16kHz PCM16 audio (all zeros).
  static List<int> sixtySecondSilence() {
    return List.filled(16000 * 2 * 60, 0);
  }

  /// Generate audio that's too large (> 60 seconds).
  static List<int> tooLargeAudio() {
    return List.filled(16000 * 2 * 120, 0); // 120 seconds
  }
}

void main() {} // Placeholder — imported by actual test files