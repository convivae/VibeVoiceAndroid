/// Result of ASR transcription from the cloud server.
class AsrResult {
  /// The transcribed text
  final String text;
  
  /// Whether this is the final (complete) transcription.
  /// False means partial/interim result during streaming.
  final bool isFinal;
  
  /// Timestamp when this result was received (milliseconds since epoch)
  final int timestampMs;
  
  const AsrResult({
    required this.text,
    required this.isFinal,
    required this.timestampMs,
  });
  
  /// Factory for parsing from server JSON
  factory AsrResult.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (type == 'done') {
      return AsrResult(
        text: json['text'] as String? ?? '',
        isFinal: true,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
    } else if (type == 'transcript') {
      return AsrResult(
        text: json['text'] as String? ?? '',
        isFinal: json['is_final'] as bool? ?? false,
        timestampMs: json['timestamp_ms'] as int? 
            ?? DateTime.now().millisecondsSinceEpoch,
      );
    }
    throw FormatException('Unknown ASR result type: $type');
  }
  
  /// Empty result (no transcription yet)
  factory AsrResult.empty() => AsrResult(
    text: '',
    isFinal: false,
    timestampMs: DateTime.now().millisecondsSinceEpoch,
  );
}

/// WebSocket connection states (per D-19)
enum ConnectionState {
  /// Not connected, idle
  disconnected,
  
  /// Attempting to connect
  connecting,
  
  /// Successfully connected and ready
  connected,
  
  /// Lost connection, attempting to reconnect (per D-18)
  reconnecting,
  
  /// Permanently failed after max retries
  failed,
  
  /// Recording audio but not yet connected
  recording,
  
  /// Audio sent, waiting for transcription result
  processing,
}

extension ConnectionStateX on ConnectionState {
  /// Human-readable status text for UI display (per D-19, D-20)
  String get statusText {
    switch (this) {
      case ConnectionState.disconnected:
        return '未连接';
      case ConnectionState.connecting:
        return '连接中...';
      case ConnectionState.connected:
        return '已连接';
      case ConnectionState.reconnecting:
        return '正在重连...';
      case ConnectionState.failed:
        return '连接失败';
      case ConnectionState.recording:
        return '录音中...';
      case ConnectionState.processing:
        return '转写中...';
    }
  }
  
  /// Whether this state indicates an error condition
  bool get isError => this == ConnectionState.failed;
  
  /// Whether the user can interact (try recording)
  bool get canRecord => this == ConnectionState.connected || 
                        this == ConnectionState.disconnected;
}
