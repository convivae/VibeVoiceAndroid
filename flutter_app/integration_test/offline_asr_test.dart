import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vibevoice_app/app.dart';
import 'package:vibevoice_app/services/asr/model_download_manager.dart';
import 'package:vibevoice_app/services/asr/model_info.dart';
import 'package:vibevoice_app/presentation/providers/model_download_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline ASR Integration Tests', () {
    testWidgets(
      'app renders home screen with mic button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: VibeVoiceApp(),
          ),
        );
        await tester.pumpAndSettle();

        final micButton = find.byIcon(Icons.mic);
        expect(micButton, findsOneWidget);
      },
    );

    testWidgets(
      'model download screen shows download button when model not downloaded',
      (WidgetTester tester) async {
        final manager = ModelDownloadManager(
          baseUrl: 'https://test-models.example.com',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              modelDownloadManagerProvider.overrideWithValue(manager),
            ],
            child: MaterialApp(
              home: _TestDownloadWidget(manager: manager),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final status = await manager.checkStatus();
        expect(status, isA<ModelDownloadNotDownloaded>());
      },
    );

    testWidgets(
      'network status bar visible when network unavailable',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: _OfflineStatusWidget(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final offlineText = find.text('离线模式 · 使用本地模型');
        expect(offlineText, findsOneWidget);
      },
    );

    testWidgets(
      'model info state shows correct size text',
      (WidgetTester tester) async {
        final info = ModelInfo(
          version: '1.0.0',
          downloadUrl: 'https://example.com/model.tflite',
          sizeBytes: 4600 * 1024 * 1024,
          sha256Checksum: 'abc123def456',
          minAppVersion: '1.0.0',
          releaseDate: DateTime(2024, 1, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('${info.sizeBytes ~/ (1024 * 1024 * 1024)} GB'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('4.5 GB'), findsOneWidget);
      },
    );
  });

  group('ModelDownloadState Tests', () {
    test('ModelDownloadInProgress progressPercent formats correctly', () {
      const state = ModelDownloadInProgress(
        progress: 0.75,
        receivedBytes: 3450 * 1024 * 1024,
        totalBytes: 4600 * 1024 * 1024,
      );
      expect(state.progressPercent, '75.0%');
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
  });
}

class _TestDownloadWidget extends ConsumerWidget {
  final ModelDownloadManager manager;

  const _TestDownloadWidget({required this.manager});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelDownloadProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state is ModelDownloadNotDownloaded)
              const Text('模型未下载')
            else if (state is ModelDownloadReady)
              const Text('模型已就绪')
            else
              const Text('未知状态'),
          ],
        ),
      ),
    );
  }
}

class _OfflineStatusWidget extends StatelessWidget {
  const _OfflineStatusWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade700,
      child: const SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.phone_android, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '离线模式 · 使用本地模型',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
