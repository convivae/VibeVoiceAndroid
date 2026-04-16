import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asr_result.dart';
import '../providers/connection_provider.dart';
import '../providers/voice_provider.dart';

/// Network status bar shown at the top of the screen.
/// Only appears when there are connectivity or server issues.
/// Per D-03: Shows "离线模式 · 使用本地模型" when offline mode is active.
class NetworkStatusBar extends ConsumerWidget {
  const NetworkStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNetworkAvailable = ref.watch(isNetworkAvailableProvider);
    final connectionState = ref.watch(currentWsConnectionStateProvider);
    final isOfflineMode = ref.watch(isOfflineModeProvider);

    // Only show bar when there are issues or offline mode is active
    if (isNetworkAvailable && connectionState == WsConnectionState.connected && !isOfflineMode) {
      return const SizedBox.shrink();
    }

    // Show offline mode indicator (per D-03)
    if (isOfflineMode) {
      return _buildOfflineModeBar(context);
    }

    // Existing error bars
    final bool noNetwork = !isNetworkAvailable;

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

  Widget _buildOfflineModeBar(BuildContext context) {
    // Per 03-CONTEXT.md: "离线模式下，网络状态栏显示'离线模式 · 使用本地模型'"
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade700,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.phone_android,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '离线模式 · 使用本地模型',
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

  IconData _getStateIcon(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return Icons.cloud_sync;
      case WsConnectionState.failed:
        return Icons.cloud_off;
      default:
        return Icons.cloud_outlined;
    }
  }
}
