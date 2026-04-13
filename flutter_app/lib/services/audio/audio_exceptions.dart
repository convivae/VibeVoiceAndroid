/// Exception types for audio recording services.
/// Centralized definitions to avoid import conflicts.

/// Thrown when microphone permission is denied.
class MicrophonePermissionDeniedException implements Exception {
  final String message;
  MicrophonePermissionDeniedException([this.message = 'Microphone permission denied']);
  @override String toString() => message;
}

/// Thrown when audio recording encounters an error.
class RecordingException implements Exception {
  final String message;
  RecordingException(this.message);
  @override String toString() => 'RecordingException: $message';
}
