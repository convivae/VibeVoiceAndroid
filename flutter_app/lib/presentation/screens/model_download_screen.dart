import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/asr/model_info.dart';
import '../providers/model_download_provider.dart';

/// First-use guidance screen shown when model needs to be downloaded.
/// Displays download progress and storage information (D-06).
class ModelDownloadScreen extends ConsumerWidget {
  final VoidCallback onDownloadComplete;
  final VoidCallback? onSkip;
  
  const ModelDownloadScreen({
    super.key,
    required this.onDownloadComplete,
    this.onSkip,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelDownloadProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Icon(
                Icons.cloud_download_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                '下载语音模型',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                '首次使用需要下载语音识别模型（约 4.5GB）'
                '\n下载完成后即可离线使用语音输入',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              
              // Progress / Action
              _buildContent(context, ref, state),
              
              const SizedBox(height: 32),
              
              // Storage info
              Text(
                '模型将保存在应用存储中'
                '\n可在设置中清理释放空间',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context, WidgetRef ref, ModelDownloadState state) {
    if (state is ModelDownloadInProgress) {
      return _buildProgress(context, state);
    } else if (state is ModelDownloadVerifying) {
      return _buildVerifying(context);
    } else if (state is ModelDownloadError) {
      return _buildError(context, ref, state.message);
    } else {
      return _buildDownloadButton(context, ref);
    }
  }
  
  Widget _buildProgress(BuildContext context, ModelDownloadInProgress state) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${state.progressPercent}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${(state.receivedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${state.sizeText}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildVerifying(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          '正在验证模型完整性...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
  
  Widget _buildError(BuildContext context, WidgetRef ref, String message) {
    return Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red[700], size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red[700]),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => ref.read(modelDownloadProvider.notifier).download(),
          child: const Text('重试'),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            child: const Text('跳过（使用云端识别）'),
          ),
        ],
      ],
    );
  }
  
  Widget _buildDownloadButton(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => ref.read(modelDownloadProvider.notifier).download(),
          icon: const Icon(Icons.download),
          label: const Text('开始下载'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            child: const Text('跳过（使用云端识别）'),
          ),
        ],
      ],
    );
  }
}