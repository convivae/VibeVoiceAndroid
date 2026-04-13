import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asr_result.dart';
import '../providers/voice_provider.dart';
import '../providers/connection_provider.dart';

/// Push-to-Talk microphone button (D-14).
/// Press and hold to start recording, release to stop.
/// Visual states: idle, recording (pulsing animation), disabled.
class MicButton extends ConsumerStatefulWidget {
  const MicButton({super.key});

  @override
  ConsumerState<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends ConsumerState<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPressStart(LongPressStartDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
    ref.read(asrProvider.notifier).startRecording();
  }

  void _onPressEnd(LongPressEndDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    ref.read(asrProvider.notifier).stopRecording();
  }

  void _onPressCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final asrState = ref.watch(asrProvider);
    final connectionState = ref.watch(currentWsConnectionStateProvider);
    final isRecording = asrState.isRecording;

    // Disable button if not connected (allow retry when disconnected)
    final canRecord = connectionState == WsConnectionState.connected ||
        connectionState == WsConnectionState.disconnected;

    return GestureDetector(
      onLongPressStart: canRecord ? _onPressStart : null,
      onLongPressEnd: canRecord ? _onPressEnd : null,
      onLongPressCancel: _onPressCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scale = isRecording ? _scaleAnimation.value : 1.0;
          final pulse = isRecording ? _pulseAnimation.value : 1.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80 * pulse,
              height: 80 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? Colors.redAccent.shade400
                    : canRecord
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                            ? Colors.redAccent
                            : Theme.of(context).colorScheme.primary)
                        .withAlpha(77),
                    blurRadius: isRecording ? 20 : 10,
                    spreadRadius: isRecording ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 36,
              ),
            ),
          );
        },
      ),
    );
  }
}
