import 'package:flutter/material.dart';

/// Progress bar with duration display for TTS playback.
/// Per 02-CONTEXT.md D-06: Progress based on estimated_chunks and received_chunks.
class TtsProgressBar extends StatelessWidget {
  /// Current progress (0.0 to 1.0).
  final double progress;

  /// Formatted duration string (e.g., "00:30 / 01:00").
  final String durationDisplay;

  const TtsProgressBar({
    super.key,
    required this.progress,
    required this.durationDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress slider (read-only for TTS)
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor:
                Theme.of(context).colorScheme.primary.withAlpha(51),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: null, // Read-only for TTS
          ),
        ),

        // Duration display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current position
              Text(
                _parseCurrentTime(durationDisplay),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),

              // Status indicator (buffering)
              if (progress > 0 && progress < 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '缓冲中...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),

              // Total duration
              Text(
                _parseTotalTime(durationDisplay),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _parseCurrentTime(String display) {
    // Parse "00:30 / 01:00" -> "00:30"
    final parts = display.split(' / ');
    return parts.isNotEmpty ? parts[0] : '00:00';
  }

  String _parseTotalTime(String display) {
    // Parse "00:30 / 01:00" -> "01:00"
    final parts = display.split(' / ');
    return parts.length > 1 ? parts[1] : '00:00';
  }
}
