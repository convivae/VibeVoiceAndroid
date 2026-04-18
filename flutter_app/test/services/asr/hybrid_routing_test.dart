import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vibevoice_app/domain/entities/asr_result.dart';
import 'package:vibevoice_app/services/asr/asr_backend.dart';
import 'package:vibevoice_app/services/asr/cloud_asr_backend.dart';
import 'package:vibevoice_app/services/asr/hybrid_asr_service.dart';
import 'package:vibevoice_app/services/asr/on_device_asr_backend.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockDio extends Mock implements Dio {}

class MockOnDeviceBackend extends Mock implements OnDeviceAsrBackend {}

class MockCloudBackend extends Mock implements CloudAsrBackend {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HybridAsrService', () {
    late HybridAsrService service;
    late MockConnectivity mockConnectivity;
    late MockDio mockDio;
    late MockOnDeviceBackend mockOnDevice;
    late MockCloudBackend mockCloud;

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
    });

    setUp(() {
      mockConnectivity = MockConnectivity();
      mockDio = MockDio();
      mockOnDevice = MockOnDeviceBackend();
      mockCloud = MockCloudBackend();

      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      // Default: health check succeeds
      when(() => mockDio.head(any())).thenAnswer(
          (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200));

      service = HybridAsrService(
        onDeviceBackend: mockOnDevice,
        cloudBackend: mockCloud,
        connectivity: mockConnectivity,
        dio: mockDio,
        apiBaseUrl: 'https://api.vibevoice.app',
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('uses on-device when available and offline', () async {
      when(() => mockOnDevice.isAvailable).thenReturn(true);
      when(() => mockOnDevice.transcribe(any(), any())).thenAnswer(
          (_) async => AsrResult(text: 'on-device', isFinal: true, timestampMs: 0));
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      final result = await service.transcribe(Uint8List(0), 'zh');

      expect(result.text, 'on-device');
      verify(() => mockOnDevice.transcribe(any(), any())).called(1);
      verifyNever(() => mockCloud.transcribe(any(), any()));
    });

    test('falls back to cloud when on-device unavailable but online', () async {
      when(() => mockOnDevice.isAvailable).thenReturn(false);
      when(() => mockCloud.transcribe(any(), any())).thenAnswer(
          (_) async => AsrResult(text: 'cloud', isFinal: true, timestampMs: 0));

      final result = await service.transcribe(Uint8List(0), 'zh');

      expect(result.text, 'cloud');
      verifyNever(() => mockOnDevice.transcribe(any(), any()));
      verify(() => mockCloud.transcribe(any(), any())).called(1);
    });

    test('throws when neither backend available', () async {
      when(() => mockOnDevice.isAvailable).thenReturn(false);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      expect(
        () => service.transcribe(Uint8List(0), 'zh'),
        throwsA(isA<AsrException>()),
      );
    });

    test('getRoutingStatus() returns correct status', () async {
      when(() => mockOnDevice.isAvailable).thenReturn(true);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      expect(await service.getRoutingStatus(), HybridRoutingStatus.onDevice);

      when(() => mockOnDevice.isAvailable).thenReturn(false);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      expect(await service.getRoutingStatus(), HybridRoutingStatus.cloud);

      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      expect(await service.getRoutingStatus(), HybridRoutingStatus.unavailable);
    });

    test('returns unavailable when cloud health check fails', () async {
      when(() => mockOnDevice.isAvailable).thenReturn(false);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(() => mockDio.head(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(await service.getRoutingStatus(), HybridRoutingStatus.unavailable);
    });
  });
}
