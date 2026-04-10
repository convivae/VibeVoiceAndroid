import 'package:flutter/material.dart';
import '../../domain/entities/tts_state.dart';

/// Playback control buttons: Play/Pause and Stop.
/// Per 02-CONTEXT.md D-06: Playback controls for TTS.
class PlaybackControls extends StatelessWidget {
  /// Current playback state.
  final TtsPlaybackState playbackState;

  /// Callback for play button.
  final VoidCallback onPlay;

  /// Callback for pause button.
  final VoidCallback onPause;

  /// Callback for stop button.
  final VoidCallback onStop;

  const PlaybackControls({
    super.key,
    required this.playbackState,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  bool get _canPlay =>
      playbackState == TtsPlaybackState.idle ||
      playbackState == TtsPlaybackState.stopped ||
      playbackState == TtsPlaybackState.error;

  bool get _canPause => playbackState == TtsPlaybackState.playing;

  bool get _canStop =>
      playbackState == TtsPlaybackState.playing ||
      playbackState == TtsPlaybackState.paused ||
      playbackState == TtsPlaybackState.loading;

  @override
  Widget build(BuildContext context) {
    final isLoading = playbackState == TtsPlaybackState.loading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play/Pause button (main action)
        _buildMainButton(context, isLoading),

        const SizedBox(width: 24),

        // Stop button
        _buildStopButton(context),
      ],
    );
  }

  Widget _buildMainButton(BuildContext context, bool isLoading) {
    IconData icon;
    VoidCallback? onPressed;

    if (isLoading) {
      icon = Icons.hourglass_empty;
      onPressed = null;
    } else if (playbackState == TtsPlaybackState.playing) {
      icon = Icons.pause_circle_filled;
      onPressed = onPause;
    } else {
      icon = Icons.play_circle_filled;
      onPressed = _canPlay ? onPlay : null;
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: isLoading
          ? Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              iconSize: 64,
              icon: Icon(
                icon,
                color: onPressed != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: IconButton(
        onPressed: _canStop ? onStop : null,
        iconSize: 40,
        icon: Icon(
          Icons.stop_circle,
          color: _canStop
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
