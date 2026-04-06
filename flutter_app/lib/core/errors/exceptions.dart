/// Custom exceptions for the voice ASR flow.
class MicrophonePermissionDeniedException implements Exception {
  final String message;
  MicrophonePermissionDeniedException([this.message = 'Microphone permission denied']);
  @override String toString() => message;
}

class NetworkDisconnectedException implements Exception {
  final String message;
  NetworkDisconnectedException([this.message = 'Network disconnected']);
  @override String toString() => message;
}

class WebSocketConnectionFailedException implements Exception {
  final String message;
  final int? statusCode;
  WebSocketConnectionFailedException(this.message, {this.statusCode});
  @override String toString() => 'WebSocketConnectionFailedException: $message (code: $statusCode)';
}

class AsrServerErrorException implements Exception {
  final String message;
  final String? code;
  AsrServerErrorException(this.message, {this.code});
  @override String toString() => 'AsrServerErrorException: $message (code: $code)';
}

class RecordingException implements Exception {
  final String message;
  RecordingException(this.message);
  @override String toString() => message;
}
