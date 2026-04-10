import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_provider.dart';

/// Language toggle button: Mandarin / English (D-15).
/// Switches between "zh" and "en" for ASR language.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(currentLanguageProvider);

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'zh',
          label: Text('中文'),
          icon: Icon(Icons.language),
        ),
        ButtonSegment(
          value: 'en',
          label: Text('English'),
          icon: Icon(Icons.language_outlined),
        ),
      ],
      selected: {currentLang},
      onSelectionChanged: (selected) {
        ref.read(asrProvider.notifier).setLanguage(selected.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
