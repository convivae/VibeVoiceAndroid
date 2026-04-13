import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../../core/constants/audio_constants.dart';
import 'audio_exceptions.dart';

/// Service for recording microphone audio as a stream of PCM16 chunks.
/// Wraps the `record` package (per D-09 — NOT `flutter_record`).
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _chunkController;
  bool _isRecording = false;

  /// Check if microphone permission is granted.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  /// Request microphone permission from the user.
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  /// Start recording and return a Stream of PCM16 audio chunks.
  /// Each chunk is approximately 1600 bytes (16kHz * 50ms * 2bytes / 1000).
  Stream<Uint8List> startStream() {
    if (_isRecording) {
      throw RecordingException('Recording already in progress');
    }

    _chunkController = StreamController<Uint8List>.broadcast(
      onCancel: () {
        _isRecording = false;
        _stopInternal();
      },
    );

    _startRecordingInternal();

    return _chunkController!.stream;
  }

  Future<void> _startRecordingInternal() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        _chunkController?.addError(
          MicrophonePermissionDeniedException(),
        );
        await _chunkController?.close();
        return;
      }

      _isRecording = true;

      // Configure for 16kHz mono PCM16 (per D-10, D-11)
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AudioConstants.sampleRate,
        numChannels: AudioConstants.numChannels,
        bitRate: AudioConstants.sampleRate * AudioConstants.bitsPerSample,
      );

      final audioStream = await _recorder.startStream(recordConfig);

      // Pipe PCM chunks to our controller
      audioStream.listen(
        (chunk) {
          if (_chunkController?.isClosed == false) {
            _chunkController?.add(chunk);
          }
        },
        onError: (error) {
          debugPrint('Audio stream error: $error');
          if (_chunkController?.isClosed == false) {
            _chunkController?.addError(RecordingException(error.toString()));
          }
        },
        onDone: () {
          _isRecording = false;
        },
      );
    } catch (e, st) {
      debugPrint('Failed to start recording: $e\n$st');
      _isRecording = false;
      _chunkController?.addError(RecordingException('Failed to start recording: $e'));
      await _chunkController?.close();
    }
  }

  /// Stop recording.
  Future<void> stop() async {
    if (!_isRecording) return;
    await _stopInternal();
  }

  Future<void> _stopInternal() async {
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }
    _isRecording = false;
    await _chunkController?.close();
    _chunkController = null;
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Dispose the recorder and close any open streams.
  void dispose() {
    _stopInternal();
    _recorder.dispose();
  }
}
