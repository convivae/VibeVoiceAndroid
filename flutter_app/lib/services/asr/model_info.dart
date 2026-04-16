/// Model metadata downloaded from server (D-08).
class ModelInfo {
  /// Semantic version of the model (e.g., "1.0.0")
  final String version;
  
  /// Download URL for the TFLite model file
  final String downloadUrl;
  
  /// File size in bytes
  final int sizeBytes;
  
  /// SHA256 checksum for integrity verification (per security requirements)
  final String sha256Checksum;
  
  /// Minimum app version required
  final String minAppVersion;
  
  /// Release date
  final DateTime releaseDate;
  
  const ModelInfo({
    required this.version,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256Checksum,
    required this.minAppVersion,
    required this.releaseDate,
  });
  
  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      version: json['version'] as String,
      downloadUrl: json['download_url'] as String,
      sizeBytes: json['size_bytes'] as int,
      sha256Checksum: json['sha256_checksum'] as String,
      minAppVersion: json['min_app_version'] as String,
      releaseDate: DateTime.parse(json['release_date'] as String),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'version': version,
    'download_url': downloadUrl,
    'size_bytes': sizeBytes,
    'sha256_checksum': sha256Checksum,
    'min_app_version': minAppVersion,
    'release_date': releaseDate.toIso8601String(),
  };
}

/// Model download state for UI (D-06).
sealed class ModelDownloadState {
  const ModelDownloadState();
}

class ModelDownloadNotStarted extends ModelDownloadState {
  const ModelDownloadNotStarted();
}

class ModelDownloadInProgress extends ModelDownloadState {
  final double progress;  // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  
  const ModelDownloadInProgress({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
  });
  
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';
  String get sizeText => '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class ModelDownloadVerifying extends ModelDownloadState {
  const ModelDownloadVerifying();
}

class ModelDownloadReady extends ModelDownloadState {
  final ModelInfo info;
  const ModelDownloadReady(this.info);
}

class ModelDownloadUpdateAvailable extends ModelDownloadState {
  final ModelInfo currentInfo;
  final ModelInfo newInfo;
  const ModelDownloadUpdateAvailable({
    required this.currentInfo,
    required this.newInfo,
  });
}

class ModelDownloadError extends ModelDownloadState {
  final String message;
  const ModelDownloadError(this.message);
}

class ModelDownloadNotDownloaded extends ModelDownloadState {
  const ModelDownloadNotDownloaded();
}