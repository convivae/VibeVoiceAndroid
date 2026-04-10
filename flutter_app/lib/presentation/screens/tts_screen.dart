import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/entities/asr_result.dart';
import '../providers/tts_provider.dart';
import '../widgets/voice_selector.dart';
import '../widgets/playback_controls.dart';
import '../widgets/tts_progress_bar.dart';

/// TTS Tab screen for text-to-speech playback.
/// Per 02-CONTEXT.md D-01, D-02: Independent tab with text input + voice selector + playback controls.
class TtsScreen extends ConsumerStatefulWidget {
  const TtsScreen({super.key});

  @override
  ConsumerState<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends ConsumerState<TtsScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Voices are loaded automatically by TtsNotifier._init()
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPlay() {
    final text = _textController.text.trim();
    final ttsState = ref.read(ttsProvider);
    ref.read(ttsProvider.notifier).play(text, ttsState.voiceId);
  }

  void _onPause() {
    ref.read(ttsProvider.notifier).pause();
  }

  void _onResume() {
    ref.read(ttsProvider.notifier).resume();
  }

  void _onStop() {
    ref.read(ttsProvider.notifier).stop();
  }

  void _onVoiceChanged(voice) {
    ref.read(ttsProvider.notifier).setVoice(voice.id, voice.name);
  }

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // App bar area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.speaker_phone,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '语音合成',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const Spacer(),
                  // Connection status
                  _buildConnectionStatus(context, ttsState.connectionState),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Voice selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VoiceSelector(
                voices: ttsState.availableVoices,
                selectedVoiceId: ttsState.voiceId,
                onVoiceChanged: _onVoiceChanged,
              ),
            ),

            const SizedBox(height: 16),

            // Text input area (expands to fill space)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '在此输入要合成的文本...',
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TtsProgressBar(
                progress: ttsState.progress,
                durationDisplay: ttsState.durationDisplay,
              ),
            ),

            const SizedBox(height: 16),

            // Playback controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlaybackControls(
                playbackState: ttsState.playbackState,
                onPlay: _onPlay,
                onPause: _onPause,
                onStop: _onStop,
              ),
            ),

            const SizedBox(height: 16),

            // Error message
            if (ttsState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ttsState.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          ref.read(ttsProvider.notifier).dismissError();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom padding
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, ConnectionState connState) {
    Color color;
    String text;
    IconData icon;

    switch (connState) {
      case ConnectionState.connected:
        color = Colors.green;
        text = '已连接';
        icon = Icons.cloud_done;
        break;
      case ConnectionState.connecting:
        color = Colors.orange;
        text = '连接中';
        icon = Icons.cloud_sync;
        break;
      case ConnectionState.reconnecting:
        color = Colors.orange;
        text = '重连中';
        icon = Icons.cloud_sync;
        break;
      case ConnectionState.failed:
        color = Colors.red;
        text = '连接失败';
        icon = Icons.cloud_off;
        break;
      case ConnectionState.disconnected:
        color = Colors.grey;
        text = '未连接';
        icon = Icons.cloud_outlined;
        break;
      default:
        color = Colors.grey;
        text = '未连接';
        icon = Icons.cloud_outlined;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
