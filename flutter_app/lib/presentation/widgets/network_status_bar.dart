import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asr_result.dart';
import '../providers/connection_provider.dart';

/// Network status bar shown at the top of the screen.
/// Only appears when there are connectivity or server issues.
class NetworkStatusBar extends ConsumerWidget {
  const NetworkStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNetworkAvailable = ref.watch(isNetworkAvailableProvider);
    final connectionState = ref.watch(currentConnectionStateProvider);

    // Only show bar when there are issues
    if (isNetworkAvailable && connectionState == ConnectionState.connected) {
      return const SizedBox.shrink();
    }

    final bool noNetwork = !isNetworkAvailable;
    final bool serverIssue = connectionState == ConnectionState.failed ||
        connectionState == ConnectionState.reconnecting ||
        connectionState == ConnectionState.connecting;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: noNetwork ? Colors.orange.shade700 : Colors.red.shade700,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              noNetwork ? Icons.wifi_off : _getStateIcon(connectionState),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                noNetwork
                    ? '无网络连接'
                    : '服务器 ${connectionState.statusText}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStateIcon(ConnectionState state) {
    switch (state) {
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return Icons.cloud_sync;
      case ConnectionState.failed:
        return Icons.cloud_off;
      default:
        return Icons.cloud_outlined;
    }
  }
}
