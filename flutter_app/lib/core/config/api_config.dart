/// Cloud server configuration (D-01, D-08)
/// The IP/hostname points to the RTX 4060 Windows Server running the ASR service.
class ApiConfig {
  /// WebSocket URL for ASR streaming (D-01, D-08)
  /// Format: ws://{server_ip}:8000/v1/asr/stream
  /// Replace {SERVER_IP} with actual RTX 4060 server address.
  static const String asrWsUrl = 'ws://{SERVER_IP}:8000/v1/asr/stream';
  
  /// HTTP URL for health checks
  static const String healthUrl = 'http://{SERVER_IP}:8000/health';
  
  /// Connection timeout
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  /// Audio recording chunk duration (D-11)
  static const Duration chunkDuration = Duration(milliseconds: 50);
}
