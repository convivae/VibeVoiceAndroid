import 'package:flutter/material.dart';
import '../../domain/entities/voice_info.dart';

/// Voice selector widget with dropdown showing 5 preset voices.
/// Per 02-CONTEXT.md D-04: 2 Chinese + 2 English + 1 mixed voices.
class VoiceSelector extends StatelessWidget {
  /// Available voices to select from.
  final List<VoiceInfo> voices;

  /// Currently selected voice ID.
  final String selectedVoiceId;

  /// Callback when voice is changed.
  final ValueChanged<VoiceInfo> onVoiceChanged;

  const VoiceSelector({
    super.key,
    required this.voices,
    required this.selectedVoiceId,
    required this.onVoiceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedVoice = voices.firstWhere(
      (v) => v.id == selectedVoiceId,
      orElse: () => voices.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.record_voice_over,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VoiceInfo>(
                value: selectedVoice,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: voices.map((voice) {
                  return DropdownMenuItem<VoiceInfo>(
                    value: voice,
                    child: Row(
                      children: [
                        _buildLanguageChip(context, voice.language),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            voice.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (voice) {
                  if (voice != null) {
                    onVoiceChanged(voice);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(BuildContext context, String language) {
    Color chipColor;
    String label;

    switch (language) {
      case 'zh':
        chipColor = Colors.red.shade400;
        label = '中';
        break;
      case 'en':
        chipColor = Colors.blue.shade400;
        label = 'EN';
        break;
      case 'mixed':
        chipColor = Colors.purple.shade400;
        label = '混';
        break;
      default:
        chipColor = Colors.grey;
        label = language.toUpperCase().substring(0, 2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(51),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
