import 'package:flutter_test/flutter_test.dart';
import 'package:vibevoice_app/services/asr/model_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelInfo', () {
    test('fromJson() parses correctly', () {
      final json = {
        'version': '1.0.0',
        'download_url': 'https://example.com/model.tflite',
        'size_bytes': 4600 * 1024 * 1024,
        'sha256_checksum': 'abc123def456',
        'min_app_version': '1.0.0',
        'release_date': '2024-01-01T00:00:00Z',
      };

      final info = ModelInfo.fromJson(json);
      expect(info.version, '1.0.0');
      expect(info.sizeBytes, 4600 * 1024 * 1024);
      expect(info.sha256Checksum, 'abc123def456');
    });

    test('toJson() round-trip works', () {
      final info = ModelInfo(
        version: '1.0.0',
        downloadUrl: 'https://example.com/model.tflite',
        sizeBytes: 4600 * 1024 * 1024,
        sha256Checksum: 'abc123def456',
        minAppVersion: '1.0.0',
        releaseDate: DateTime(2024, 1, 1),
      );

      final json = info.toJson();
      final restored = ModelInfo.fromJson(json);

      expect(restored.version, info.version);
      expect(restored.sizeBytes, info.sizeBytes);
      expect(restored.sha256Checksum, info.sha256Checksum);
    });
  });

  group('ModelDownloadState', () {
    test('ModelDownloadNotDownloaded is distinct state', () {
      const state = ModelDownloadNotDownloaded();
      expect(state, isA<ModelDownloadState>());
    });

    test('ModelDownloadInProgress progressPercent formats correctly', () {
      const state = ModelDownloadInProgress(
        progress: 0.5,
        receivedBytes: 2300 * 1024 * 1024,
        totalBytes: 4600 * 1024 * 1024,
      );
      expect(state.progressPercent, '50.0%');
      expect(state.sizeText, '4.5 GB');
    });

    test('ModelDownloadInProgress with zero progress', () {
      const state = ModelDownloadInProgress(
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 4600 * 1024 * 1024,
      );
      expect(state.progressPercent, '0.0%');
      expect(state.sizeText, '4.5 GB');
    });

    test('ModelDownloadInProgress with 100 percent', () {
      const state = ModelDownloadInProgress(
        progress: 1.0,
        receivedBytes: 4600 * 1024 * 1024,
        totalBytes: 4600 * 1024 * 1024,
      );
      expect(state.progressPercent, '100.0%');
    });

    test('ModelDownloadReady holds model info', () {
      final info = ModelInfo(
        version: '1.0.0',
        downloadUrl: 'https://example.com/model.tflite',
        sizeBytes: 4600 * 1024 * 1024,
        sha256Checksum: 'abc123',
        minAppVersion: '1.0.0',
        releaseDate: DateTime(2024, 1, 1),
      );
      final state = ModelDownloadReady(info);
      expect(state.info.version, '1.0.0');
    });

    test('ModelDownloadError holds error message', () {
      const state = ModelDownloadError('Network timeout');
      expect(state.message, 'Network timeout');
    });

    test('ModelDownloadVerifying is distinct state', () {
      const state = ModelDownloadVerifying();
      expect(state, isA<ModelDownloadState>());
    });

    test('ModelDownloadUpdateAvailable holds both versions', () {
      final current = ModelInfo(
        version: '1.0.0',
        downloadUrl: 'https://example.com/v1.tflite',
        sizeBytes: 4600 * 1024 * 1024,
        sha256Checksum: 'abc123',
        minAppVersion: '1.0.0',
        releaseDate: DateTime(2024, 1, 1),
      );
      final newer = ModelInfo(
        version: '1.1.0',
        downloadUrl: 'https://example.com/v2.tflite',
        sizeBytes: 4600 * 1024 * 1024,
        sha256Checksum: 'def456',
        minAppVersion: '1.0.0',
        releaseDate: DateTime(2024, 3, 1),
      );
      final state = ModelDownloadUpdateAvailable(
        currentInfo: current,
        newInfo: newer,
      );
      expect(state.currentInfo.version, '1.0.0');
      expect(state.newInfo.version, '1.1.0');
    });
  });
}
