import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asr_result.dart';
import '../providers/voice_provider.dart';
import '../providers/connection_provider.dart';

/// Status indicator showing 7 connection states (D-19, D-20).
/// States: disconnected, connecting, connected, reconnecting, failed, recording, processing.
class StatusIndicator extends ConsumerWidget {
  const StatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(currentWsConnectionStateProvider);
    final asrState = ref.watch(asrProvider);

    // Determine actual display state
    WsConnectionState displayState = connectionState;
    if (asrState.isRecording) {
      displayState = WsConnectionState.recording;
    } else if (asrState.isProcessing) {
      displayState = WsConnectionState.processing;
    }

    final statusText = displayState.statusText;
    final hasError = asrState.errorMessage != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context, displayState, hasError),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIndicator(context, displayState),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              hasError ? asrState.errorMessage! : statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getTextColor(context, displayState, hasError),
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(BuildContext context, WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return const _PulsingDot(color: Colors.green);
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      case WsConnectionState.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red.shade700,
        );
      case WsConnectionState.recording:
        return const _RecordingIndicator();
      case WsConnectionState.processing:
        return const _ProcessingIndicator();
      case WsConnectionState.disconnected:
      default:
        return Icon(
          Icons.circle,
          size: 8,
          color: Colors.grey.shade500,
        );
    }
  }

  Color _getBackgroundColor(BuildContext context, WsConnectionState state, bool hasError) {
    if (hasError) return Colors.red.shade50;
    switch (state) {
      case WsConnectionState.connected:
        return Colors.green.shade50;
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return Colors.blue.shade50;
      case WsConnectionState.failed:
        return Colors.red.shade50;
      case WsConnectionState.recording:
        return Colors.red.shade50;
      case WsConnectionState.processing:
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getTextColor(BuildContext context, WsConnectionState state, bool hasError) {
    if (hasError) return Colors.red.shade700;
    switch (state) {
      case WsConnectionState.connected:
        return Colors.green.shade700;
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return Colors.blue.shade700;
      case WsConnectionState.failed:
        return Colors.red.shade700;
      case WsConnectionState.recording:
        return Colors.red.shade700;
      case WsConnectionState.processing:
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withAlpha((_animation.value * 255).toInt()),
          ),
        );
      },
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator();

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withAlpha((_controller.value * 200 + 55).toInt()),
          ),
        );
      },
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.orange.shade700,
      ),
    );
  }
}
