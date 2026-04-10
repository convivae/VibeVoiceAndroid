import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asr_result.dart';
import '../providers/voice_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/mic_button.dart';
import '../widgets/transcription_display.dart';
import '../widgets/status_indicator.dart';
import '../widgets/language_toggle.dart';
import '../widgets/network_status_bar.dart';

/// Main home screen of the VibeVoice ASR app.
///
/// Layout:
///   - Top: Network status bar (only shown on issues)
///   - App bar: Logo + Title + Status indicator
///   - Language toggle + Permission hint
///   - Middle: Transcription display (text + history)
///   - Bottom: Instruction text + Mic button
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asrState = ref.watch(asrProvider);
    final connectionState = ref.watch(currentConnectionStateProvider);
    final isRecording = asrState.isRecording;
    final permStatus = asrState.microphonePermission;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Network status bar (only shows when issues)
            const NetworkStatusBar(),

            // App bar area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // App logo / title
                  Row(
                    children: [
                      Icon(
                        Icons.mic,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'VibeVoice',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Status indicator
                  const StatusIndicator(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Language toggle + Permission hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const LanguageToggle(),
                  const Spacer(),
                  if (permStatus == PermissionStatus.denied)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(asrProvider.notifier).requestPermission();
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('授权'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Transcription display (expands to fill space)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const TranscriptionDisplay(),
              ),
            ),

            // Bottom area: instruction + mic button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Instruction text
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isRecording
                          ? '松开结束录音...'
                          : (connectionState == ConnectionState.connected
                              ? '长按麦克风开始说话'
                              : (connectionState == ConnectionState.connecting
                                  ? '连接中...'
                                  : '等待连接...')),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isRecording
                                ? Colors.red.shade700
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Mic button (centered)
                  const MicButton(),

                  const SizedBox(height: 16),

                  // Permission hint
                  if (permStatus == PermissionStatus.unknown)
                    Text(
                      '需要麦克风权限才能使用',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
