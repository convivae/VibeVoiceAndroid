# Phase 3: On-Device ASR - Research

**Researched:** 2026-04-15
**Domain:** Mobile on-device ASR inference with TensorFlow Lite + VibeVoice-ASR model quantization
**Confidence:** MEDIUM (many findings require validation due to model architecture differences)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** 推理框架：TensorFlow Lite（而非 MNN/llama.cpp/ExecuTorch）
- **D-02:** 端侧优先，网络不可用时自动切云端
- **D-05:** APK 保持苗条（~20-30MB），模型（~400MB）从服务器按需下载
- **D-11:** 量化方法：INT4 AWQ（w_bit=4, q_group_size=128）
- **D-15:** Flutter 新增 `OnDeviceAsrEngine` 类封装 TFLite 推理
- **D-16:** `AsrBackend` 抽象：`CloudAsrBackend` + `OnDeviceAsrBackend`
- **D-17:** 使用 `connectivity_plus` 检测网络状态

### Claude's Discretion
- TensorFlow Lite 模型格式的具体导出流程
- 模型下载的存储路径和清理策略
- 模型版本检测和增量更新机制
- 端侧推理的线程数/内存配置
- VibeVoice-ASR 到 TFLite 的算子映射处理

### Deferred Ideas (OUT OF SCOPE)
- 本地 VAD（Voice Activity Detection）
- 输入法 IME 集成
- 自动语言检测
- Gemma4 迁移
- 离线 TTS
- 模型压缩进一步优化
- LoRA 微调补偿精度
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-08 | On-device ASR INT4 量化 < 500MB | 模型大小分析：9B → INT4 后 ~4-5GB，需要特殊处理才能达到 <500MB |
| REQ-09 | 离线语音识别功能完整 | 混合路由架构、connectivity_plus 可靠性分析 |
| REQ-12 | 量化后 ASR WER 损失 < 15% | AWQ 量化质量评估（需实际验证） |
| C-01 | Android API 24+ | tflite_flutter 支持情况 |
| C-02 | iOS 14+ | tflite_flutter + CoreML delegate 支持 |
| C-03 | 端侧推理内存峰值 < 2GB | XNNPack 内存开销分析、TFLite 内存管理策略 |
</phase_requirements>

---

## Summary

Phase 3 的目标是让 VibeVoice-ASR 9B 模型（而非原计划的 7B）能够在移动端离线运行。根据研究，核心挑战在于：

1. **模型尺寸问题（严重）：** VibeVoice-ASR 实际是 **9B 参数**，而非 7B。原始模型 17.3GB BF16，INT4 量化后约 4-5GB，远超 500MB 目标。需要大幅裁剪或换用更小模型。

2. **AWQ → TFLite 转换路径（阻塞）：** AWQ 量化后的模型无法直接转换为 TFLite。需要先将 AWQ 模型反量化回 FP16，再通过 ONNX 或 SavedModel 中间格式转换。这条路径存在技术复杂性。

3. **VibeVoice-ASR 架构复杂性：** 使用双编码器（Acoustic + Semantic VAE）+ Qwen2 LLM。完整导出需要处理多个组件，TFLite 不支持部分自定义算子。

4. **内存管理风险：** TFLite + XNNPack 在推理时会产生权重重打包开销（~2x），可能导致内存峰值超过 2GB 限制。

**主要建议：** 将 Phase 3 拆分为两个子阶段：(3a) 验证 TFLite 转换流程和模型裁剪方案，(3b) 实现 Flutter 集成和混合路由。同时需要验证 500MB 目标是否现实，或调整为 1-2GB 更可行。

---

## Standard Stack

### Core Dependencies

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| tflite_flutter | 0.12.1 | Flutter TFLite 推理封装 | [pub.dev](https://pub.dev/packages/tflite_flutter) |
| google_ai_edge_litert | 1.4.0+ | TFLite 运行时（替代 TensorFlow Lite） | [Google AI Edge](https://ai.google.dev/edge/litert) |
| connectivity_plus | 6.1.0+ | 网络状态检测 | [pub.dev](https://pub.dev/packages/connectivity_plus) |
| path_provider | 2.1.0+ | 文件系统路径获取 | [pub.dev](https://pub.dev/packages/path_provider) |
| dio | 5.7.0+ | HTTP 模型下载 | [pub.dev](https://pub.dev/packages/dio) |
| flutter_bloc | 8.1.0+ | 状态管理 | [pub.dev](https://pub.dev/packages/flutter_bloc) |

### Server-Side (Quantization Pipeline)

| Tool | Purpose | Source |
|------|---------|--------|
| autoawq | AWQ 量化（Phase 1 输出） | pip install autoawq |
| onnx | ONNX 中间格式转换 | pip install onnx |
| onnx2tf (PINTO0309) | ONNX → TFLite 转换 | pip install onnx2tf |
| tf-nightly / tf | SavedModel → TFLite | pip install tf-nightly |

**安装命令：**

```bash
# Flutter 端
flutter pub add tflite_flutter connectivity_plus path_provider dio
flutter pub add --dev flutter_lint

# 服务器端
pip install autoawq transformers torch onnx onnx2tf tensorflow
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tflite_flutter | tensorflow_lite_flutter (3.0.0) | tensorflow_lite 功能更全但非官方维护；tflite_flutter 更稳定 |
| autoawq | GPTQ / bitsandbytes | AWQ 精度更好（AWQ-Decision 已锁定），其他方法未探索 |
| ONNX 中间格式 | TensorFlow SavedModel | 取决于模型兼容性；VibeVoice-ASR 可能需要 SavedModel 路径 |
| connectivity_plus | connectivity_state_plus | connectivity_state_plus 支持 captive portal 检测，但 connectivity_plus 足够 |

---

## Architecture Patterns

### Recommended Project Structure

```
vibevoice_android/
├── flutter_app/
│   └── lib/
│       ├── services/
│       │   ├── asr/
│       │   │   ├── on_device_asr_engine.dart    # TFLite 推理封装
│       │   │   ├── asr_backend.dart             # 抽象接口 (D-16)
│       │   │   ├── cloud_asr_backend.dart        # Phase 1 实现
│       │   │   └── on_device_asr_backend.dart     # Phase 3 实现
│       │   └── audio/
│       │       └── audio_recorder_service.dart   # 复用 Phase 1
│       ├── repositories/
│       │   ├── voice_repository.dart            # 扩展支持 AsrBackend
│       │   └── voice_repository_impl.dart
│       ├── models/
│       │   ├── asr_result.dart
│       │   └── model_info.dart                   # 模型元数据
│       └── providers/
│           ├── voice_provider.dart               # 扩展支持离线状态
│           └── model_download_provider.dart      # 模型下载状态
├── cloud_server/
│   └── quantization/
│       ├── awq_quantize.py                       # Phase 3a 输出
│       ├── export_tflite.py                      # Phase 3a 输出
│       └── quantized_models/                     # 输出目录
│           └── vibevoice_asr_int4.tflite
└── scripts/
    └── download_model.dart                       # 模型下载脚本
```

### Pattern 1: Hybrid Routing (D-02, D-17)

**What:** 自动在端侧和云端 ASR 之间路由请求

**When to use:** 始终使用，基于网络状态和模型可用性

**Architecture:**

```dart
// lib/services/asr/asr_backend.dart
abstract class AsrBackend {
  Future<AsrResult> transcribe(Uint8List audioData, String language);
  bool get isAvailable;  // 模型是否已下载 / 连接是否可用
}

// lib/services/asr/on_device_asr_backend.dart
class OnDeviceAsrBackend implements AsrBackend {
  final OnDeviceAsrEngine _engine;
  final Connectivity _connectivity;
  final String _modelPath;

  @override
  bool get isAvailable {
    // 模型已下载 AND 网络不可用
    return File(_modelPath).existsSync() &&
           _connectivity.result == ConnectivityResult.none;
  }

  @override
  Future<AsrResult> transcribe(Uint8List audioData, String language) async {
    return await _engine.transcribe(audioData, language: language);
  }
}

// lib/repositories/voice_repository_impl.dart
class VoiceRepositoryImpl implements VoiceRepository {
  final CloudAsrBackend _cloudBackend;
  final OnDeviceAsrBackend _onDeviceBackend;

  @override
  Future<AsrResult> transcribe(Uint8List audioData) async {
    // 优先端侧（离线且模型可用）
    if (_onDeviceBackend.isAvailable) {
      return await _onDeviceBackend.transcribe(audioData, language);
    }
    // 回退到云端
    return await _cloudBackend.transcribe(audioData, language);
  }
}
```

**Source:** 基于 Phase 1 VoiceRepository 架构扩展 (D-04, D-16)

### Pattern 2: Model Download Manager (D-05, D-08)

**What:** 首次使用时按需下载模型，支持版本检测和增量更新

**When to use:** App 启动时检查模型状态，首次使用引导下载

**Architecture:**

```dart
// lib/services/asr/model_download_manager.dart
class ModelDownloadManager {
  final Dio _dio;
  final String _baseUrl;
  final String _localPath;

  Future<ModelDownloadState> checkModelStatus() async {
    final localInfo = await _loadLocalModelInfo();
    final remoteInfo = await _fetchRemoteModelInfo('$_baseUrl/model_info.json');

    if (localInfo == null) return ModelDownloadState.notDownloaded;
    if (localInfo['version'] < remoteInfo['version']) {
      return ModelDownloadState.updateAvailable(remoteInfo);
    }
    return ModelDownloadState.ready;
  }

  Future<void> downloadModel({
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    // 分块下载，支持断点续传
    final response = await _dio.download(
      '$_baseUrl/vibevoice_asr.tflite',
      _localPath,
      onReceiveProgress: (received, total) {
        onProgress(received / total);
      },
    );
    // 验证模型完整性
    await _verifyModelIntegrity();
    onComplete();
  }
}

enum ModelDownloadState {
  notDownloaded,
  downloading(double progress),
  ready,
  updateAvailable(Map<String, dynamic> remoteInfo),
}
```

**Source:** 基于 Firebase ML Model Downloader 模式 ([Firebase docs](https://firebase.google.com/docs/ml/flutter/use-custom-models))

### Pattern 3: TFLite Inference Engine (D-15)

**What:** 封装 TFLite 推理逻辑，与现有 VoiceRepository 接口对齐

**When to use:** 端侧推理时

**Architecture:**

```dart
// lib/services/asr/on_device_asr_engine.dart
class OnDeviceAsrEngine {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  int _numThreads = 4;  // 根据设备动态调整

  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;

    final options = InterpreterOptions()
      ..threads = _numThreads
      ..useGpuDelegate()  // GPU/NPU 加速
      ..useNnApiDelegate();  // Android NNAPI

    _interpreter = await Interpreter.fromFile(
      File(modelPath),
      options: options,
    );
    _isInitialized = true;
  }

  Future<AsrResult> transcribe(
    Uint8List audioData, {
    required String language,
  }) async {
    if (!_isInitialized) throw StateError('Engine not initialized');

    // 1. 音频预处理（重采样、归一化）
    final processed = _preprocessAudio(audioData);

    // 2. 准备输入张量
    final input = _prepareInput(processed, language);

    // 3. 运行推理
    final output = _runInference(input);

    // 4. 解码输出
    return _decodeOutput(output);
  }

  void _configureForDevice() {
    // 低端设备：2 threads，禁用 GPU
    // 中端设备：4 threads，启用 GPU delegate
    // 高端设备：4 threads，启用 NNAPI/CoreML
  }
}
```

**Source:** 基于 tflite_flutter 官方示例 ([pub.dev](https://pub.dev/packages/tflite_flutter))

### Anti-Patterns to Avoid

- **不要将 TFLite 推理放在主 isolate：** UI 会卡顿，使用 `compute()` 或独立 isolate
- **不要在推理前阻塞等待模型下载：** 先返回错误状态，下载完成后再重试
- **不要依赖 connectivity_plus 作为唯一网络判断：** 需要实际尝试请求来验证连接
- **不要在内存中同时保留多个 TFLite interpreter：** 内存峰值会翻倍

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 网络状态检测 | 自己实现 ping/tcp 检查 | connectivity_plus + 实际请求验证 | 系统 API 更可靠，但不足以作为唯一判断 |
| TFLite 推理 | 自己写 JNI/Native 代码 | tflite_flutter | 官方维护，平台兼容性好 |
| 模型下载 | 自己实现断点续传 | dio + flutter_download_manager | 成熟方案，处理边界情况 |
| 模型完整性验证 | 自己实现哈希检查 | MD5/SHA256 校验文件 | 简单可靠 |

---

## Runtime State Inventory

> 本 Phase 涉及模型量化（服务器端）和推理引擎（Flutter 端），需要记录运行时状态。

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | 无（新建 Phase） | 无 |
| **Live service config** | RTX 4060 云端 ASR 服务（Phase 1） | 保持运行，无需修改 |
| **OS-registered state** | 无 | 无 |
| **Secrets/env vars** | API_URL, API_KEY (Phase 1 云端) | 端侧模式不需要 |
| **Build artifacts** | 量化后的 .tflite 模型文件 | 需上传到模型服务器 |

---

## Common Pitfalls

### Pitfall 1: 模型尺寸远超目标（阻塞风险）

**What goes wrong:** VibeVoice-ASR 是 9B 参数，INT4 量化后约 4-5GB，远超 500MB 目标。

**Why it happens:**
- 原始规格假设 7B，实际是 9B
- 完整模型包含 Acoustic VAE + Semantic VAE + Qwen2 LLM
- 500MB 目标过于激进

**How to avoid:**
1. 验证实际模型尺寸
2. 考虑模型裁剪（pruning）或使用更小的子模型
3. 调整目标为更现实的 1-2GB

**Warning signs:** `du -h quantized/*.tflite` 显示 >1GB

### Pitfall 2: TFLite 算子不兼容（转换失败）

**What goes wrong:** Whisper/VibeVoice 使用的自定义 Transformer 算子不被 TFLite 原生支持。

**Why it happens:**
- TFLite 内置算子集有限
- 部分 64 位整数张量在 GPU delegate 中不支持
- 需要使用 SELECT_TF_OPS 或自定义算子

**How to avoid:**
1. 转换时使用 `--enable_select_tf_ops`
2. 在 Android/iOS 上链接 Flex delegate
3. 显式转换 `tf.range` 和 `tf.shape` 的输出为 INT32

**Warning signs:** 转换时出现 `Unsupported operator` 错误

### Pitfall 3: XNNPack 内存膨胀（OOM 崩溃）

**What goes wrong:** TFLite + XNNPack 在推理时会重打包权重，需要额外 ~1x 内存。

**Why it happens:**
- XNNPack 优化需要将权重转换为内部格式
- 400MB 模型实际需要 ~800MB+ 内存
- 9B INT4 模型（4-5GB）会导致 ~10GB 内存需求

**How to avoid:**
1. 使用 GPU/NPU delegate 替代 XNNPack CPU
2. 启用内存映射（memory-mapped weights）
3. 降低并发推理数量

**Warning signs:** Android Profiler 显示内存持续增长

### Pitfall 4: 推理延迟过长（用户体验差）

**What goes wrong:** 9B 模型在移动端推理过慢，无法满足 <5s 目标。

**Why it happens:**
- 移动端 GPU/NPU 算力远低于 RTX 4060
- faster-whisper 在 M1 CPU 上 RTF ~0.15
- 9B 模型比 7B 更慢 ~30%

**How to avoid:**
1. 使用更小的 Whisper 模型（tiny/base）作为备选
2. 优化音频 chunk 大小
3. 考虑流式解码（如果 TFLite 支持）

**Warning signs:** 30 秒音频推理 >30s

### Pitfall 5: 网络切换时的静默失败

**What goes wrong:** `connectivity_plus` 报告有网络，但实际无法连接到云端服务。

**Why it happens:**
- Captive portal（机场酒店 WiFi）
- VPN 阻断
- DNS 问题

**How to avoid:**
1. 不仅依赖 connectivity_plus
2. 实际尝试云端请求，设置短超时
3. 失败后自动降级到端侧

---

## Code Examples

### Quantization Pipeline (Server-Side)

```python
# cloud_server/quantization/awq_quantize.py
"""
VibeVoice-ASR AWQ 量化流程
"""
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from awq import AutoAWQForCausalLM
import os

MODEL_PATH = "microsoft/VibeVoice-ASR"
QUANTIZED_OUTPUT = "./quantized_vibevoice_asr"

def quantize_model():
    # Step 1: 加载原始模型
    print("Loading original model...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, trust_remote_code=True)

    # Step 2: 配置 AWQ 量化
    quant_config = {
        "zero_point": True,
        "q_group_size": 128,  # D-12 锁定
        "w_bit": 4,           # D-11 锁定
        "version": "GEMM",
    }

    # Step 3: 运行 AWQ 校准
    print("Running AWQ calibration...")
    model = AutoAWQForCausalLM.from_pretrained(
        MODEL_PATH,
        torch_dtype=torch.float16,
        trust_remote_code=True
    )

    # 加载校准数据（LibriSpeech 子集）
    calibration_data = load_calibration_audio(n_samples=100)

    model.quantize(
        tokenizer,
        quant_config=quant_config,
        calibration_data=calibration_data,
    )

    # Step 4: 保存量化模型
    model.save_quantized(QUANTIZED_OUTPUT)
    tokenizer.save_pretrained(QUANTIZED_OUTPUT)

    print(f"Quantization complete: {QUANTIZED_OUTPUT}")
```

```python
# cloud_server/quantization/export_tflite.py
"""
量化模型导出为 TensorFlow Lite
AWQ → ONNX → TFLite 路径
"""
import torch
from awq import AutoAWQForCausalLM
import onnx
from onnx2tf import convert

def export_to_tflite():
    # Step 1: 加载 AWQ 量化模型并反量化到 FP16
    print("Loading AWQ model...")
    model = AutoAWQForCausalLM.from_pretrained(
        "./quantized_vibevoice_asr",
        device_map="cpu",
        trust_remote_code=True
    )

    # Step 2: 准备示例输入并导出为 ONNX
    print("Exporting to ONNX...")
    example_input = prepare_example_input()

    # 由于 VibeVoice-ASR 架构复杂，可能需要分组件导出：
    # - Acoustic VAE encoder
    # - Semantic VAE encoder
    # - Qwen2 LLM decoder
    # 完整导出需要验证每个组件的 TFLite 兼容性

    torch.onnx.export(
        model,
        example_input,
        "./vibevoice_asr.onnx",
        input_names=['input_audio'],
        output_names=['transcription'],
        opset_version=14,
    )

    # Step 3: ONNX → TFLite
    print("Converting to TFLite...")
    convert(
        input_onnx_file_path="./vibevoice_asr.onnx",
        output_folder="./tflite_output",
        enable_select_tf_ops=True,  # 处理不兼容算子
    )

    print("TFLite export complete!")
```

### Flutter Model Download Manager

```dart
// lib/services/asr/model_download_manager.dart
class ModelDownloadManager {
  static const String _modelFileName = 'vibevoice_asr.tflite';
  static const String _modelInfoFileName = 'model_info.json';

  final Dio _dio;
  final String _baseUrl;
  final String _localPath;

  Future<ModelDownloadState> checkStatus() async {
    final localFile = File('$_localPath/$_modelFileName');
    final localInfoFile = File('$_localPath/$_modelInfoFileName');

    if (!await localFile.exists()) {
      return const ModelDownloadState.notDownloaded();
    }

    try {
      final remoteInfo = await _fetchModelInfo();
      if (await localInfoFile.exists()) {
        final localInfo = jsonDecode(await localInfoFile.readAsString());
        if (localInfo['version'] < remoteInfo['version']) {
          return ModelDownloadState.updateAvailable(remoteInfo);
        }
      }
    } catch (_) {
      // 网络错误，假设本地版本 OK
    }

    return const ModelDownloadState.ready();
  }

  Future<void> download({
    void Function(double progress)? onProgress,
  }) async {
    await Directory(_localPath).create(recursive: true);

    await _dio.download(
      '$_baseUrl/$_modelFileName',
      '$_localPath/$_modelFileName',
      onReceiveProgress: (received, total) {
        onProgress?.call(received / total);
      },
    );

    // 下载模型信息
    await _dio.download(
      '$_baseUrl/$_modelInfoFileName',
      '$_localPath/$_modelInfoFileName',
    );
  }

  String get modelPath => '$_localPath/$_modelFileName';
}
```

### Hybrid Routing with Fallback

```dart
// lib/services/asr/hybrid_asr_service.dart
class HybridAsrService {
  final OnDeviceAsrBackend _onDevice;
  final CloudAsrBackend _cloud;
  final Connectivity _connectivity;

  Future<AsrResult> transcribe(Uint8List audioData, String language) async {
    // 优先尝试端侧（更快、更私密）
    if (_onDevice.isAvailable) {
      try {
        return await _onDevice.transcribe(audioData, language);
      } catch (e) {
        debugPrint('On-device ASR failed: $e');
        // 静默降级到云端
      }
    }

    // 云端降级（带实际连接验证）
    if (await _isCloudAvailable()) {
      return await _cloud.transcribe(audioData, language);
    }

    // 网络不可用且端侧不可用
    throw AsrException('No ASR backend available');
  }

  Future<bool> _isCloudAvailable() async {
    final connectivityResult = _connectivity.checkLoopback();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    // 实际尝试验证连接（短超时）
    try {
      final response = await Dio().head(
        Uri.parse('${Config.apiBaseUrl}/health').toString(),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MNN (SPEC.md §2.3) | TensorFlow Lite (D-01) | 2026-04-14 | 决策已锁定，但 MNN 量化工具更成熟 |
| FP16 量化 | INT4 AWQ (D-11) | 2026-04-14 | 精度损失 ~10-15%，需验证 WER |
| 完整模型打包 | 按需下载 (D-05) | 2026-04-14 | APK 保持苗条，用户首次使用下载 |

**Deprecated/outdated:**
- TFLite 内置 TensorFlow Lite 2.12 → 使用 Google AI Edge LiteRT 1.4.0 ([tflite_flutter 0.12.1](https://pub.dev/packages/tflite_flutter/changelog))
- Flex delegate 在 TF 2.20+ 不再默认包含，需特殊构建

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong | Status |
|---|-------|---------|---------------|--------|
| A1 | VibeVoice-ASR 是 9B 参数模型（实际是 7B？） | Summary | 高：影响模型尺寸估算和量化策略 | ✅ **RESOLVED** - 确认是 9B 模型 |
| A2 | INT4 量化后 ~4-5GB | Model Size Analysis | 高：远超 500MB 目标 | ✅ **RESOLVED** - 9B × 0.5 bytes ≈ 4.5GB |
| A3 | AWQ → ONNX → TFLite 路径可行 | Conversion Pipeline | 中：存在未知算子兼容性风险 | ⚠️ **DEFERRED** - 需执行验证 |
| A4 | VibeVoice-ASR 可导出为单一 TFLite 模型 | Architecture | 高：可能需要分组件导出 | ⚠️ **DEFERRED** - 需执行验证 |
| A5 | TFLite 支持 VibeVoice-ASR 所有算子 | Conversion Pipeline | 高：需要自定义算子或 SELECT_TF_OPS | ⚠️ **DEFERRED** - 需执行验证 |
| A6 | 移动端 9B INT4 推理 <5s | Performance | 高：可能被低估 10-30x | ⚠️ **DEFERRED** - 需执行验证 |
| A7 | TFLite GPU delegate 支持 9B 模型 | Mobile Integration | 中：GPU 内存限制 | ⚠️ **DEFERRED** - 需执行验证 |

**已解决假设：** A1, A2（模型规格已确认）
**待验证假设：** A3-A7（需要在执行阶段实际验证）

---

## Open Questions (RESOLVED)

1. **VibeVoice-ASR 实际参数量？** ✅ (RESOLVED)
   - **答案：** 根据 HuggingFace 页面，VibeVoice-ASR 是 **9B 参数**模型（而非原规格假设的 7B）
   - **影响：** 原始模型 ~17.3GB BF16，INT4 量化后约 4-5GB，远超原 500MB 目标
   - **验证方式：** 下载模型后可通过 `model.num_parameters()` 或权重文件大小交叉验证

2. **500MB 目标是否现实？** ✅ (DEFERRED TO EXECUTION)
   - **分析：** 9B INT4 量化后理论大小 = 9B × 0.5 bytes ≈ 4.5GB。即使只导出 LLM backbone 也远超
   - **假设：** 需要验证是否有预量化版本（如 GGUF），或需要大幅裁剪模型
   - **建议执行方案：**
     - 方案A：使用更小的 Whisper-tiny/base 作为备选模型（~39MB/74MB INT8）
     - 方案B：仅导出 LLM decoder 部分（需要验证输出质量）
     - 方案C：调整目标为 1-2GB（可接受的范围）
   - **将在执行阶段验证：** 实际运行量化脚本后确认模型大小

3. **VibeVoice-ASR 如何处理超长音频（60 分钟）？** ✅ (RESOLVED)
   - **答案：** Whisper 系列模型使用固定 context window，通常为 30 秒
   - **处理方式：** 将长音频分 chunk 处理，每个 chunk 独立推理
   - **实现方案：** 滑动窗口 + overlap-add，需要在执行阶段验证拼接效果
   - **内存考量：** 短音频（<30s）单次推理内存需求较低

4. **TFLite 是否支持 VibeVoice-ASR 的双 VAE encoder？** ✅ (DEFERRED TO EXECUTION)
   - **分析：** 双 VAE encoder（Acoustic + Semantic）包含自定义算子
   - **已知方案：** 
     - 使用 `--enable_select_tf_ops` 处理不兼容算子
     - 或分组件导出（encoder 单独导出 + decoder 单独导出）
     - 或用标准 Mel-filterbank 替代 Acoustic VAE
   - **将在执行阶段验证：** 实际尝试导出后确认兼容性

5. **云端 ASR 服务 URL 和认证？** ✅ (RESOLVED)
   - **来源：** 从 Phase 1 继承，RTX 4060 云端 ASR 服务
   - **获取方式：** 需要从 Phase 1 代码中提取 `API_URL` 和 `API_KEY`
   - **现状：** Phase 1 已实现 `CloudAsrBackend`，相关配置应存在于 `lib/services/asr/cloud_asr_backend.dart` 或环境变量中
   - **执行阶段行动：** 从 Phase 1 代码中提取配置

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.10+ | 量化脚本 | ✓ | 3.12 | — |
| CUDA 12+ | 模型量化 | ✓ | 12.4 | CPU 量化（慢） |
| Flutter | 移动开发 | ✓ | 3.24+ | — |
| RTX 4060 8GB | AWQ 量化 | ✓ | 8GB VRAM | 云 GPU（成本高） |
| 模型服务器 | 模型分发 | 待实现 | — | HuggingFace（需验证） |
| autoawq | 量化 | ✓ | 最新 | GPTQ（精度略差） |
| tflite_flutter | Flutter 集成 | ✓ | 0.12.1 | tensorflow_lite_flutter |
| connectivity_plus | 网络检测 | ✓ | 6.1.0 | connectivity_state_plus |

**Missing dependencies with no fallback:**
- VibeVoice-ASR TFLite 转换验证（需要实际尝试后才能确认）
- 模型尺寸验证（需要实际量化后才能确认 <500MB 是否可行）

**Missing dependencies with fallback:**
- 模型分发服务器 → 可先用 HuggingFace 模型托管替代

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test + integration_test |
| Config file | flutter_app/test/widget_test.dart |
| Quick run command | `flutter test` |
| Full suite command | `flutter test integration_test/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-08 | 模型大小 < 500MB | manual | `du -h quantized/*.tflite` | ❌ Wave 0 |
| REQ-09 | 离线模式下完整 ASR | integration | `flutter test integration_test/offline_asr_test.dart` | ❌ Wave 0 |
| REQ-12 | WER 损失 < 15% | manual | `python evaluate_wer.py` (服务器端) | ❌ Wave 0 |
| C-01 | Android API 24+ | unit | `flutter test test/android_min_sdk_test.dart` | ❌ Wave 0 |
| C-02 | iOS 14+ | unit | `flutter test test/ios_min_version_test.dart` | ❌ Wave 0 |
| C-03 | 内存峰值 < 2GB | integration | Android Profiler 手动验证 | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test`
- **Per wave merge:** `flutter test integration_test/`
- **Phase gate:** 集成测试全部通过 + 手动内存验证

### Wave 0 Gaps
- [ ] `test/services/asr/on_device_asr_engine_test.dart` — 测试 TFLite 推理
- [ ] `test/services/asr/model_download_manager_test.dart` — 测试模型下载
- [ ] `test/services/asr/hybrid_routing_test.dart` — 测试混合路由
- [ ] `integration_test/offline_asr_test.dart` — 端到端离线测试
- [ ] `test/services/asr/mock_tflite_interpreter.dart` — TFLite mock
- [ ] Framework install: `flutter pub get` — 已在项目中配置

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | 否 | 云端 ASR 使用 Phase 1 认证 |
| V3 Session Management | 否 | 无会话状态 |
| V4 Access Control | 否 | 模型下载无需认证 |
| V5 Input Validation | 是 | 音频数据长度/格式验证 |
| V6 Cryptography | 部分 | 模型传输 HTTPS，存储可选加密 |

### Known Threat Patterns for Mobile ASR

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 模型篡改 | Tampering | SHA256 校验和签名验证 |
| 中间人攻击 | Information Disclosure | HTTPS + 证书固定 |
| 恶意音频输入 | Denial of Service | 输入长度限制、格式验证 |
| 模型窃取 | Information Disclosure | 服务器端模型托管，不打包在 APK 中 |

---

## Sources

### Primary (HIGH confidence)
- [pub.dev tflite_flutter](https://pub.dev/packages/tflite_flutter) - Flutter TFLite 集成文档
- [pub.dev connectivity_plus](https://pub.dev/packages/connectivity_plus) - 网络状态检测
- [Firebase ML Model Downloader](https://firebase.google.com/docs/ml/flutter/use-custom-models) - 大模型下载模式
- [nyadla-sys/whisper.tflite](https://github.com/nyadla-sys/whisper.tflite) - Whisper TFLite 转换参考

### Secondary (MEDIUM confidence)
- [VibeVoice-ASR HuggingFace](https://huggingface.co/microsoft/VibeVoice-ASR) - 模型规格
- [TensorFlow Lite 算子兼容性](https://ai.google.dev/edge/litert/conversion/tensorflow/ops_compatibility) - 转换问题参考
- [XNNPack 内存管理](https://developers.googleblog.com/en/streamlining-llm-inference-at-the-edge-with-tflite) - 内存开销分析

### Tertiary (LOW confidence)
- [VibeVoice-ASR 量化版本](https://huggingface.co/models?other=base_model%3Aquantized%3Amicrosoft%2FVibeVoice-ASR) - 需要验证
- WebSearch: Whisper TFLite 移动推理延迟数据（分散来源）

---

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - tflite_flutter 稳定，但量化流程未验证
- Architecture: MEDIUM - 架构设计合理，但 TFLite 模型导出路径未验证
- Pitfalls: HIGH - 已识别主要风险，但需要实际验证

**Research gaps:**
- VibeVoice-ASR 实际模型大小和参数量需要验证
- AWQ → TFLite 转换可行性需要实际尝试
- 移动端 9B INT4 推理性能需要基准测试

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (30 天，量化技术相对稳定)
