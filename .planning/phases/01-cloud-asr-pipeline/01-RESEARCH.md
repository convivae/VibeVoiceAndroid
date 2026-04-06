# Phase 1: Cloud ASR Pipeline - Research

**Researched:** 2026-04-06
**Domain:** Flutter移动端 + 云端ASR推理服务 + WebSocket实时流
**Confidence:** MEDIUM-HIGH

> ⚠️ **Critical finding:** vLLM does NOT natively support audio models via Transformers backend as of 2026-04. VibeVoice-ASR must be served via Microsoft VibeVoice官方vLLM plugin (`vllm_plugin/`)，而非原生vLLM serving。

## Summary

Phase 1需要在2周内完成MVP：Flutter独立App（语音输入法）+ 云端VibeVoice-ASR (7B)推理服务（RTX 4060 GPU后端）。核心技术挑战是**将VibeVoice-ASR 7B量化为INT4（~4GB）以在RTX 4060 8GB VRAM上运行**，以及**实现WebSocket实时流式ASR**（边说边出字）。

核心发现：
1. **vLLM不支持VibeVoice-ASR原生流式推理** — vLLM的Transformers后端不支持音频模型；需使用Microsoft官方vLLM plugin（`vllm_plugin/scripts/start_server.py`），但plugin采用**批量批处理**架构，**非流式**设计，实时语音输入需额外架构适配
2. **flutter_record包**（非`flutter_record`）是Flutter音频录制的标准方案，支持PCM流式API；`flutter_realtime_voice_ai`是一站式方案但依赖特定WebSocket协议
3. **RTX 4060 compute capability 8.9 (SM89/Ada Lovelace)**，FlashAttention-2向前传播（推理仅需向前传播）完全支持
4. **Windows Server 2025 + WSL2 GPU passthrough存在已知兼容性风险**（2026年3月报告）

**Primary recommendation:** 确认VibeVoice-ASR的vLLM plugin是否支持流式/增量推理；如果不支持，考虑用`transformers`+`accelerate`直接推理（绕过vLLM）配合FastAPI WebSocket。

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01~D-20**: 所有决策已锁定（WebSocket协议、vLLM Serving、INT4 AWQ量化、WSL2+Docker、FastAPI端点、flutter_record、16kHz PCM、50ms chunks、长按说话、断线重连等）
- **Phase requirement IDs**: REQ-01, REQ-02, REQ-03, REQ-05, REQ-10（REQ-04和RE-04待区分）
- **Out of scope**: Android IME、iOS Keyboard Extension、VAD、自动语言检测、端侧推理、离线模式

### Claude's Discretion
- Flutter UI配色和视觉风格
- vLLM并发连接数上限配置
- ASR分句策略（实时tokens vs完整句子）
- Flutter状态管理选型（Riverpod vs BLoC）

### Deferred Ideas (OUT OF SCOPE)
- Android/iOS输入法集成
- 声控VAD
- 自动语言检测
- 英文ASR支持（Phase 1专注中文普通话）
- flutter_soloud音频播放
- 离线ASR/TTS
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-01 | 中文普通话ASR识别 | VibeVoice-ASR支持50+语言，含中文普通话；Microsoft官方plugin |
| REQ-02 | WebSocket实时流式传输（16kHz PCM，50ms chunks） | flutter_record包支持StreamRecorder；WebSocket协议在SPEC.md 1.2节定义 |
| REQ-03 | Flutter App麦克风权限+网络状态UI | `record`包有hasPermission API；5种状态需明确UI反馈 |
| RE-04 | Windows Server RTX 4060 GPU推理服务 | RTX 4060 compute capability 8.9 (SM89)；FlashAttention-2向前传播支持；WSL2+Docker GPU passthrough |
| REQ-05 | APK可打包并运行在Android 12+ | Flutter >= 3.24支持Android 12+ (API 24)；impeller渲染 |
| REQ-10 | WebSocket断线自动重连 | 指数退避策略：Base 1s，Max 30s，Max 5 retries |

> 注：REQUIREMENTS.md中同时存在`RE-04`和`REQ-05`，可能存在笔误（前者应为`REQ-04`）。规划阶段需确认。
</phase_requirements>

---

## 1. 标准技术栈

### 1.1 云端推理服务

| 组件 | 推荐方案 | 版本 | 说明 |
|------|---------|------|------|
| **ASR推理引擎** | Microsoft VibeVoice官方vLLM plugin | — | ⚠️ 非原生vLLM；plugin路径 `vllm_plugin/scripts/start_server.py` |
| **替代方案（流式优先）** | `transformers` + `accelerate` 直接推理 | transformers >= 5.3.0 | ⚠️ 如果plugin不支持流式推理则用此方案 |
| **模型量化** | autoawq | — | `w_bit: 4`，`q_group_size: 128` |
| **GPU优化** | FlashAttention-2 + bf16 | — | RTX 4060 (SM89) 完全支持向前传播 |
| **Web框架** | FastAPI + Uvicorn | fastapi >= 0.115, uvicorn >= 0.30 | WebSocket端点 `/v1/asr/stream`，健康检查 `/health` |
| **CUDA** | CUDA 12+ | — | FlashAttention-2依赖；RTX 4060需CUDA 12+ |
| **容器化** | Docker Desktop + WSL2 | Docker >= 24.0 | ⚠️ GPU passthrough有已知风险（见§6） |

**安装（云端服务器）：**
```bash
# WSL2内
pip install transformers>=5.3.0 torch accelerate autoawq
# 或使用vLLM plugin（需从VibeVoice仓库克隆）
git clone https://github.com/microsoft/VibeVoice
cd VibeVoice/vllm_plugin && pip install -e .
```

### 1.2 Flutter App

| 组件 | 推荐方案 | 版本 | 说明 |
|------|---------|------|------|
| **跨平台框架** | Flutter | >= 3.24 | Android 12+ (API 24)，Impeller渲染 |
| **状态管理** | Riverpod | >= 3.3.1 | Claude在规划阶段决定（Riverpod vs BLoC） |
| **音频录制** | `record` 包 | >= 6.2.0 | ⚠️ SPEC.md写的是`flutter_record`，实际包名是`record` |
| **WebSocket客户端** | `web_socket_channel` | >= 3.0 | Dart官方；配合Stream |
| **HTTP客户端** | `dio` | >= 5.0 | REST API备用、健康检查 |
| **路由** | `go_router` | >= 14.0 | Flutter官方推荐 |
| **代码生成** | `freezed` | >= 5.0 | 数据类 |
| **iOS音频处理备选** | `socket_audiostream` | — | Windows专属；iOS用`record` |

**pubspec.yaml关键依赖：**
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.1
  record: ^6.2.0
  web_socket_channel: ^3.0.0
  dio: ^5.0.0
  go_router: ^14.0.0
  freezed_annotation: ^2.4.0
  permission_handler: ^11.0.0  # 麦克风权限

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^5.0.0
  riverpod_generator: ^2.4.0
```

### 1.3 音频参数（已锁定）

| 参数 | 值 | 来源 |
|------|---|------|
| 采样率 | 16kHz或24kHz | D-10 |
| 声道 | mono | D-10 |
| 位深 | 16-bit PCM | D-10 |
| Chunk时长 | 50ms | D-11 |
| 触发方式 | 长按说话（Push-to-Talk） | D-14 |
| 断线重连 | 指数退避（Base 1s, Max 30s, Max 5次） | D-18 |

---

## 2. 架构模式

### 2.1 推荐项目结构

```
VibeVoiceAndroid/
├── flutter_app/                    # Flutter应用
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── app.dart                # App入口、Theme、Router
│       ├── core/
│       │   ├── config/
│       │   │   └── api_config.dart # 服务器地址、WebSocket配置
│       │   ├── constants/
│       │   │   └── audio_constants.dart  # 16kHz、50ms chunk
│       │   └── errors/
│       │       └── exceptions.dart
│       ├── data/
│       │   ├── repositories/
│       │   │   └── voice_repository_impl.dart
│       │   └── datasources/
│       │       ├── remote/
│       │       │   ├── websocket_client.dart
│       │       │   └── asr_api_client.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── voice_chunk.dart
│       │   │   └── asr_result.dart
│       │   └── repositories/
│       │       └── voice_repository.dart
│       ├── presentation/
│       │   ├── providers/         # Riverpod providers
│       │   │   ├── voice_provider.dart
│       │   │   └── connection_provider.dart
│       │   ├── screens/
│       │   │   └── home_screen.dart
│       │   └── widgets/
│       │       ├── mic_button.dart   # 长按说话按钮+波形动画
│       │       ├── transcription_display.dart  # 打字机效果
│       │       └── status_indicator.dart  # 5种状态UI
│       └── services/
│           ├── audio/
│           │   └── audio_recorder_service.dart  # flutter_record封装
│           └── websocket/
│               └── websocket_service.dart   # 重连+指数退避
│
└── cloud_server/                   # 云端推理服务（RTX 4060）
    ├── Dockerfile
    ├── docker-compose.yml
    ├── requirements.txt
    └── app/
        ├── main.py                # FastAPI入口
        ├── routers/
        │   ├── asr.py             # /v1/asr/stream WebSocket
        │   └── health.py          # /health
        ├── services/
        │   └── vibevoice_asr.py   # VibeVoice-ASR推理封装
        └── models/
            └── schemas.py          # Pydantic模型
```

### 2.2 Flutter音频录制模式（StreamRecorder）

使用`record`包的`startStream()`获取PCM chunk流：

```dart
// Source: pub.dev record package docs
import 'package:record/record.dart';
import 'dart:typed_data';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<Stream<Uint8List>> startStreaming() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw MicrophonePermissionDenied();

    return await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,  // 16-bit PCM (D-10)
        sampleRate: 16000,               // 16kHz (D-10)
        numChannels: 1,                  // mono (D-10)
      ),
    );
  }

  // 每50ms约1600 bytes: 16000 * 50 / 1000 * 2 = 1600 bytes
  Stream<Uint8List> chunkStream() {
    return startStreaming();
  }
}
```

### 2.3 WebSocket连接+指数退避重连

```dart
// Source: SPEC.md §1.4.3（已由discuss-phase验证）
class WebSocketService {
  static const int MAX_RETRIES = 5;
  static const Duration BASE_DELAY = Duration(seconds: 1);
  static const Duration MAX_DELAY = Duration(seconds: 30);

  int _retryCount = 0;
  Duration _currentDelay = BASE_DELAY;

  Future<void> connect(String url) async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _retryCount = 0;
      _currentDelay = BASE_DELAY;
      _setupListeners(channel);
    } on WebSocketException catch (e) {
      await _handleDisconnect(e);
    }
  }

  Future<void> _handleDisconnect(Object e) async {
    if (_retryCount >= MAX_RETRIES) {
      emit(ConnectionState.failed(maxRetriesReached: true));
      return;
    }
    emit(ConnectionState.reconnecting(
      attempt: _retryCount + 1,
      delay: _currentDelay,
    ));
    await Future.delayed(_currentDelay);
    _currentDelay = Duration(
      milliseconds: (_currentDelay.inMilliseconds * 2).clamp(1000, 30000),
    );
    _retryCount++;
    await connect(url);
  }
}
```

### 2.4 FastAPI WebSocket端点（云端）

```python
# cloud_server/app/routers/asr.py
from fastapi import WebSocket, WebSocketDisconnect
from typing import Optional
import asyncio

@app.websocket("/v1/asr/stream")
async def asr_stream(ws: WebSocket):
    """WebSocket ASR流式端点"""
    await ws.accept()

    # 收集音频chunks直到说话结束
    audio_buffer = bytearray()

    try:
        # 接收并累积PCM chunks
        while True:
            chunk = await ws.receive_bytes()
            audio_buffer.extend(chunk)

            # 可选：每N个chunks触发一次推理（分句策略）
            if should_trigger_inference(audio_buffer):
                result = await run_asr(audio_buffer)
                await ws.send_json({
                    "type": "transcript",
                    "text": result.text,
                    "is_final": False,
                    "timestamp_ms": get_timestamp(),
                })

    except WebSocketDisconnect:
        # 最终完整转写
        final_result = await run_asr(audio_buffer)
        await ws.send_json({
            "type": "done",
            "text": final_result.text,
        })
```

---

## 3. 不要手写（用现成库）

| 问题 | 不要手写 | 用这个 | 为什么 |
|------|---------|--------|--------|
| Flutter音频录制+PCM流 | 自己封装AudioRecord | `record`包 | 跨平台兼容、权限处理、编码器支持 |
| WebSocket客户端 | 自己写心跳/重连 | `web_socket_channel` | 成熟实现，Stream API |
| 麦克风权限 | 手动调用平台API | `permission_handler` | Android/iOS统一API |
| 数据类 | 手写toJson/fromJson | `freezed` | 零运行时开销、IDE集成 |
| HTTP客户端 | 自己处理超时/重试 | `dio` | 拦截器、适配器成熟 |
| 模型量化 | 手写量化代码 | `autoawq` | 校准流程复杂、量化为INT4必须 |
| Python WebSocket | 自己处理帧 | FastAPI内置 | 异步、非阻塞、生产级 |
| 麦克风波形动画 | 自己用Canvas画 | `audio_waveforms`包 | 手势识别、实时可视化 |

---

## 4. 常见陷阱

### 陷阱1: vLLM plugin不支持流式ASR推理
**问题：** VibeVoice-ASR的vLLM plugin采用**批量批处理**架构，设计目标是处理完整音频文件（如60分钟），不是实时流式。
**症状：** WebSocket发送音频chunks后，服务器不返回中间结果，只在断开后返回完整转写。
**避免：** 规划阶段需确认plugin是否支持流式/增量推理。**备选方案**：如果不支持，改用`transformers`直接推理，参考VibeVoice仓库的`demo/web/app.py`。
**[ASSUMED]** — 需实际验证plugin的流式支持能力。

### 陷阱2: Flutter音频录制包名称错误
**问题：** SPEC.md写的是`flutter_record`，但pub.dev上的包名是`record`。没有名为`flutter_record`的包。
**症状：** `flutter pub add flutter_record` 会失败。
**避免：** 使用`record`包：`flutter pub add record`。
**[VERIFIED: pub.dev]**

### 陷阱3: WSL2 GPU passthrough在Windows Server 2025上失败
**问题：** 2026年3月报告显示Windows Server 2025上WSL2 GPU访问存在已知问题（"Failed to initialize NVML: GPU access blocked by the OS"）。
**影响：** GPU无法在容器内可见，CUDA推理无法运行。
**避免：** 在实际部署前验证GPU passthrough；考虑Windows 11代替Windows Server 2025，或使用Ubuntu Server原生安装。
**[ASSUMED]** — 单个issue来源，需要验证。

### 陷阱4: RTX 4060 8GB VRAM在叠加ASR+TTS时不足
**问题：** Phase 1后Phase 2叠加TTS（0.5B INT4），ASR 7B INT4 (~4GB) + TTS 0.5B INT4 (~0.25GB) + KV Cache + 中间激活值可能超过8GB。
**避免：** Phase 1规划时预留显存空间，不要用尽所有VRAM。
**[ASSUMED]**

### 陷阱5: FlashAttention-2在RTX 4060 (SM89)的向后传播限制
**问题：** FlashAttention-2对compute capability 8.9的向后传播（训练）仅支持head dim ≤ 64。
**缓解：** Phase 1是**推理**，仅需要向前传播，无此限制。
**[VERIFIED: FlashAttention GitHub Issue #190]**

### 陷阱6: audio_waveforms包在Android上的延迟
**问题：** `audio_waveforms`包依赖原生平台，Android上的波形更新可能有几十毫秒延迟。
**避免：** 如果延迟不可接受，考虑用CustomPainter自己绘制简单波形。
**[ASSUMED]**

---

## 5. 运行时状态清单

> Phase 1是greenfield项目，此项仅适用于后续有修改的Phase。当前无任何需要迁移的运行时状态。

| Category | Items Found | Action Required |
|----------|------------|------------------|
| Stored data | None | — |
| Live service config | None | — |
| OS-registered state | None | — |
| Secrets/env vars | None | — |
| Build artifacts | None | — |

---

## 6. 环境可用性

| 依赖 | Required By | Available | Version | Fallback |
|------|------------|-----------|---------|----------|
| Flutter | Flutter App | ✗ | — | 需在目标开发机安装 |
| Docker | 云端服务容器化 | ✓ | 28.0.4 | — |
| Python 3 | 云端推理服务 | ✓ | 3.14.3 | — |
| pip | Python包安装 | ✓ | 26.0 | — |
| Node.js | Flutter tooling | ✓ | v25.9.0 | — |
| Git | 版本控制 | ✓ | 2.50.1 | — |
| nvidia-smi | GPU验证 | ✗ | — | 预期（macOS开发机，GPU在Windows Server） |
| WSL2 | Windows GPU服务 | ? | — | 需在Windows Server上验证 |

**Missing dependencies with no fallback:**
- Flutter SDK — 必须在Windows/macOS/Linux开发机上安装
- Windows Server WSL2 GPU passthrough — 必须在RTX 4060服务器上验证

**Missing dependencies with fallback:**
- 无

---

## 7. 验证架构

> `workflow.nyquist_validation` 配置未找到（默认启用）

### 测试框架
| 属性 | 值 |
|------|---|
| 框架 | Flutter test (集成测试) + Python pytest (云端服务) |
| 配置 | `flutter_app/test/` + `cloud_server/tests/` |
| 快速运行 | `flutter test --reporter=compact` |
| 全量运行 | `flutter test` + `pytest cloud_server/tests/` |

### Phase Requirements → Test Map
| Req ID | 行为 | 测试类型 | 自动化命令 | 文件存在？ |
|--------|------|---------|-----------|-----------|
| REQ-01 | 中文普通话ASR识别 | 集成测试 | 真机或模拟器录音→WebSocket→验证返回文字 | ❌ Wave 0 |
| REQ-02 | WebSocket流式传输（16kHz PCM, 50ms chunks） | 单元+集成 | Mock WebSocket，验证chunk大小和频率 | ❌ Wave 0 |
| REQ-03 | 麦克风权限+网络状态UI | 集成测试 | 模拟权限拒绝/网络断开，验证UI反馈 | ❌ Wave 0 |
| RE-04 | RTX 4060 GPU推理服务 | 集成测试 | POST音频到`/v1/asr/stream`，验证响应 | ❌ Wave 0 |
| REQ-05 | APK打包+Android 12+运行 | 构建测试 | `flutter build apk --debug` | ❌ Wave 0 |
| REQ-10 | WebSocket断线重连 | 单元测试 | Mock WebSocket断开，验证重试次数和延迟 | ❌ Wave 0 |

### Wave 0 缺口
- [ ] `flutter_app/test/services/audio_recorder_test.dart` — 覆盖REQ-02
- [ ] `flutter_app/test/services/websocket_service_test.dart` — 覆盖REQ-10
- [ ] `flutter_app/test/widgets/mic_button_test.dart` — 覆盖REQ-03
- [ ] `cloud_server/tests/test_asr_stream.py` — 覆盖RE-04
- [ ] `cloud_server/tests/conftest.py` — 共享fixtures（FastAPI test client）
- [ ] Flutter安装: `flutter pub get` — 需在有Flutter环境时执行

---

## 8. 安全领域

> Phase 1 MVP无用户认证，但WebSocket暴露在公网需考虑以下安全措施。

### 适用ASVS类别

| ASVS类别 | 适用 | 标准控制 |
|---------|------|---------|
| V2 认证 | 否 | Phase 1无用户认证 |
| V3 会话管理 | 否 | — |
| V4 访问控制 | 部分 | IP白名单或临时Token（Claude's Discretion） |
| V5 输入验证 | 是 | FastAPI Pydantic验证音频bytes长度+格式 |
| V6 密码学 | 否 | 无敏感数据存储 |
| V7 错误处理 | 是 | 不向客户端暴露内部错误详情 |

### VibeVoice-ASR云端服务的已知威胁

| 模式 | STRIDE | 标准缓解 |
|------|--------|---------|
| WebSocket恶意音频数据 | Tampering | Pydantic验证bytes长度、格式 |
| 无限音频流（DoS） | Denial | 最大chunk数限制（~10000 chunks ≈ 500秒） |
| 模型推理资源耗尽 | Denial | vLLM的continuous batching资源配置max_seqs |

---

## 9. 假设日志

> 列出所有在研究中被标记为`[ASSUMED]`的声明

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | VibeVoice-ASR vLLM plugin支持流式/增量推理 | §4陷阱1 | 如果不支持，需要重构云端架构，改用transformers直接推理 |
| A2 | Windows Server 2025 + WSL2 GPU passthrough可用 | §4陷阱3 | 如果不work，需换Ubuntu Server或Windows 11 |
| A3 | RTX 4060显存可同时容纳ASR 7B INT4 + Phase 2 TTS 0.5B INT4 | §4陷阱4 | 如果不够，Phase 2需要降低ASR量化精度或用时间片分配 |
| A4 | audio_waveforms包在Android波形更新延迟可接受 | §4陷阱6 | 如果延迟高，需自绘波形 |

**如果此表非空：** Planner和discuss-phase使用此表确认哪些信息需要用户在执行前验证。

---

## 10. 开放问题

1. **vLLM plugin流式推理支持？**
   - 部分了解：plugin是批量处理设计，但未在生产环境验证
   - 不清楚：是否支持增量/流式ASR
   - 建议：规划阶段用`transformers`直接实现WebSocket+ASR作为稳妥方案

2. **VibeVoice-ASR的语音Tokenizer输入格式？**
   - 部分了解：模型使用VAE tokenizers（acoustic 64-dim + semantic 128-dim）
   - 不清楚：原始PCM如何encode为模型输入
   - 建议：参考`demo/web/app.py`和VibeVoice仓库中的inference示例代码

3. **RTX 4060 Windows Server WSL2 GPU passthrough验证？**
   - 2026年3月有失败报告，但未明确是否所有配置都失败
   - 建议：在实际Windows Server上验证，或准备Ubuntu Server备选方案

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: pub.dev] `record` package latest version 6.2.0 — Flutter音频录制PCM流
- [VERIFIED: pub.dev] `flutter_riverpod` version 3.3.1 (March 9, 2026) — Flutter状态管理
- [VERIFIED: GitHub] FlashAttention Issue #190 — RTX 3090 SM86向后传播限制（适用于RTX 4060 SM89）
- [VERIFIED: NVIDIA docs] RTX 4060 compute capability 8.9 (SM89/Ada Lovelace)
- [VERIFIED: vLLM docs] INT4 W4A16 quantization — RTX 4060 compute capability 8.9满足 > 8.0要求

### Secondary (MEDIUM confidence)
- [WebSearch] vLLM Realtime API (2026-01-31) — WebSocket流式支持，但仅Qwen3-ASR原生集成
- [WebSearch] Microsoft VibeVoice GitHub — vLLM plugin在`vllm_plugin/`目录
- [WebSearch] Docker Desktop WSL2 GPU passthrough docs
- [WebSearch] Flutter WebSocket音频流架构 — socket_audiostream, flutter_realtime_voice_ai

### Tertiary (LOW confidence)
- [ASSUMED] VibeVoice-ASR vLLM plugin流式推理支持 — 需要实际验证
- [ASSUMED] Windows Server 2025 WSL2 GPU passthrough可用性 — 单个issue来源
- [ASSUMED] audio_waveforms包Android延迟可接受

---

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — Flutter包有pub.dev验证；云端vLLM plugin架构有不确定性
- Architecture: HIGH — Flutter Clean Architecture + FastAPI模式成熟
- Pitfalls: MEDIUM — vLLM plugin流式推理是关键风险，需执行验证
- Security: MEDIUM — 无用户认证MVP，风险可控但不完整

**Research date:** 2026-04-06
**Valid until:** 2026-05-06（30天，vLLM/audio领域稳定）
