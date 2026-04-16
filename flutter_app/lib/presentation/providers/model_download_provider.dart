import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/asr/model_download_manager.dart';
import '../../services/asr/model_info.dart';

/// State for model download management.
class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  final ModelDownloadManager _manager;
  
  ModelDownloadNotifier(this._manager) : super(const ModelDownloadNotStarted()) {
    _checkStatus();
  }
  
  Future<void> _checkStatus() async {
    state = await _manager.checkStatus();
  }
  
  /// Start downloading the model.
  Future<void> download() async {
    state = const ModelDownloadInProgress(
      progress: 0,
      receivedBytes: 0,
      totalBytes: 0,
    );
    
    await _manager.downloadModel(
      onProgress: (progress) {
        if (progress >= 0) {
          // progress is 0.0-1.0
          state = ModelDownloadInProgress(
            progress: progress,
            receivedBytes: (progress * 4600 * 1024 * 1024).toInt(),
            totalBytes: (400 * 1024 * 1024),
          );
        } else {
          // progress < 0 means verification in progress
          state = const ModelDownloadVerifying();
        }
      },
      onComplete: () async {
        state = await _manager.checkStatus();
      },
      onError: (error) {
        state = ModelDownloadError(error);
      },
    );
  }
  
  /// Check for updates and optionally update.
  Future<void> checkForUpdates() async {
    await _checkStatus();
  }
  
  /// Delete local model (storage cleanup).
  Future<void> deleteModel() async {
    await _manager.deleteModel();
    state = const ModelDownloadNotDownloaded();
  }
  
  /// Refresh status.
  Future<void> refresh() async {
    await _checkStatus();
  }
  
  /// Get model path (throws if not downloaded).
  Future<String> getModelPath() => _manager.getModelPath();
  
  /// Get local model size.
  Future<int> getLocalModelSize() => _manager.getLocalModelSize();
}

/// Provider for model download manager.
final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  return ModelDownloadManager();
});

/// Provider for model download state.
final modelDownloadProvider = StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  final manager = ref.watch(modelDownloadManagerProvider);
  return ModelDownloadNotifier(manager);
});

/// Convenience providers.
final isModelDownloadedProvider = Provider<bool>((ref) {
  final state = ref.watch(modelDownloadProvider);
  return state is ModelDownloadReady;
});

final downloadProgressProvider = Provider<double?>((ref) {
  final state = ref.watch(modelDownloadProvider);
  if (state is ModelDownloadInProgress) {
    return state.progress;
  }
  return null;
});