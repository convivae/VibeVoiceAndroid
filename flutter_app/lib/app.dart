import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/api_config.dart';

class VibeVoiceApp extends ConsumerWidget {
  const VibeVoiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'VibeVoice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('VibeVoice - Loading...'),
        ),
      ),
    );
  }
}
