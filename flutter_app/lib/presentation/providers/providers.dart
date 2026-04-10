import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/voice_repository_impl.dart';
import '../../services/audio/audio_recorder_service.dart';
import '../../services/websocket/websocket_service.dart';

/// Provider for the AudioRecorderService.
/// Creates a new instance and disposes it when the provider is disposed.
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the WebSocketService.
/// Creates a new instance and disposes it when the provider is disposed.
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the VoiceRepository.
/// Combines AudioRecorderService and WebSocketService.
/// Watches the underlying services so it rebuilds when they change.
final voiceRepositoryProvider = Provider<VoiceRepositoryImpl>((ref) {
  final audioRecorder = ref.watch(audioRecorderServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  return VoiceRepositoryImpl(
    audioRecorder: audioRecorder,
    wsService: wsService,
  );
});
