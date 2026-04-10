import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asr_result.dart';
import '../../domain/repositories/voice_repository.dart';
import 'providers.dart';

/// Microphone permission status.
enum PermissionStatus {
  /// Permission state unknown (not yet checked)
  unknown,
  /// Permission granted
  granted,
  /// Permission denied (user can retry)
  denied,
  /// Permission permanently denied (user must go to settings)
  permanentlyDenied,
}

/// Immutable state for the ASR voice input feature.
class AsrState {
  /// Current transcription text (partial during streaming, complete when final)
  final String transcriptionText;

  /// Full transcription history for this session.
  /// Each entry is a final result that the user can copy.
  final List<String> transcriptionHistory;

  /// Whether the microphone is currently recording audio.
  final bool isRecording;

  /// Whether we're waiting for a final transcription result.
  final bool isProcessing;

  /// Current language code ('zh' for Mandarin, 'en' for English) (D-15).
  final String language;

  /// Error message if something went wrong.
  final String? errorMessage;

  /// Microphone permission status.
  final PermissionStatus microphonePermission;

  const AsrState({
    this.transcriptionText = '',
    this.transcriptionHistory = const [],
    this.isRecording = false,
    this.isProcessing = false,
    this.language = 'zh',
    this.errorMessage,
    this.microphonePermission = PermissionStatus.unknown,
  });

  AsrState copyWith({
    String? transcriptionText,
    List<String>? transcriptionHistory,
    bool? isRecording,
    bool? isProcessing,
    String? language,
    String? errorMessage,
    PermissionStatus? microphonePermission,
    bool clearError = false,
    bool clearTranscription = false,
  }) {
    return AsrState(
      transcriptionText:
          clearTranscription ? '' : (transcriptionText ?? this.transcriptionText),
      transcriptionHistory: transcriptionHistory ?? this.transcriptionHistory,
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      language: language ?? this.language,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      microphonePermission: microphonePermission ?? this.microphonePermission,
    );
  }
}

/// Notifier that manages the ASR voice input state.
/// Coordinates between VoiceRepository, audio recording, and transcription results.
class AsrNotifier extends StateNotifier<AsrState> {
  final VoiceRepository _repository;
  final Ref _ref;

  StreamSubscription<AsrResult>? _transcriptionSubscription;
  StreamSubscription<ConnectionState>? _connectionSubscription;

  AsrNotifier(this._repository, this._ref) : super(const AsrState()) {
    _init();
  }

  void _init() {
    _transcriptionSubscription = _repository.transcriptionStream.listen(
      _onTranscriptionResult,
      onError: _onTranscriptionError,
    );

    _connectionSubscription = _repository.connectionStateStream.listen(
      _onConnectionStateChanged,
    );

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await _repository.hasPermission();
    state = state.copyWith(
      microphonePermission:
          granted ? PermissionStatus.granted : PermissionStatus.unknown,
    );
  }

  Future<void> requestPermission() async {
    final granted = await _repository.requestPermission();
    state = state.copyWith(
      microphonePermission: granted
          ? PermissionStatus.granted
          : PermissionStatus.denied,
    );
  }

  void _onTranscriptionResult(AsrResult result) {
    if (result.isFinal) {
      final newHistory = [...state.transcriptionHistory, result.text];
      state = state.copyWith(
        transcriptionText: result.text,
        transcriptionHistory: newHistory,
        isProcessing: false,
      );
    } else {
      state = state.copyWith(
        transcriptionText: result.text,
        isProcessing: true,
      );
    }
  }

  void _onTranscriptionError(Object error) {
    state = state.copyWith(
      errorMessage: '转写失败: ${error.toString()}',
      isProcessing: false,
      isRecording: false,
    );
  }

  void _onConnectionStateChanged(ConnectionState connState) {
    if (connState == ConnectionState.failed) {
      state = state.copyWith(
        errorMessage: '连接失败，请检查网络',
        isRecording: false,
      );
    }
  }

  /// Start recording when user presses and holds the mic button (D-14).
  Future<void> startRecording() async {
    if (state.microphonePermission != PermissionStatus.granted) {
      await requestPermission();
      if (state.microphonePermission != PermissionStatus.granted) {
        state = state.copyWith(
          errorMessage: '请授予麦克风权限',
          microphonePermission: PermissionStatus.denied,
        );
        return;
      }
    }

    state = state.copyWith(
      clearError: true,
      clearTranscription: true,
      isRecording: true,
    );

    try {
      await _repository.connect();
      await _repository.startRecording();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permission') || msg.contains('Permission')) {
        state = state.copyWith(
          errorMessage: '麦克风权限被拒绝',
          microphonePermission: PermissionStatus.denied,
          isRecording: false,
        );
      } else {
        state = state.copyWith(
          errorMessage: '录音失败: $msg',
          isRecording: false,
        );
      }
    }
  }

  /// Stop recording when user releases the mic button (D-14).
  Future<void> stopRecording() async {
    state = state.copyWith(isRecording: false, isProcessing: true);

    try {
      await _repository.stopRecording();
    } catch (e) {
      state = state.copyWith(
        errorMessage: '停止录音失败: ${e.toString()}',
        isProcessing: false,
      );
    }
  }

  /// Toggle language between Mandarin and English (D-15).
  void toggleLanguage() {
    final newLang = state.language == 'zh' ? 'en' : 'zh';
    _repository.language = newLang;
    state = state.copyWith(language: newLang);
  }

  /// Set language explicitly.
  void setLanguage(String lang) {
    _repository.language = lang;
    state = state.copyWith(language: lang);
  }

  /// Clear the current (uncommitted) transcription text.
  void clearCurrentTranscription() {
    state = state.copyWith(clearTranscription: true);
  }

  /// Dismiss the current error message.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _transcriptionSubscription?.cancel();
    _connectionSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

/// Main provider for ASR state.
final asrProvider = StateNotifierProvider<AsrNotifier, AsrState>((ref) {
  final repository = ref.watch(voiceRepositoryProvider);
  return AsrNotifier(repository, ref);
});

/// Convenience providers for common state slices.

final isRecordingProvider = Provider<bool>((ref) {
  return ref.watch(asrProvider).isRecording;
});

final transcriptionTextProvider = Provider<String>((ref) {
  return ref.watch(asrProvider).transcriptionText;
});

final transcriptionHistoryProvider = Provider<List<String>>((ref) {
  return ref.watch(asrProvider).transcriptionHistory;
});

final currentLanguageProvider = Provider<String>((ref) {
  return ref.watch(asrProvider).language;
});

final microphonePermissionProvider = Provider<PermissionStatus>((ref) {
  return ref.watch(asrProvider).microphonePermission;
});

final isProcessingProvider = Provider<bool>((ref) {
  return ref.watch(asrProvider).isProcessing;
});

final asrErrorMessageProvider = Provider<String?>((ref) {
  return ref.watch(asrProvider).errorMessage;
});
