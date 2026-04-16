import 'dart:async';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/asr_result.dart';
import 'on_device_asr_backend.dart';
import 'cloud_asr_backend.dart';

/// Hybrid ASR service that routes between on-device and cloud backends.
/// Implements D-02: on-device priority, auto-fallback to cloud.
/// Implements D-17: connectivity_plus for network detection.
class HybridAsrService {
  final OnDeviceAsrBackend _onDeviceBackend;
  final CloudAsrBackend _cloudBackend;
  final Connectivity _connectivity;
  final Dio _dio;
  final String _apiBaseUrl;

  HybridAsrService({
    OnDeviceAsrBackend? onDeviceBackend,
    CloudAsrBackend? cloudBackend,
    Connectivity? connectivity,
    Dio? dio,
    String? apiBaseUrl,
  })  : _onDeviceBackend = onDeviceBackend ?? OnDeviceAsrBackend(),
        _cloudBackend = cloudBackend ?? CloudAsrBackend(),
        _connectivity = connectivity ?? Connectivity(),
        _dio = dio ?? Dio(),
        _apiBaseUrl = apiBaseUrl ?? 'https://api.vibevoice.app';

  /// Check if on-device ASR is available.
  /// Conditions: model downloaded AND (network unavailable OR preference for on-device)
  Future<bool> isOnDeviceAvailable() async {
    // Check 1: Model downloaded
    if (!_onDeviceBackend.isAvailable) {
      return false;
    }

    // On-device works when offline OR when model is ready
    // Even if network is available, on-device is preferred for offline capability
    return true; // Model is ready
  }

  /// Check if cloud ASR is available.
  /// Requires: network connected AND server reachable.
  Future<bool> isCloudAvailable() async {
    // Check 1: Network connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    // Check 2: Actually try to reach the server (per RESEARCH.md Pitfall 5)
    try {
      final response = await _dio.head(
        '$_apiBaseUrl/health',
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Transcribe audio using the best available backend.
  /// Priority: on-device (if available) > cloud (if available) > error
  Future<AsrResult> transcribe(Uint8List audioData, String language) async {
    // Try on-device first (D-02: on-device priority)
    if (await isOnDeviceAvailable()) {
      try {
        debugPrint('HybridAsrService: Using on-device ASR');
        return await _onDeviceBackend.transcribe(audioData, language);
      } catch (e) {
        debugPrint('HybridAsrService: On-device failed: $e');
        // Fall through to cloud fallback
      }
    }

    // Cloud fallback (D-02: auto-fallback to cloud)
    if (await isCloudAvailable()) {
      try {
        debugPrint('HybridAsrService: Using cloud ASR');
        return await _cloudBackend.transcribe(audioData, language);
      } catch (e) {
        debugPrint('HybridAsrService: Cloud failed: $e');
        // Both failed
        throw AsrException('No ASR backend available');
      }
    }

    // Neither available
    throw AsrException('No ASR backend available. '
        'On-device model not downloaded and cloud unreachable.');
  }

  /// Get current routing status for UI display.
  Future<HybridRoutingStatus> getRoutingStatus() async {
    final onDeviceAvailable = await isOnDeviceAvailable();
    final cloudAvailable = await isCloudAvailable();

    if (onDeviceAvailable) {
      return HybridRoutingStatus.onDevice;
    } else if (cloudAvailable) {
      return HybridRoutingStatus.cloud;
    } else {
      return HybridRoutingStatus.unavailable;
    }
  }

  /// Initialize both backends.
  Future<void> initialize() async {
    // Initialize on-device backend (loads TFLite model)
    // This may fail if model not downloaded - that's OK
    try {
      await _onDeviceBackend.initialize();
    } catch (e) {
      debugPrint('HybridAsrService: On-device init failed: $e');
    }

    // Initialize cloud backend
    try {
      await _cloudBackend.initialize();
    } catch (e) {
      debugPrint('HybridAsrService: Cloud init failed: $e');
    }
  }

  /// Dispose resources.
  void dispose() {
    _onDeviceBackend.dispose();
    _cloudBackend.dispose();
  }
}

/// Routing status for UI display.
enum HybridRoutingStatus {
  /// On-device ASR is active
  onDevice,

  /// Cloud ASR is active
  cloud,

  /// Neither backend available
  unavailable,
}

/// Exception thrown when no ASR backend is available.
class AsrException implements Exception {
  final String message;

  AsrException(this.message);

  @override
  String toString() => 'AsrException: $message';
}
