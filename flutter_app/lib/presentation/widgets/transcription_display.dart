import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_provider.dart';

/// Displays ASR transcription results with copy button (D-16).
/// Shows typing animation effect and maintains session history.
class TranscriptionDisplay extends ConsumerWidget {
  const TranscriptionDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcriptionText = ref.watch(transcriptionTextProvider);
    final history = ref.watch(transcriptionHistoryProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current transcription with copy button
        _TranscriptionCard(
          text: transcriptionText,
          isProcessing: isProcessing,
        ),

        const SizedBox(height: 12),

        // History list (D-Claude's discretion: in-session history)
        if (history.isNotEmpty) ...[
          Text(
            '历史记录 (${history.length})',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              reverse: true, // Most recent at top
              itemBuilder: (context, index) {
                // index 0 is most recent due to reverse: true
                final item = history[history.length - 1 - index];
                return _HistoryTile(text: item);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _TranscriptionCard extends StatelessWidget {
  final String text;
  final bool isProcessing;

  const _TranscriptionCard({
    required this.text,
    required this.isProcessing,
  });

  void _copyToClipboard(BuildContext context) {
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已复制到剪贴板'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '转写结果',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Spacer(),
              if (text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: '复制',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (text.isEmpty) {
      return Text(
        isProcessing ? '转写中...' : '长按麦克风说话',
        key: ValueKey(text.isEmpty ? 'empty' : 'text'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Text(
      text,
      key: ValueKey(text),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            height: 1.5,
          ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String text;

  const _HistoryTile({required this.text});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.history,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 16),
        onPressed: () => _copy(context),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
