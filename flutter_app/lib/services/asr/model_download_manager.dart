import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'model_info.dart';

/// Manages model download, storage, and version updates (D-05, D-07, D-08).
class ModelDownloadManager {
  static const String _modelFileName = 'vibevoice_asr.tflite';
  static const String _modelInfoFileName = 'model_info.json';
  static const String _modelServerBaseUrl = 'https://models.vibevoice.app';
  
  final Dio _dio;
  final String _baseUrl;
  
  ModelDownloadManager({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
        )),
        _baseUrl = baseUrl ?? _modelServerBaseUrl;
  
  /// Get the local path for the model file.
  Future<String> _getLocalModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models/$_modelFileName';
  }
  
  /// Get the local path for model_info.json.
  Future<String> _getLocalInfoPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models/$_modelInfoFileName';
  }
  
  /// Check current model status.
  Future<ModelDownloadState> checkStatus() async {
    final modelPath = await _getLocalModelPath();
    final infoPath = await _getLocalInfoPath();
    
    // Check if model exists locally
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      return const ModelDownloadNotDownloaded();
    }
    
    // Load local info if exists
    ModelInfo? localInfo;
    if (await File(infoPath).exists()) {
      final localJson = jsonDecode(await File(infoPath).readAsString());
      localInfo = ModelInfo.fromJson(localJson);
    }
    
    // Check for remote updates
    try {
      final remoteInfo = await _fetchRemoteModelInfo();
      
      if (localInfo == null) {
        return ModelDownloadReady(remoteInfo);
      }
      
      if (_compareVersions(localInfo.version, remoteInfo.version) < 0) {
        return ModelDownloadUpdateAvailable(
          currentInfo: localInfo,
          newInfo: remoteInfo,
        );
      }
      
      return ModelDownloadReady(localInfo);
    } catch (e) {
      // Network error, assume local version is fine
      if (localInfo != null) {
        return ModelDownloadReady(localInfo);
      }
      return const ModelDownloadNotDownloaded();
    }
  }
  
  /// Fetch model info from server.
  Future<ModelInfo> _fetchRemoteModelInfo() async {
    final response = await _dio.get('$_baseUrl/model_info.json');
    return ModelInfo.fromJson(response.data);
  }
  
  /// Download the model with progress tracking (D-06).
  Future<void> downloadModel({
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      // Get model info
      final info = await _fetchRemoteModelInfo();
      
      // Ensure directory exists
      final modelDir = File(await _getLocalModelPath()).parent;
      await modelDir.create(recursive: true);
      
      // Download with progress
      final modelPath = await _getLocalModelPath();
      await _dio.download(
        info.downloadUrl,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );
      
      // Verify integrity (per security requirements)
      onProgress(-1.0);  // Signal verification started
      final isValid = await _verifyChecksum(modelPath, info.sha256Checksum);
      
      if (!isValid) {
        // Delete corrupted file
        await File(modelPath).delete();
        onError('Model integrity check failed. Please download again.');
        return;
      }
      
      // Save model info locally
      final infoPath = await _getLocalInfoPath();
      await File(infoPath).writeAsString(jsonEncode(info.toJson()));
      
      onComplete();
    } on DioException catch (e) {
      onError('Download failed: ${e.message}');
    } catch (e) {
      onError('Download failed: $e');
    }
  }
  
  /// Verify SHA256 checksum of downloaded model (per security requirements).
  Future<bool> _verifyChecksum(String filePath, String expectedChecksum) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      return hash.toLowerCase() == expectedChecksum.toLowerCase();
    } catch (e) {
      debugPrint('Checksum verification error: $e');
      return false;
    }
  }
  
  /// Compare semantic versions (e.g., "1.0.0" vs "1.0.1").
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }
  
  /// Get the local model path (throws if not exists).
  Future<String> getModelPath() async {
    final path = await _getLocalModelPath();
    if (!await File(path).exists()) {
      throw StateError('Model not downloaded. Call downloadModel() first.');
    }
    return path;
  }
  
  /// Delete local model (for storage cleanup).
  Future<void> deleteModel() async {
    final modelPath = await _getLocalModelPath();
    final infoPath = await _getLocalInfoPath();
    
    if (await File(modelPath).exists()) {
      await File(modelPath).delete();
    }
    if (await File(infoPath).exists()) {
      await File(infoPath).delete();
    }
  }
  
  /// Get local model size in bytes (0 if not downloaded).
  Future<int> getLocalModelSize() async {
    final modelPath = await _getLocalModelPath();
    if (await File(modelPath).exists()) {
      return File(modelPath).length();
    }
    return 0;
  }
}