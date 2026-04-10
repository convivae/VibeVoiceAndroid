# VibeVoiceAndroid: Technical Roadmap

> **Project**: 将 Microsoft VibeVoice 语音 AI 移植到 Android/iOS 移动端  
> **Goal**: 构建支持 ASR（语音识别）和 Realtime TTS（实时语音合成）的跨平台移动应用  
> **Strategy**: 三阶段渐进式移植，云端优先 → 边缘计算 → 端侧部署  
> **Created**: 2026-04-02  
> **Status**: 🔴 Phase 0 - 立项规划

---

## 目录

- [0. 项目背景与目标](#0-项目背景与目标)
- [1. 参考项目分析](#1-参考项目分析)
- [2. 技术栈选型](#2-技术栈选型)
- [3. Phase 1: 云端 API 架构（Week 1-2）](#phase-1-云端-api-架构week-1-2)
- [4. Phase 2: 端侧 ASR 部署（Month 1-3）](#phase-2-端侧-asr-部署month-1-3)
- [5. Phase 3: 端侧 Realtime TTS（Month 3-6）](#phase-3-端侧-realtime-tts-month-3-6)
- [6. 工程挑战与风险](#6-工程挑战与风险)
- [7. 开发里程碑与验收标准](#7-开发里程碑与验收标准)
- [8. 附录：关键技术细节](#8-附录关键技术细节)

---

## 0. 项目背景与目标

### 0.1 VibeVoice 模型家族

VibeVoice 是 Microsoft 开源的前沿语音 AI，包含三个核心模型：

| 模型 | 参数量 | 核心能力 | 上下文 | 延迟 | 当前 Phase |
|------|--------|---------|--------|------|-----------|
| VibeVoice-ASR | 7B | 语音识别 + 说话人分离 + 时间戳 | 64K tokens (~60分钟音频) | 离线批处理 | Phase 2 目标 |
| VibeVoice-TTS | 1.5B | 长文本转语音 + 4 说话人 | 64K tokens (~90分钟) | 离线批处理 | 暂不移植 |
| **VibeVoice-Realtime** | **0.5B** | **流式实时 TTS** | 8K tokens (~10分钟) | **~200ms** | **Phase 1/3 目标** |

### 0.2 核心技术创新

- **7.5Hz 极低帧率连续语音 tokenizer**（Acoustic 64-dim + Semantic 128-dim 双 VAE）
- **Next-Token Diffusion 框架**：LLM 理解文本上下文 + Diffusion Head 生成 acoustic details
- 基于 **Qwen2.5** 作为 LLM backbone（0.5B / 1.5B / 7B 三种规模）
- 流式推理支持：text window + speech diffusion 并行生成

### 0.3 最终目标

构建一款跨平台（Android + iOS）语音 AI 应用，实现：

```
┌─────────────────────────────────────────┐
│  语音输入 → 实时转文字（ASR）           │
│  文字输入 → 实时语音合成（TTS）           │
│  对话模式（Voice → Voice 全双工）         │
└─────────────────────────────────────────┘
```

**优先级**：Realtime TTS 体验 > ASR 离线能力 > 多说话人 TTS

### 0.4 关键约束

- Android API 24+（Android 7.0，覆盖 98%+ 设备）
- iOS 14+（覆盖 95%+ 设备）
- 单次推理内存峰值 < 2GB（移动端 GPU 限制）
- 离线模式下 TTS 延迟 < 2s（可接受）
- 在线模式下 TTS 端到端延迟 < 500ms

---

## 1. 参考项目分析

### 1.1 直接参考

| 项目 | 链接 | 参考价值 | 借鉴内容 |
|------|------|---------|---------|
| **Vibing** | [VibingJustSpeakIt/Vibing](https://github.com/VibingJustSpeakIt/Vibing) | ⭐⭐⭐⭐⭐ | VibeVoice-ASR 已成功移植到 macOS/Windows 的案例，证明技术可行性 |
| **VibeVoice 官方 Demo** | [microsoft/VibeVoice](https://github.com/microsoft/VibeVoice) | ⭐⭐⭐⭐⭐ | 核心模型、WebSocket 实时服务、Gradio UI 的全部参考 |
| **flutter_soloud** | [alnitak/flutter_soloud](https://github.com/alnitak/flutter_soloud) | ⭐⭐⭐⭐ | Flutter 端 PCM 音频流播放的最佳实践，支持 low-latency audio |
| **flutter_voice_engine** | [pub.dev](https://pub.dev/documentation/flutter_voice_engine/latest) | ⭐⭐⭐⭐ | Flutter 麦克风录音 + WebSocket 流式传输的完整方案 |

### 1.2 云端推理参考

| 项目 | 链接 | 参考价值 | 借鉴内容 |
|------|------|---------|---------|
| **vLLM** | [vllm-project/vllm](https://github.com/vllm-project/vllm) | ⭐⭐⭐⭐ | 高性能推理引擎，Streaming Audio API，vLLM-Omni TTS 支持 |
| **vLLM Streaming & Realtime API** | [vLLM Blog](https://blog.vllm.ai/2026/01/31/streaming-realtime.html) | ⭐⭐⭐⭐ | 2026年流式 TTS 架构：SharedMemoryConnector + async chunked streaming |
| **vLLM-Omni** | [vllm-project/vllm-omni](https://github.com/vllm-project/vllm-omni) | ⭐⭐⭐⭐ | TTS 开发路线图，Qwen3-TTS RTF 0.34，TTFP 131ms |
| **CosyVoice** | [vllm-project/vllm-omni#1552](https://github.com/vllm-project/vllm-omni/issues/1552) | ⭐⭐⭐ | LLM-based streaming TTS 架构参考，150ms 延迟 |

### 1.3 端侧推理框架参考

| 框架 | 链接 | 平台 | 适合度 | 说明 |
|------|------|------|--------|------|
| **MNN** | [alibaba/MNN](https://github.com/alibaba/MNN) | Android/iOS | ⭐⭐⭐⭐⭐ | 阿里开源，端侧推理成熟，MNN-LLM 8.6x 加速，有 ASR/TTS 迁移案例（TaoAvatar） |
| **ExecuTorch** | [pytorch/executorch](https://github.com/pytorch/executorch) | Android/iOS | ⭐⭐⭐⭐ | PyTorch 原生，对 VibeVoice 代码改动最小，支持 Llama 3.2 1B/3B |
| **llama.cpp** | [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | Android/iOS | ⭐⭐⭐⭐ | GGUF 量化成熟，OpenCL GPU 加速（骁龙 8 Gen3），llamafile 0.10.0 全面 GPU 支持 |
| **Core ML** | Apple 官方 | iOS only | ⭐⭐⭐ | Apple 生态，但自定义 Transformer 层支持差，需 Objective-C++ 封装 |

### 1.4 移动端音频架构参考

| 文章 | 链接 | 核心参考点 |
|------|------|-----------|
| Real-Time Voice AI Android App (WebRTC.ventures) | [webrtc.ventures](https://webrtc.ventures/2026/02/blog-voice-ai-android-app-gemini-prototype/) | Android AudioRecord/AudioTrack + WebSocket + Gemini 2.0 集成架构 |
| Flutter Real-Time Voice Chat WebSocket | [dev.to](https://dev.to/abphaiboon/building-real-time-voice-chat-in-flutter-a-websocket-streaming-architecture-3iak) | Flutter WebSocket 流式架构，VoiceProvider + VoiceStreamController 模式 |
| vLLM Streaming Realtime API | [vLLM Blog](https://blog.vllm.ai/2026/01/31/streaming-realtime.html) | HTTP chunked transfer，131ms TTFP 目标 |

---

## 2. 技术栈选型

### 2.1 跨平台框架选型

| 方案 | 评分 | 推荐度 | 理由 |
|------|------|--------|------|
| **Flutter** | ⭐⭐⭐⭐⭐ | 🥇 强烈推荐 | 2026年性能领先 8-18%，120fps 更稳定，flutter_soloud 音频方案成熟，Impeller 渲染引擎 GPU 加速，Impeller 现已同时支持 iOS 和 Android |
| React Native | ⭐⭐⭐ | 🥉 备选 | Bridge 开销在高音频负载场景稍高，但 Fabric + TurboModules 已改善，需更多原生模块优化 |
| Kotlin Multiplatform | ⭐⭐ | 🥉 备选 | 共享业务逻辑，但 UI 差异化大，音频库不如 Flutter 成熟 |
| 各自原生开发 | ⭐⭐ | ❌ 不推荐 | 双倍工作量，Voice AI 逻辑需要跨平台一致体验 |

### 2.2 云端推理引擎选型

| 方案 | 评分 | 推荐度 | 理由 |
|------|------|--------|------|
| **vLLM + 自定义 ASR/TTS 封装** | ⭐⭐⭐⭐⭐ | 🥇 强烈推荐 | 高吞吐、Continuous Batching、Streaming 支持完善，已有 VibeVoice vLLM Plugin |
| TGI (Text Generation Inference) | ⭐⭐⭐ | 🥈 备选 | HuggingFace 官方，但 Streaming 性能不如 vLLM |
| FastAPI + PyTorch (裸跑) | ⭐⭐ | 🥉 不推荐 | 无批处理优化，吞吐量差 |

### 2.3 端侧推理框架选型（Phase 2/3 使用）

| 阶段 | 推荐框架 | 备选 | 理由 |
|------|---------|------|------|
| **Phase 2 (ASR)** | MNN | ExecuTorch | MNN 量化工具成熟（TaoAvatar 已验证 ASR/TTS 端侧），中文社区支持好 |
| **Phase 3 (TTS)** | ExecuTorch | MNN | 对 PyTorch 原生模型改动最小，Diffusion Head 支持较好 |

### 2.4 完整技术栈总览

```
┌─────────────────────────────────────────────────────────┐
│                    移动端 (Flutter)                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐          │
│  │ UI Layer │  │ 业务层   │  │ 音频引擎层   │          │
│  │ Flutter  │  │ BLoC/   │  │ AudioRecord │          │
│  │ Riverpod │  │ Provider │  │ AudioTrack  │          │
│  │          │  │          │  │ WebSocket   │          │
│  │          │  │          │  │ flutter_    │          │
│  │          │  │          │  │ soloud      │          │
│  └──────────┘  └──────────┘  └──────────────┘          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │         端侧推理层 (Phase 2/3 启用)                │   │
│  │  MNN / ExecuTorch  │  GGUF 量化模型             │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┬───────┘
                                                  │ HTTPS / WSS
┌─────────────────────────────────────────────────┴───────┐
│                    云端服务器                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │
│  │ 负载均衡     │  │ 推理服务集群  │  │ 模型服务  │  │
│  │  (nginx /   │→ │  (vLLM × N)  │→ │ VibeVoice│  │
│  │   Docker)   │  │  GPU × M     │  │ Realtime │  │
│  └──────────────┘  └──────────────┘  └──────────┘  │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │ WebSocket   │  │ FastAPI     │                    │
│  │ Server      │  │ REST API     │                    │
│  │ (uvicorn)   │  │ (Pydantic)  │                    │
│  └──────────────┘  └──────────────┘                    │
└──────────────────────────────────────────────────────────┘
```

---

## Phase 1: 云端 API 架构（Week 1-2）

### Phase 1 目标

> 在 **2 周内** 完成 MVP：Flutter App + 云端 VibeVoice Realtime TTS 服务，实现实时语音合成。

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App (Android/iOS)                    │
│                                                                  │
│  [用户输入文本]                                                     │
│       │                                                            │
│       ▼                                                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              BLoC / Riverpod State Management               │  │
│  │  VoiceServiceBloc: 录音状态 │ 播放状态 │ 连接状态 │ 错误处理│  │
│  └──────────────────────────────┬───────────────────────────────┘  │
│                                  │                                 │
│       ┌──────────────────────────┴──────────────────────────┐     │
│       ▼                                                    ▼     │
│  ┌─────────────┐                                     ┌─────────┐│
│  │ VoiceInput  │                                     │VoicePlay││
│  │ Recorder    │                                     │back     ││
│  │(10-50ms    │                                     │(flutter_ ││
│  │ chunks)     │                                     │ soloud) ││
│  └──────┬──────┘                                     └────┬────┘│
│         │                                                  │       │
│         └────────────────┬────────────────────────────────┘       │
│                          ▼                                        │
│              ┌─────────────────────────┐                           │
│              │   WebSocket Manager    │                           │
│              │  (自动重连 │ 心跳 │   │                           │
│              │   chunked 流处理)       │                           │
│              └───────────┬─────────────┘                           │
└──────────────────────────│───────────────────────────────────────┘
                            │ WSS / HTTPS
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│                      云端服务器 (Docker Compose)                      │
│                                                                    │
│  ┌──────────────┐     ┌──────────────────────────────────────┐  │
│  │ nginx       │     │         FastAPI + Uvicorn              │  │
│  │ (反向代理)   │────→│  GET  /health                        │  │
│  │ TLS 终止    │     │  POST /v1/tts (REST 备用)             │  │
│  │ 负载均衡    │     │  WS   /stream (WebSocket 流式)       │  │
│  └──────────────┘     └───────────────┬──────────────────────┘  │
│                                       │                          │
│                              ┌────────▼────────────────┐         │
│                              │    VibeVoice Service    │         │
│                              │  ┌─────────────────┐  │         │
│                              │  │ StreamingTTSService│ │         │
│                              │  │ (from app.py)    │  │         │
│                              │  │                  │  │         │
│                              │  │ voice prompt: .pt│ │         │
│                              │  │ text: str        │  │         │
│                              │  │ → PCM16 stream   │  │         │
│                              │  └────────┬─────────┘  │         │
│                              │           │             │         │
│                              │  ┌────────▼─────────┐  │         │
│                              │  │ AudioStreamer     │  │         │
│                              │  │ (chunked yield)   │  │         │
│                              │  └──────────────────┘  │         │
│                              └─────────────────────────────┘         │
│                                       │                             │
│                              ┌─────────▼────────────────┐            │
│                              │   GPU Inference Node     │            │
│                              │   VibeVoice-Realtime    │            │
│                              │   0.5B Qwen2.5         │            │
│                              │   FlashAttention-2      │            │
│                              │   bf16, CUDA 12+        │            │
│                              └──────────────────────────┘            │
└───────────────────────────────────────────────────────────────────┘
```

### 1.2 WebSocket 协议设计

#### 客户端 → 服务器（请求）

```json
// 握手 + 开始 TTS
{
  "type": "start",
  "text": "你好，这是一段测试文本",
  "voice": "en-Carter_man",        // 可选，默认 en-Carter_man
  "cfg_scale": 1.5,                 // 可选，默认 1.5
  "inference_steps": 5,              // 可选，默认 5
  "temperature": 0.9,               // 可选
  "top_p": 0.9                     // 可选
}
```

#### 服务器 → 客户端（响应）

```json
// 元数据
{
  "type": "metadata",
  "sample_rate": 24000,
  "channels": 1,
  "format": "pcm_s16le",
  "model": "microsoft/VibeVoice-Realtime-0.5B",
  "estimated_chunks": 42
}

// 音频块 (多次推送)
{
  "type": "audio_chunk",
  "data": "<base64 PCM16 bytes>",
  "chunk_index": 0,
  "timestamp_ms": 0,
  "is_final": false
}

// 日志事件
{
  "type": "log",
  "event": "backend_first_chunk_sent",
  "data": {"latency_ms": 287},
  "timestamp": "2026-04-02 10:30:01.123"
}

// 结束
{
  "type": "done",
  "total_chunks": 42,
  "total_duration_ms": 5200
}

// 错误
{
  "type": "error",
  "message": "Text is empty",
  "code": "INVALID_REQUEST"
}
```

### 1.3 Flutter App 模块设计

```
lib/
├── main.dart
├── app.dart                          # App 入口，Theme，Router
│
├── core/
│   ├── config/
│   │   └── api_config.dart           # 服务器地址、WS 配置、重连策略
│   ├── constants/
│   │   └── audio_constants.dart      # 采样率 (24000)、chunk 大小
│   └── errors/
│       └── exceptions.dart           # 自定义异常类型
│
├── data/
│   ├── repositories/
│   │   └── voice_repository_impl.dart # 语音服务 Repository 实现
│   └── datasources/
│       ├── remote/
│       │   ├── websocket_client.dart  # WebSocket 客户端封装
│       │   └── tts_api_client.dart   # REST API 客户端（备用）
│       └── local/
│           └── audio_cache.dart      # 音频缓存（可选）
│
├── domain/
│   ├── entities/
│   │   ├── voice_chunk.dart          # 音频块实体
│   │   └── tts_request.dart        # TTS 请求实体
│   └── repositories/
│       └── voice_repository.dart     # Repository 接口
│
├── presentation/
│   ├── blocs/
│   │   └── tts/
│   │       ├── tts_bloc.dart
│   │       ├── tts_event.dart
│   │       └── tts_state.dart
│   ├── screens/
│   │   ├── home_screen.dart          # 主界面
│   │   └── settings_screen.dart      # 设置（音色选择等）
│   └── widgets/
│       ├── text_input_panel.dart     # 文本输入面板
│       ├── voice_player_widget.dart  # 播放控制组件
│       └── voice_selector.dart      # 音色选择器
│
└── services/
    ├── audio/
    │   └── audio_service.dart       # AudioRecord + AudioTrack 封装
    └── websocket/
        └── websocket_service.dart    # WebSocket 连接管理
```

### 1.4 关键技术实现细节

#### 1.4.1 Flutter 音频录制（低延迟麦克风采集）

```dart
// 使用 flutter_voice_engine 或直接封装 AudioRecord
class VoiceRecorder {
  static const int SAMPLE_RATE = 16000; // 重采样到 16kHz 减小带宽
  static const int CHUNK_DURATION_MS = 50; // 50ms chunks
  static const int CHUNK_SIZE = 16000 * 50 ~/ 1000 * 2; // PCM16 字节数

  AudioRecord? _recorder;
  List<int> _buffer = [];

  Future<void> start() async {
    final config = AudioConfig(
      sampleRate: SAMPLE_RATE,
      channels: 1,
      bitDepth: 16,
      bufferSize: 4096,
    );
    _recorder = AudioRecord(config: config);
    await _recorder!.start();

    // 后台线程持续读取
    _readLoop();
  }

  void _readLoop() {
    final chunk = _recorder!.read(CHUNK_SIZE);
    // → 发送到 ASR 云端
  }
}
```

#### 1.4.2 Flutter 音频播放（低延迟播放）

```dart
// 使用 flutter_soloud 实现低延迟播放
import 'package:flutter_soloud/flutter_soloud.dart';

class VoicePlayer {
  SoLoud? _soloud;
  VoiceSource? _currentSource;

  Future<void> init() async {
    _soloud = SoLoud.instance;
    await _soloud!.init();
  }

  // WebSocket 收到 chunk 后立即播放
  void onChunkReceived(Uint8List pcmData) {
    if (_currentSource == null) {
      _currentSource = VoiceSource();
    }
    _currentSource!.addDataStream(Stream.value(pcmData));
    if (!_soloud!.isPlaying(_currentSource!)) {
      _soloud!.play(_currentSource!);
    }
  }

  void stop() {
    _soloud!.stop(_currentSource!);
    _currentSource = null;
  }
}
```

#### 1.4.3 WebSocket 断线重连策略

```dart
class WebSocketService {
  static const int MAX_RETRIES = 5;
  static const Duration BASE_DELAY = Duration(seconds: 1);
  static const Duration MAX_DELAY = Duration(seconds: 30);

  int _retryCount = 0;
  Duration _currentDelay = BASE_DELAY;

  Future<void> connect() async {
    try {
      await _socket.connect(url, protocols: ['vibevoice']);
      _retryCount = 0;
      _currentDelay = BASE_DELAY;
      _setupListeners();
    } on WsException catch (e) {
      await _handleDisconnect(e);
    }
  }

  Future<void> _handleDisconnect(WsException e) async {
    if (_retryCount >= MAX_RETRIES) {
      emit(ConnectionState.failed(maxRetriesReached: true));
      return;
    }

    emit(ConnectionState.reconnecting(
      attempt: _retryCount + 1,
      delay: _currentDelay,
    ));

    await Future.delayed(_currentDelay);
    _currentDelay = min(_currentDelay * 2, MAX_DELAY);
    _retryCount++;
    await connect();
  }
}
```

### 1.5 云端服务部署

#### 1.5.1 Docker Compose 配置

```yaml
# docker-compose.yml (Phase 1 - 单机部署)
version: '3.8'

services:
  vibevoice-api:
    image: nvidia/cuda:12.4-runtime-ubuntu22.04
    container_name: vibevoice-tts
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - MODEL_PATH=microsoft/VibeVoice-Realtime-0.5B
      - DEVICE=cuda
      - INFERENCE_STEPS=5
      - MAX_WORKERS=4
    ports:
      - "8000:8000"
    volumes:
      - ~/.cache/huggingface:/root/.cache/huggingface  # 模型缓存
      - ./voices:/app/voices                           # voice prompts
    command: >
      bash -c "
        pip install -e .[streamingtts] &&
        uvicorn web.app:app --host 0.0.0.0 --port 8000 --workers 1
      "
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  nginx:
    image: nginx:alpine
    container_name: vibevoice-proxy
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - vibevoice-api
```

#### 1.5.2 FastAPI 服务扩展（基于现有 app.py）

```python
# cloud_server/main.py
# 在 demo/web/app.py 基础上增加 REST 端点和健康检查

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uvicorn

app = FastAPI(title="VibeVoice Android Cloud API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境限制域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 导入现有的 StreamingTTSService
import sys
sys.path.insert(0, "/path/to/VibeVoice")
from demo.web.app import StreamingTTSService, app as base_app

# 共享服务实例（避免重复加载模型）
tts_service: Optional[StreamingTTSService] = None

@app.on_event("startup")
async def startup():
    global tts_service
    tts_service = StreamingTTSService(
        model_path=os.environ.get("MODEL_PATH", "microsoft/VibeVoice-Realtime-0.5B"),
        device=os.environ.get("DEVICE", "cuda"),
    )
    tts_service.load()

# ============ REST API ============

class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = "en-Carter_man"
    cfg_scale: Optional[float] = 1.5
    steps: Optional[int] = 5

class TTSResponse(BaseModel):
    success: bool
    audio_url: Optional[str] = None  # 预计算模式下返回 URL
    error: Optional[str] = None

@app.post("/v1/tts", response_model=TTSResponse)
async def tts_rest(request: TTSRequest):
    """REST 备用接口（完整音频返回）"""
    try:
        # 收集所有 chunks
        chunks = []
        async for chunk in tts_service.stream(request.text, ...):
            chunks.append(chunk)

        # 合并为完整音频
        full_audio = np.concatenate(chunks)
        # 保存为 WAV
        audio_url = await save_audio(full_audio, request.voice)
        return TTSResponse(success=True, audio_url=audio_url)
    except Exception as e:
        return TTSResponse(success=False, error=str(e))

# WebSocket 流式端点（核心）
@app.websocket("/v1/tts/stream")
async def tts_websocket(ws: WebSocket):
    """流式 TTS WebSocket 端点"""
    await ws.accept()

    try:
        # 接收请求
        msg = await ws.receive_json()
        text = msg.get("text", "")
        voice = msg.get("voice", "en-Carter_man")
        cfg_scale = msg.get("cfg_scale", 1.5)
        steps = msg.get("steps", 5)

        # 发送元数据
        await ws.send_json({
            "type": "metadata",
            "sample_rate": 24000,
            "channels": 1,
            "format": "pcm_s16le",
        })

        # 流式推送音频
        chunk_idx = 0
        async for audio_chunk in tts_service.stream_async(
            text, voice, cfg_scale, steps
        ):
            pcm_bytes = tts_service.chunk_to_pcm16(audio_chunk)
            await ws.send_bytes(pcm_bytes)
            chunk_idx += 1

        await ws.send_json({"type": "done", "total_chunks": chunk_idx})

    except WebSocketDisconnect:
        pass
    except Exception as e:
        await ws.send_json({"type": "error", "message": str(e)})

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": tts_service is not None,
        "model": os.environ.get("MODEL_PATH", "unknown"),
    }

@app.get("/voices")
async def list_voices():
    return {
        "voices": list(tts_service.voice_presets.keys()),
        "default": tts_service.default_voice_key,
    }
```

### 1.6 Phase 1 验收标准

| 验收项 | 标准 | 测试方法 |
|--------|------|---------|
| TTS 流式延迟 | 首音频 chunk < 500ms | 从发送请求到收到第一块 PCM 的时间 |
| TTS 语音质量 | MOS 主观评分 > 3.5 | 用户评测 |
| WebSocket 稳定性 | 连续 10 分钟不断线 | 自动化测试 |
| 断线重连 | 3 次内重连成功 | 人工拔网线测试 |
| 音频播放 | 无可感知的卡顿 | 播放 60s 长文本 |
| iOS 兼容性 | iPhone 12+ 流畅运行 | 真机测试 |
| Android 兼容性 | Android 12+ 流畅运行 | Android Studio 模拟器 + 真机 |

### 1.7 Phase 1 工作量估算

| 任务 | 预估时间 | 负责方 |
|------|---------|-------|
| Flutter 项目初始化 + 依赖配置 | 4h | Flutter |
| 云端 FastAPI 服务扩展 | 4h | Backend |
| WebSocket 客户端封装 | 8h | Flutter |
| 音频录制 + 播放实现 | 8h | Flutter |
| TTS 核心 UI（文本输入 + 播放控制） | 8h | Flutter |
| 音色选择器 UI | 4h | Flutter |
| Docker 部署配置 | 4h | DevOps |
| 端到端集成测试 | 8h | 全栈 |
| **合计** | **48h（约 6 人天）** | |

---

## Phase 2: 端侧 ASR 部署（Month 1-3）

### Phase 2 目标

> 在 **3 个月内**，将 VibeVoice-ASR (7B) 量化为移动端可用的大小，实现在 **iOS/Android 上离线语音识别**。

### 2.1 为什么先做 ASR 而不是 TTS

1. **模型更小可分割**：ASR 7B 模型可以通过量化降到 ~400MB INT4，适合移动端
2. **无实时性硬约束**：ASR 是离线批处理，不要求 <500ms 延迟
3. **技术风险已验证**：已有 Vibing 项目证明 ASR 移动端可行
4. **产品价值明确**：离线语音输入是强需求（无网络时也能用）

### 2.2 端侧推理架构

```
┌────────────────────────────────────────────────────────────────┐
│                      Flutter App                                 │
│                                                                 │
│  AudioRecord (麦克风 16kHz PCM)                                 │
│         │                                                      │
│         ▼                                                      │
│  ┌─────────────┐   ┌──────────────┐                             │
│  │ ASR BLoC  │   │  文本展示    │                             │
│  │ 状态管理   │──→│  UI         │                             │
│  └──────┬─────┘   └──────────────┘                             │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────┐                        │
│  │      MNN / ExecuTorch Engine         │                        │
│  │                                      │                        │
│  │  ┌──────────┐  ┌──────────┐        │                        │
│  │  │ Acoustic │  │ Semantic  │        │                        │
│  │  │Tokenizer │  │Tokenizer  │        │  ← VAE 编码 (CPU/GPU)  │
│  │  │ (INT8)  │  │  (INT8)   │        │                        │
│  │  └────┬─────┘  └────┬─────┘        │                        │
│  │       │               │             │                        │
│  │       └───────┬───────┘             │                        │
│  │               ▼                      │                        │
│  │  ┌────────────────────────┐          │                        │
│  │  │   Qwen2.5-7B LLM     │          │                        │
│  │  │   (GGUF INT4)         │          │  ← 主推理 (NPU/GPU)    │
│  │  └────────────┬─────────┘          │                        │
│  │               ▼                      │                        │
│  │  ┌────────────────────────┐          │                        │
│  │  │  lm_head → Text Tokens│          │                        │
│  │  └────────────────────────┘          │                        │
│  └──────────────────────────────────────┘                        │
└────────────────────────────────────────────────────────────────┘
```

### 2.3 模型量化流程

#### 2.3.1 量化方案对比

| 量化方法 | 模型大小 | 精度损失 | 推理速度 | 推荐度 |
|---------|---------|---------|---------|--------|
| FP16 | ~14GB | 无 | 1x | ❌ 太大 |
| INT8 | ~7GB | ~5% 质量下降 | ~1.5x | ⭐⭐ 勉强 |
| **INT4 (AWQ)** | **~4GB** | **~10% 质量下降** | **~2x** | **⭐⭐⭐⭐ 首选** |
| INT4 (GPTQ) | ~4GB | ~12% 质量下降 | ~2x | ⭐⭐⭐ 可选 |
| INT4 + 稀疏 | ~2.5GB | ~15% 质量下降 | ~3x | ⭐⭐ 实验性 |

**最终选择**：INT4 AWQ 量化，平衡体积和精度。

#### 2.3.2 量化流程

```python
# Phase 2/quantization/quantize_vibevoice_asr.py
"""
VibeVoice-ASR 端侧量化流程
依赖: autoawq, transformers, vibevoice
"""

import torch
from transformers import AutoModelForCausalLM
from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer
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
        "q_group_size": 128,      # 128 对移动端更友好
        "w_bit": 4,
        "version": "GEMM",          # GEMM > GEMV for batch inference
    }

    # Step 3: 运行 AWQ 校准（需要少量校准数据）
    print("Running AWQ calibration...")
    model = AutoAWQForCausalLM.from_pretrained(
        MODEL_PATH,
        torch_dtype=torch.float16,
        trust_remote_code=True
    )

    # 使用少量代表性音频数据做校准 (~100 samples)
    calibration_data = load_calibration_audio(n_samples=100)

    model.quantize(
        tokenizer,
        quant_config=quant_config,
        calibration_data=calibration_data,
    )

    # Step 4: 保存量化模型
    print(f"Saving quantized model to {QUANTIZED_OUTPUT}...")
    model.save_quantized(QUANTIZED_OUTPUT)
    tokenizer.save_pretrained(QUANTIZED_OUTPUT)

    # Step 5: 生成模型信息
    generate_model_info(QUANTIZED_OUTPUT)

def generate_model_info(output_path: str):
    """生成移动端加载所需的信息文件"""
    info = {
        "model_type": "vibevoice_asr",
        "quantization": "int4_awq",
        "w_bit": 4,
        "q_group_size": 128,
        "hidden_size": 3584,
        "num_layers": 28,          # Qwen2.5-7B = 28 layers
        "vocab_size": 152064,
        "sample_rate": 24000,
        "acoustic_dim": 64,
        "semantic_dim": 128,
        "context_length": 65536,
        "memory_estimate_mb": 4096,
    }
    import json
    with open(os.path.join(output_path, "model_info.json"), "w") as f:
        json.dump(info, f, indent=2)
```

### 2.4 MNN 导出与部署

```python
# Phase 2/export/mnn_export.py
"""
将量化后的 VibeVoice-ASR 导出为 MNN 格式
"""
import MNN
import torch
from transformers import AutoTokenizer
from awq import AutoAWQForCausalLM

def export_to_mnn():
    # Step 1: 加载量化模型
    model = AutoAWQForCausalLM.from_pretrained(
        "./quantized_vibevoice_asr",
        device_map="cpu",  # MNN 导出走 CPU
        trust_remote_code=True
    )

    # Step 2: 准备示例输入
    # ASR 模型需要: input_ids (text) + speech_features (audio)
    example_text_ids = torch.randint(0, 152064, (1, 512))
    example_speech = torch.randn(1, 512, 192)  # acoustic + semantic concat

    # Step 3: 跟踪并转换为 MNN
    print("Converting to MNN format...")

    # 由于 VibeVoice 是复杂的多模态模型（全链路导出困难），
    # 方案: 仅导出 LLM backbone，VAE encoder 单独部署

    # LLM backbone 导出
    llm_backbone = model.model.language_model

    # 创建 MNN Expresser 并导出
    expresser = MNN.Expresser()

    # 使用 MNN 的 PyTorch 导入工具
    mnn_var_map, mnn_var_list = MNN.HZBackend.RunAsMNN({
        "input_ids": example_text_ids.numpy(),
        "speech_features": example_speech.numpy(),
    })

    # MNN 序列化
    mnn_net = MNN.Net()
    # ... 详细导出代码（参考 MNN 官方文档）

    mnn_net.saveToFile("./vibevoice_asr.mnn")
    print("MNN model saved!")

    # Step 4: 打包 assets
    package_mnn_assets("./output/")
```

### 2.5 Flutter 端侧推理集成

```dart
// lib/services/asr/asr_engine.dart
import 'package:flutter/services.dart';
import 'package:mnn_flutter/mnn_engine.dart';

class ASREngine {
  MNNEngine? _mnnEngine;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 加载 MNN 模型 (首次从 assets 复制到 app documents)
    final modelBytes = await rootBundle.load('assets/models/vibevoice_asr.mnn');
    final modelInfo = await rootBundle.loadString('assets/models/model_info.json');

    _mnnEngine = MNNEngine.create(
      modelData: modelBytes.buffer.asUint8List(),
      numThreads: 4,  // 根据设备动态调整
      power: PowerMode.high,
    );

    _isInitialized = true;
  }

  /// 转录一段音频
  Future<ASRResult> transcribe({
    required List<double> audioSamples,
    int sampleRate = 24000,
    String? contextInfo,
  }) async {
    if (!_isInitialized) await initialize();

    // Step 1: 音频预处理 (重采样到 24kHz, 归一化)
    final processedAudio = _preprocessAudio(audioSamples, sampleRate);

    // Step 2: Acoustic Tokenizer (VAE encode)
    // 在移动端可以用简化的特征提取替代完整 VAE
    final acousticFeatures = await _encodeAcoustic(processedAudio);

    // Step 3: Semantic Tokenizer
    final semanticFeatures = await _encodeSemantic(processedAudio);

    // Step 4: 合并特征
    final combinedFeatures = _mergeFeatures(acousticFeatures, semanticFeatures);

    // Step 5: LLM 推理
    final outputTokens = await _mnnEngine!.run({
      "input_ids": _buildInputIds(contextInfo),
      "speech_features": combinedFeatures,
    });

    // Step 6: 解码为文本
    return _decodeTokens(outputTokens);
  }

  void dispose() {
    _mnnEngine?.release();
    _isInitialized = false;
  }
}
```

### 2.6 Phase 2 技术挑战

| 挑战 | 原因 | 解决方案 |
|------|------|---------|
| **7B 模型太大** | 完整模型 INT4 也有 ~4GB | 优先量化 LLM backbone（3.5GB），VAE encoder 保持 FP16 (~200MB) |
| **Acoustic Tokenizer 导出复杂** | 自定义 VAE 层 MNN 支持有限 | VAE encoder 用 libtorch 动态加载，或用 TFLite 单独导出 |
| **Diffusion Head 不兼容** | MNN 不支持自定义 Diffusion 算子 | Phase 2 仅做 ASR，不需要 diffusion |
| **内存峰值超限** | 7B LLM + KV cache 峰值 > 2GB | INT4 + 减少 max_context + chunked inference |
| **量化精度损失** | AWQ 量化后 WER 可能上升 10-20% | LoRA 微调补偿（用手机录制的数据） |

### 2.7 Phase 2 验收标准

| 验收项 | 标准 | 测试方法 |
|--------|------|---------|
| 模型大小 | < 500MB（INT4 LLM + FP16 VAE） | 文件大小检查 |
| 内存峰值 | < 1.5GB VRAM | Android Profiler |
| ASR WER | 相比 FP16 损失 < 15% | LibriSpeech test-clean |
| 推理延迟 | < 5s（60s 音频） | 计时测试 |
| 离线可用性 | 无网络环境下完整功能 | 飞行模式测试 |
| 发热控制 | 连续推理 5 分钟温度 < 45°C | 温度监控 |

---

## Phase 3: 端侧 Realtime TTS（Month 3-6）

### Phase 3 目标

> 在 **6 个月内**，将 VibeVoice-Realtime (0.5B) 移植到移动端，实现**离线实时语音合成**。

### 3.1 挑战分析

这是整个移植项目**最难的部分**，原因如下：

```
挑战 1: Diffusion Head 依赖 LLM hidden states
├── 每生成一个语音 token，都需要 LLM forward pass
├── 无法提前 precompute 所有语音 token
└── 移动端 LLM 推理本身就慢 → TTS 延迟成倍增加

挑战 2: 移动端缺少 Flash Attention
├── CUDA Flash Attention 在手机不存在
├── naive attention 速度慢 3-5x
└── 需要 ARM NEON / GPU 优化的 attention kernel

挑战 3: 流式生成需要严格延迟控制
├── 每步 diffusion (~20ms) + 每步 LLM (~50ms) = ~70ms/token
├── 语音实时播放需要 ~40ms/frame
└── 总延迟 = 200ms (LLM decode) + 20ms (diffusion) = ~220ms

挑战 4: 0.5B 模型 + diffusion 内存压力大
├── Qwen2.5-0.5B INT4: ~250MB
├── Diffusion Head: ~50MB
├── Acoustic Tokenizer: ~100MB
├── KV Cache (8K context): ~200MB
└── 总计: ~600MB（勉强可接受）
```

### 3.2 技术方案

#### 3.2.1 方案一：ExecuTorch 完整移植（推荐）

```python
# Phase 3/export/export_realtime_tts.py
"""
使用 ExecuTorch 导出 VibeVoice-Realtime 完整链路
"""

import torch
from transformers import AutoModelForCausalLM
from executorch.sdk import ExecuTorchRegistry

def export_realtime_tts():
    # 加载原始模型
    model = VibeVoiceStreamingForConditionalGenerationInference.from_pretrained(
        "microsoft/VibeVoice-Realtime-0.5B",
        torch_dtype=torch.float16,
    )

    # 准备示例输入
    example_text = torch.randint(0, 152064, (1, 128))
    example_voice_prompt = torch.randn(1, 100, 64)

    # 简化模型图（移除不需要的分支）
    # ExecuTorch 暂时不支持完整的多分支流式推理，
    # 需要先将 text LM 和 TTS LM 分离导出

    # Part A: Text LM (Qwen2.5-0.5B backbone)
    text_lm = model.model.language_model
    text_lm_inputs = (example_text,)
    text_lm_output = text_lm(*text_lm_inputs)

    # Part B: TTS LM (upper layers)
    tts_lm = model.model.tts_language_model

    # Part C: Diffusion Head
    diffusion_head = model.model.prediction_head

    # Part D: Acoustic Tokenizer (Decoder)
    acoustic_tokenizer = model.model.acoustic_tokenizer

    # ExecuTorch 分段导出
    # ... (参考 ExecuTorch 官方 Llama 导出流程)

    print("Export complete! Check ./outputs/")
```

**优势**：对 PyTorch 模型改动最小，PyTorch 官方支持  
**劣势**：ExecuTorch 对自定义 diffusion 层支持有限，需要写 custom operator

#### 3.2.2 方案二：MNN + Custom Ops（中长期方案）

```
Phase 3A: 仅导出 LLM backbone (0.5B) → MNN
Phase 3B: Diffusion Head → 自定义 MNN OP (C++)
Phase 3C: Acoustic Tokenizer → TFLite 或 MNN
Phase 3D: 整合所有组件为统一推理引擎
```

**优势**：MNN 在中文生态有较好支持  
**劣势**：工程量巨大（需要为 diffusion 写 custom CUDA/Metal kernel）

### 3.3 延迟优化策略

| 优化项 | 目标 | 实现方式 |
|--------|------|---------|
| 减少 diffusion 步数 | 20步 → 5步 | 用更激进的 schedule（代价：音质轻微下降） |
| KV Cache 优化 | 减少 50% 内存 | INT4 量化 KV cache |
| 预计算 voice prompt | 消除初始化延迟 | 预加载 .pt voice prompt 到内存 |
| 增量生成 | 减少重复计算 | 缓存 text window 编码结果 |
| 异步化 | 隐藏延迟 | 下一个 text window 和当前 audio chunk 并行处理 |

### 3.4 混合部署策略（务实方案）

```
┌─────────────────────────────────────────────────────────┐
│               智能路由推理引擎                            │
│                                                          │
│  用户发起 TTS 请求                                       │
│       │                                                 │
│       ▼                                                 │
│  ┌──────────────┐                                      │
│  │ 延迟要求检测 │                                      │
│  └──────┬───────┘                                      │
│         │                                               │
│   ┌─────┴─────┐                                        │
│   ▼           ▼                                        │
│ <500ms?    >500ms?                                     │
│   │           │                                         │
│   ▼           ▼                                         │
│ 云端推理    端侧推理                                     │
│ (Phase 1)  (Phase 3)                                   │
│                                        │
│  自动切换，无感知                                  │
└─────────────────────────────────────────────────────────┘
```

**实现**：App 检测当前网络质量和设备状态，动态选择推理路径：
- 网络良好 + 用户不敏感 → 云端
- 网络不佳 / 隐私模式 → 端侧
- 设备发热 / 电量低 → 云端降级

### 3.5 Phase 3 验收标准

| 验收项 | 标准 | 测试方法 |
|--------|------|---------|
| 模型大小 | < 800MB（INT4 LLM + diffusion + VAE） | 文件大小检查 |
| 首音频延迟 | < 2s（离线） / < 500ms（在线） | 从点击播放到听到声音的时间 |
| 端到端流畅度 | MOS > 3.0 | 用户主观评测 |
| 内存峰值 | < 1GB | Android Profiler |
| 发热 | 连续播放 10 分钟 < 42°C | 温度监控 |
| 电池消耗 | 10 分钟 TTS 消耗 < 5% 电量 | 电量测试 |

---

## 6. 工程挑战与风险

### 6.1 风险矩阵

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| MNN 量化导出失败 | 中 | 高 | 同时测试 ExecuTorch 备选方案 |
| 移动端内存不足 | 高 | 高 | 从 0.5B 开始验证，不直接上 1.5B/7B |
| Diffusion 延迟无法优化 | 中 | 高 | 接受较高延迟，或减少 diffusion 步数 |
| Flutter 音频延迟过高 | 低 | 中 | 使用 flutter_soloud + native echo cancellation |
| 云端部署 GPU 成本高 | 中 | 中 | Phase 2 后优先推送端侧推理 |
| iOS CoreML 自定义层支持差 | 高 | 低 | iOS 用 ExecuTorch（MPS backend） |

### 6.2 技术债务

| 技术债务 | 清理计划 |
|---------|---------|
| 硬编码音频采样率 (24000) | Phase 1 结束后统一为常量配置 |
| 缺少移动端性能基准测试 | 每个 Phase 结束前完成性能测试 |
| WebSocket 无鉴权 | Phase 1 结束后添加 Token 认证 |
| 无离线缓存策略 | Phase 2 完成后实现 voice prompt 缓存 |

---

## 7. 开发里程碑与验收标准

```
Timeline (Month 1-6)
───────────────────────────────────────────────────────────►
     │        │        │        │        │        │
   Phase 1   Phase 2  Phase 3  Test    Polish  Launch
  ┌────────┐ ┌────────┐ ┌────────┐
  │云端MVP │ │端侧ASR │ │端侧TTS │
  │        │ │        │ │        │
  │ Week1-2│ │Month1-3│ │Month3-6│
  └────────┘ └────────┘ └────────┘

Milestones:
M0 (Week 0): 项目初始化，Flutter 骨架，Git 仓库建立
M1 (Week 2): Phase 1 完成 → 云端 TTS App 可用
M2 (Month 3): Phase 2 完成 → 离线 ASR 可用
M3 (Month 6): Phase 3 完成 → 离线 TTS 可用
M4 (Month 7): 集成测试 + 性能调优
M5 (Month 8): 正式发布
```

### 验收检查清单

**M1 验收（Week 2）**
- [ ] Flutter App 可在 Android/iOS 上运行
- [ ] WebSocket 连接云端 TTS 服务成功
- [ ] 文本输入 → 语音播放 完整链路通
- [ ] 首音频延迟 < 500ms
- [ ] 连续播放 60s 无卡顿
- [ ] 断线重连正常

**M2 验收（Month 3）**
- [ ] ASR 模型 INT4 量化完成 < 500MB
- [ ] 离线 ASR 推理成功
- [ ] WER 相比 FP16 损失 < 15%
- [ ] 推理延迟 < 5s（60s 音频）
- [ ] 内存峰值 < 1.5GB

**M3 验收（Month 6）**
- [ ] Realtime TTS 离线推理成功
- [ ] 首音频延迟 < 2s（离线）
- [ ] 模型 + diffusion + VAE < 800MB
- [ ] MOS 评分 > 3.0
- [ ] 内存峰值 < 1GB

---

## 8. 附录：关键技术细节

### 8.1 VibeVoice 音频格式规范

| 参数 | 值 | 说明 |
|------|---|------|
| 采样率 | 24000 Hz | 固定，不随输入变化 |
| 声道数 | 1 (mono) | 移动端录音多为 16kHz，需重采样 |
| 位深 | 16-bit PCM | VibeVoice 内部 float32，输出 PCM16 |
| 编码 | pcm_s16le | Little-endian signed 16-bit |
| chunk 大小 | ~480 bytes | 50ms × 24000Hz × 1ch × 2bytes / 1000 ≈ 2400 bytes / chunk |

### 8.2 VibeVoice 特殊 Token ID

| Token | ID | 用途 |
|-------|----|------|
| `<|speech_start|>` | (tokenizer.speech_start_id) | 音频 embedding 起始 |
| `<|speech_end|>` | (tokenizer.speech_end_id) | 音频 embedding 结束 |
| `<|speech_pad|>` | (tokenizer.speech_pad_id) | 填充 token |
| `<|AUDIO|>` | (vocab["<\|AUDIO\|>"]) | 音频 placeholder |
| `<|audio_bos|>` | (vocab["<\|audio_bos\|>"]) | 音频 BOS |
| `<|audio_eos|>` | (vocab["<\|audio_eos\|>"]) | 音频 EOS |

### 8.3 移动端音频重采样

```dart
// 移动端录音通常是 16kHz，VibeVoice 需要 24kHz
List<double> resampleTo24000Hz(List<double> input, int inputRate) {
  final ratio = 24000 / inputRate;
  final outputLength = (input.length * ratio).round();
  final output = List<double>.filled(outputLength, 0);

  for (int i = 0; i < outputLength; i++) {
    final srcIndex = i / ratio;
    final srcIndexFloor = srcIndex.floor();
    final srcIndexCeil = min(srcIndexFloor + 1, input.length - 1);
    final t = srcIndex - srcIndexFloor;
    output[i] = input[srcIndexFloor] * (1 - t) + input[srcIndexCeil] * t;
  }
  return output;
}
```

### 8.4 WebSocket Chunked PCM 流协议

```
帧结构:
┌──────────────────────────────────────────┐
│  Type (1 byte) │ Length (4 bytes) │ Data │
│  0x01 = metadata                        │
│  0x02 = audio_chunk                     │
│  0x03 = log_event                       │
│  0x04 = done                            │
│  0xFF = error                           │
└──────────────────────────────────────────┘

最优 chunk 大小:
- 理论最优: 50ms × 24kHz × 2bytes = 2400 bytes
- 网络友好: 100ms × 24kHz × 2bytes = 4800 bytes
- 推荐: 100ms per chunk (平衡延迟和吞吐)
```

### 8.5 推荐依赖版本

| 依赖 | 版本 | 说明 |
|------|------|------|
| Flutter | >= 3.24 | Impeller 稳定版 |
| Dart | >= 3.5 | null safety + records |
| flutter_soloud | >= 3.0 | 低延迟音频播放 |
| web_socket_channel | >= 3.0 | WebSocket 客户端 |
| dio | >= 5.0 | HTTP 客户端 |
| freezed | >= 5.0 | 数据类生成 |
| riverpod | >= 2.5 | 状态管理 |
| go_router | >= 14.0 | 路由 |

| 后端依赖 | 版本 | 说明 |
|---------|------|------|
| Python | >= 3.10 | |
| transformers | 4.51.3 | VibeVoice 兼容版本 |
| torch | >= 2.0 | |
| vllm | >= 0.6 | 高性能推理 |
| fastapi | >= 0.115 | |
| uvicorn | >= 0.30 | ASGI server |
| pydantic | >= 2.0 | 数据验证 |
| nginx | >= 1.25 | 反向代理 |
| Docker | >= 24.0 | 容器化 |

### 8.6 项目目录结构建议

```
VibeVoiceAndroid/
├── SPEC.md                          # 本文档
│
├── flutter_app/                      # Flutter 应用
│   ├── pubspec.yaml
│   ├── lib/
│   ├── ios/
│   ├── android/
│   └── test/
│
├── cloud_server/                     # 云端推理服务
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── nginx.conf
│   ├── requirements.txt
│   └── app/
│       ├── main.py
│       ├── api/
│       ├── services/
│       └── models/
│
├── quantization/                     # 模型量化工具
│   ├── requirements.txt
│   ├── scripts/
│   │   ├── quantize_asr.py
│   │   ├── quantize_tts.py
│   │   └── evaluate_quality.py
│   └── calibration_data/
│
├── export/                           # 模型导出工具
│   ├── mnn_export.py
│   ├── executorch_export.py
│   └── test_inference.py
│
└── docs/                            # 文档
    ├── api_reference.md
    ├── deployment_guide.md
    └── mobile_optimization.md
```

---

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|---------|
| 2026-04-02 | v1.0 | 初稿创建 |

---

**下一步行动**：完成 Phase 1 的详细设计和代码实现。
