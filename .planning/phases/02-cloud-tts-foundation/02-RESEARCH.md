# Phase 2: Cloud TTS Foundation - Research

**Status:** Research Complete
**Date:** 2026-04-10

---

## 1. 云端 TTS 服务部署

### 1.1 VibeVoice-Realtime-0.5B 模型分析

#### 模型规格

| 参数 | 值 | 说明 |
|------|-----|------|
| 参数量 | 0.5B | Qwen2.5-0.5B LLM backbone |
| 上下文长度 | 8K tokens | 最大输入 |
| 生成长度 | ~10 分钟 | 单次请求最大语音长度 |
| 首音频延迟 | ~300ms | 官方标称（硬件依赖） |
| 音频输出 | 24kHz, mono, PCM16 | 固定采样率 |
| 支持语言 | 英文为主 | 其他语言支持有限 |

#### 架构特点

```
VibeVoice-Realtime-0.5B
├── Acoustic Tokenizer (7.5 Hz 极低帧率)
│   ├── 3200x 降采样 (24kHz → 7.5Hz acoustic tokens)
│   └── 基于 σ-VAE 变体
├── LLM Backbone (Qwen2.5-0.5B)
│   ├── Causal attention (支持流式)
│   └── Sliding window attention
└── Diffusion Head
    └── 声学细节生成
```

**关键发现**: VibeVoice-Realtime 仅使用 Acoustic Tokenizer（无 Semantic Tokenizer），使其成为真正的流式模型。

### 1.2 vLLM TTS 服务方案

#### 方案 A: vLLM-Omni 原生支持

vLLM-Omni (v0.6+) 原生支持 TTS 服务：

```bash
# Qwen3-TTS (推荐用于中文支持)
vllm serve Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice \
  --stage-configs-path vllm_omni/model_executor/stage_configs/qwen3_tts.yaml \
  --omni --port 8000 --trust-remote-code --enforce-eager

# 性能指标
# - RTF: 0.34 (比实时快 3 倍)
# - TTFP: 131ms
```

**支持模型:**
- Qwen3-TTS (CustomVoice, VoiceDesign, Base)
- Fish Speech S2 Pro
- Voxtral TTS

#### 方案 B: FastAPI 自定义封装

对于 VibeVoice-Realtime-0.5B，需要自定义 FastAPI 封装：

```python
# cloud_server/app/tts_service.py
from fastapi import WebSocket, WebSocketDisconnect
from vllm import LLM, SamplingParams
import torch
import numpy as np

class VibeVoiceTTSService:
    def __init__(self, model_path: str, device: str = "cuda"):
        self.llm = LLM(
            model=model_path,
            trust_remote_code=True,
            tensor_parallel_size=1,
            gpu_memory_utilization=0.7,
        )
        self.sampling_params = SamplingParams(
            max_tokens=2048,
            temperature=0.7,
            top_p=0.9,
        )

    async def stream(self, text: str, voice_id: str):
        """流式生成音频 chunks"""
        # 1. Tokenize 输入文本
        # 2. 增量生成音频 tokens
        # 3. 通过 Acoustic Decoder 转换为 PCM
        # 4. Yield PCM chunks (约 50ms per chunk)
        pass

    def pcm_to_bytes(self, pcm: np.ndarray) -> bytes:
        """转换为小端序 16-bit PCM"""
        return (pcm * 32767).astype(np.int16).tobytes()
```

#### 方案选择

| 方案 | 优势 | 劣势 | 推荐度 |
|------|------|------|--------|
| vLLM-Omni | 原生流式、已优化 | VibeVoice 可能不兼容 | ⭐⭐⭐ 待验证 |
| FastAPI 自定义 | 完全控制 | 需要自行实现流式逻辑 | ⭐⭐⭐ 备选 |

**建议**: 先尝试 vLLM-Omni 加载 VibeVoice-Realtime-0.5B，若不支持则使用自定义 FastAPI 封装。

### 1.3 WebSocket 流式端点设计

#### 端点定义

```
WS /v1/tts/stream
```

#### 握手协议 (Client → Server)

```json
{
  "type": "start",
  "text": "你好，欢迎使用语音合成",
  "voice_id": "zh_female_1",
  "cfg_scale": 1.5,
  "inference_steps": 5
}
```

#### 元数据响应 (Server → Client)

```json
{
  "type": "metadata",
  "sample_rate": 24000,
  "channels": 1,
  "format": "pcm_s16le",
  "model": "microsoft/VibeVoice-Realtime-0.5B",
  "estimated_chunks": 42,
  "estimated_duration_ms": 5250
}
```

#### 音频数据响应 (Server → Client)

```json
{
  "type": "audio_chunk",
  "chunk_index": 0,
  "is_final": false,
  "timestamp_ms": 0
}
// Binary frame: PCM16 little-endian
```

#### 完成响应

```json
{
  "type": "done",
  "total_chunks": 42,
  "total_duration_ms": 5250
}
```

#### 错误响应

```json
{
  "type": "error",
  "code": "TEXT_TOO_LONG",
  "message": "Text exceeds maximum length of 8K tokens"
}
```

### 1.4 /voices 端点实现

```python
@app.get("/voices")
async def list_voices():
    return {
        "voices": [
            {
                "id": "zh_female_1",
                "name": "中文女声-温柔",
                "language": "zh",
                "gender": "female",
            },
            {
                "id": "zh_male_1",
                "name": "中文男声-稳重",
                "language": "zh",
                "gender": "male",
            },
            {
                "id": "en_female_1",
                "name": "English Female",
                "language": "en",
                "gender": "female",
            },
            {
                "id": "en_male_1",
                "name": "English Male",
                "language": "en",
                "gender": "male",
            },
            {
                "id": "mixed_1",
                "name": "中英混合",
                "language": "mixed",
                "gender": "neutral",
            },
        ],
        "default": "zh_female_1"
    }
```

### 1.5 首音频延迟优化 (TTFP < 500ms)

#### 延迟构成分析

```
TTFP = T_network + T_prefill + T_first_chunk + T_decode
     = 20ms    + 100ms    + 50ms        + 30ms
     ≈ 200ms (理想情况)
```

#### 优化策略

1. **网络层优化**
   - WebSocket 保持连接（预热）
   - 禁用 Nagle 算法 (`TCP_NODELAY`)
   - 使用 WSS 加密减少握手时间

2. **Prefill 优化**
   - 启用 FlashAttention-2
   - bf16 推理精度
   - `enforce_eager=True` 避免 CUDA graph 开销

3. **首 chunk 优化**
   - 使用 Voice Prompt 预加载
   - 减少 diffusion steps (5 → 3，音质轻微下降)
   - 降低 chunk duration (100ms → 50ms)

4. **客户端优化**
   - 预建立 WebSocket 连接
   - 收到 metadata 后立即准备播放器
   - 边收边播（收到第一个 chunk 就开始播放）

---

## 2. 显存与性能分析

### 2.1 RTX 4060 8GB VRAM 分配

#### 分开部署架构分析

| 模型 | 精度 | VRAM 占用 | 说明 |
|------|------|-----------|------|
| VibeVoice-ASR 7B | INT4 AWQ | ~4GB | Phase 1 已量化 |
| VibeVoice-Realtime 0.5B | FP16/BF16 | ~1GB | 模型权重 |
| KV Cache (ASR) | - | ~1.5GB | 8K context |
| KV Cache (TTS) | - | ~0.5GB | 8K context |
| 中间激活值 | - | ~1GB | 计算开销 |
| **总计** | - | **~8GB** | 刚好占满 |

#### 风险评估

⚠️ **高风险**: RTX 4060 8GB VRAM 刚好够用，但无冗余空间。

**缓解措施:**
1. 降低 `gpu_memory_utilization` 从 0.9 → 0.7
2. ASR 和 TTS 不同时加载（按需加载）
3. 使用 INT4 量化 TTS 模型（若支持）
4. 减少 KV cache 最大长度

### 2.2 vLLM 多模型实例管理

#### 方案: 按需加载

```python
# cloud_server/app/model_manager.py
class ModelManager:
    def __init__(self):
        self.models: Dict[str, LLM] = {}
        self.model_vram: Dict[str, float] = {}

    async def get_model(self, model_type: str) -> LLM:
        """按类型获取模型实例"""
        if model_type not in self.models:
            if model_type == "asr":
                await self._load_asr()
            elif model_type == "tts":
                await self._load_tts()
        return self.models[model_type]

    async def _load_tts(self):
        """加载 TTS 模型"""
        # 卸载 ASR（如果已加载）
        if "asr" in self.models:
            del self.models["asr"]
            torch.cuda.empty_cache()

        # 加载 TTS
        self.models["tts"] = LLM(
            model="microsoft/VibeVoice-Realtime-0.5B",
            trust_remote_code=True,
            gpu_memory_utilization=0.5,  # 预留空间
        )
```

#### 备选方案: 进程分离

```
┌─────────────────────────────────────────────────┐
│              nginx (端口 8000)                    │
├────────────────────┬────────────────────────────┤
│   FastAPI (ASR)   │    FastAPI (TTS)          │
│   Port 8001       │    Port 8002               │
├────────────────────┴────────────────────────────┤
│           vLLM Engine (共享 GPU)                  │
│   ASR Model      │       TTS Model            │
└─────────────────────────────────────────────────┘
```

**优点**: 独立进程，崩溃不影响另一方
**缺点**: 显存占用翻倍

### 2.3 流式输出显存峰值分析

#### 单请求峰值估算

```
Peak VRAM = Model Weights + KV Cache + Activation
          = 1GB        + 0.5GB    + 0.3GB
          = 1.8GB
```

#### 连续请求峰值估算

```
Peak VRAM = Model Weights + N × KV Cache + Activation
          = 1GB        + 3 × 0.5GB  + 0.3GB
          = 2.8GB
```

**结论**: 单请求流式推理显存需求可控 (约 2GB)。

---

## 3. Flutter TTS 客户端

### 3.1 flutter_soloud 流式播放配置

#### 初始化配置

```dart
// lib/services/audio/tts_audio_player.dart
import 'package:flutter_soloud/flutter_soloud.dart';

class TTSAudioPlayer {
  SoLoud? _soloud;
  BufferStream? _currentStream;
  bool _isPlaying = false;
  bool _isPaused = false;

  /// 初始化音频引擎（低延迟配置）
  Future<void> init() async {
    _soloud = SoLoud.instance;

    await _soloud!.init(
      bufferSize: 512,           // 低延迟缓冲
      sampleRate: 24000,        // 匹配 TTS 输出
      channels: Channels.mono,  // 单声道
    );
  }

  /// 创建流式音频流
  Future<BufferStream> createStream() async {
    return _soloud!.setBufferStream(
      maxBufferSizeBytes: 1024 * 1024 * 10,  // 10MB
      bufferingTimeNeeds: 0.2,               // 200ms 缓冲后开始播放
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,               // PCM16 little-endian
      bufferingType: BufferingType.released,  // 手动控制暂停
    );
  }
}
```

#### 边收边播实现

```dart
/// 处理收到的音频 chunk
void onAudioChunkReceived(Uint8List pcmData, int chunkIndex) {
  if (_currentStream == null) {
    return;
  }

  // 添加音频数据到流
  _soloud!.addAudioDataStream(_currentStream!, pcmData);

  // 第一次收到数据时开始播放
  if (!_isPlaying) {
    _startPlayback();
  }
}

/// 开始播放
Future<void> _startPlayback() async {
  if (_currentStream == null) return;

  _handle = await _soloud!.play(_currentStream!);
  _isPlaying = true;
  _isPaused = false;
}
```

### 3.2 Buffer 管理策略

#### 缓冲策略

| 场景 | bufferingTimeNeeds | 说明 |
|------|-------------------|------|
| 短文本 (<5s) | 0.1s (100ms) | 追求最低延迟 |
| 中文本 (5-30s) | 0.3s (300ms) | 平衡延迟和稳定性 |
| 长文本 (>30s) | 0.5s (500ms) | 防止卡顿 |

#### 暂停时 Buffer 保留

```dart
class TTSPlayerState {
  Uint8List _buffer = Uint8List(0);
  int _receivedChunks = 0;

  /// 添加 chunk 到 buffer（暂停时也保留）
  void addToBuffer(Uint8List chunk) {
    final newBuffer = Uint8List(_buffer.length + chunk.length);
    newBuffer.setRange(0, _buffer.length, _buffer);
    newBuffer.setRange(_buffer.length, newBuffer.length, chunk);
    _buffer = newBuffer;
    _receivedChunks++;
  }

  /// 恢复播放时使用 buffer 内容
  Future<void> resumeFromBuffer() async {
    if (_buffer.isEmpty) return;

    // 创建新流并填充 buffer
    final stream = await createStream();
    _soloud!.addAudioDataStream(stream, _buffer);

    // 从头开始播放
    _handle = await _soloud!.play(stream);
    _currentStream = stream;
    _isPlaying = true;
  }
}
```

### 3.3 播放控制与 WebSocket 生命周期

#### 状态机

```
                    ┌─────────────┐
                    │   Idle      │
                    └──────┬──────┘
                           │ play()
                           ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Error     │────▶│  Loading    │────▶│  Playing    │
│             │     │  (buffering)│     │             │
└─────────────┘     └──────┬──────┘     └──────┬──────┘
       ▲                   │                   │
       │                   │ pause()          │ pause()
       │                   ▼                   ▼
       │             ┌─────────────┐     ┌─────────────┐
       └────────────│   Paused    │◀────│   Stopped   │
                     │  (buffered) │     │             │
                     └──────┬──────┘     └─────────────┘
                            │ play()           ▲
                            ▼                   │
                      ┌─────────────┐    stop() │
                      │  Playing    │────────────┘
                      │  (resumed) │
                      └─────────────┘
```

#### WebSocket 连接管理

```dart
class TTSWebSocketManager {
  WebSocket? _socket;
  TTSAudioPlayer _player;

  /// 播放请求
  Future<void> play(String text, String voiceId) async {
    // 1. 建立 WebSocket 连接
    _socket = await WebSocket.connect('wss://$server/v1/tts/stream');

    // 2. 发送开始请求
    _socket.add(JSON.encode({
      'type': 'start',
      'text': text,
      'voice_id': voiceId,
    }));

    // 3. 监听响应
    _socket.listen(_onMessage);

    // 4. 创建音频流
    await _player.init();
    _player.createStream();
  }

  /// 暂停：保持连接和 buffer
  void pause() {
    _player.pause();
    // WebSocket 连接保持
  }

  /// 恢复播放
  void resume() {
    _player.resume();
  }

  /// 停止：立即断开连接
  void stop() {
    _player.stop();
    _socket?.close();  // 立即关闭
    _socket = null;
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      final data = JSON.decode(message);
      switch (data['type']) {
        case 'metadata':
          // 记录元数据
          break;
        case 'audio_chunk':
          // 添加到播放 buffer
          _player.addToBuffer(message as Uint8List);
          break;
        case 'done':
          _player.setDataIsEnded();
          break;
        case 'error':
          _handleError(data);
          break;
      }
    }
  }
}
```

### 3.4 进度条计算逻辑

```dart
class TTSPlaybackState {
  int _estimatedChunks = 0;
  int _receivedChunks = 0;
  int _playedChunks = 0;
  DateTime? _startTime;

  /// 更新进度
  double get progress {
    if (_estimatedChunks == 0) return 0.0;
    return _playedChunks / _estimatedChunks;
  }

  /// 时长显示
  String get durationDisplay {
    if (_estimatedChunks == 0) return '--:--';

    final totalMs = (_estimatedChunks * 50);  // 每 chunk 50ms
    final currentMs = (_playedChunks * 50);

    final totalSec = (totalMs / 1000).round();
    final currentSec = (currentMs / 1000).round();

    return '${currentSec ~/ 60}:${(currentSec % 60).toString().padLeft(2, '0')}'
           ' / '
           '${totalSec ~/ 60}:${(totalSec % 60).toString().padLeft(2, '0')}';
  }

  /// 在 chunk 收到时更新
  void onChunkReceived(int chunkIndex) {
    _receivedChunks = chunkIndex + 1;

    if (_startTime == null && chunkIndex == 0) {
      _startTime = DateTime.now();
    }
  }

  /// 在 chunk 播放时更新
  void onChunkPlayed(int chunkIndex) {
    _playedChunks = chunkIndex + 1;
  }
}
```

---

## 4. 协议兼容性

### 4.1 ASR vs TTS 协议对比

| 方面 | ASR | TTS | 兼容性 |
|------|-----|-----|--------|
| 端点 | `/v1/asr/stream` | `/v1/tts/stream` | 不同端点 |
| 握手 | JSON (start) | JSON (start) | ✅ 一致 |
| 数据方向 | Client → Server | Client → Server | 反向 |
| 响应格式 | JSON transcription | Binary PCM | 不同 |
| 元数据 | 可选 | 必须 (sample_rate) | 需适配 |
| 完成信号 | `done` | `done` | ✅ 一致 |
| 错误格式 | JSON | JSON | ✅ 一致 |

### 4.2 统一客户端设计

```dart
// lib/data/datasources/remote/websocket_client.dart
abstract class StreamingWebSocketClient {
  Future<void> connect();
  void send(Map<String, dynamic> data);
  void sendBinary(Uint8List data);
  Stream<WebSocketMessage> get messageStream;
  Future<void> close();
}

class WebSocketMessage {
  final WebSocketMessageType type;
  final Map<String, dynamic>? json;
  final Uint8List? binary;

  factory WebSocketMessage.json(Map<String, dynamic> data) => ...
  factory WebSocketMessage.binary(Uint8List data) => ...
}

// ASR 和 TTS 复用相同客户端
class ASRWebSocketClient extends StreamingWebSocketClient { ... }
class TTSWebSocketClient extends StreamingWebSocketClient { ... }
```

---

## 5. 验证架构

<validation_architecture>

### 5.1 TTFP < 500ms 验证

#### 自动化测试

```python
# tests/performance/test_tts_latency.py
import pytest
import asyncio
import time
import websockets

@pytest.mark.asyncio
async def test_ttfp_under_500ms():
    """测试首音频 chunk 延迟 < 500ms"""
    async with websockets.connect('ws://localhost:8000/v1/tts/stream') as ws:
        # 等待元数据
        metadata = await ws.recv()
        start_time = time.time()

        # 发送请求
        await ws.send(json.dumps({
            'type': 'start',
            'text': '你好，这是一段测试文本',
            'voice_id': 'zh_female_1',
        }))

        # 等待第一个音频 chunk
        first_chunk = await ws.recv()
        ttfp = (time.time() - start_time) * 1000

        assert ttfp < 500, f"TTFP {ttfp:.2f}ms exceeds 500ms limit"
        print(f"TTFP: {ttfp:.2f}ms")

@pytest.mark.asyncio
async def test_ttfp_p95():
    """测试 P95 TTFP（连续 100 次）"""
    ttfp_values = []
    for _ in range(100):
        ttfp = await measure_single_ttfp()
        ttfp_values.append(ttfp)

    p95 = sorted(ttfp_values)[94]
    assert p95 < 600, f"P95 TTFP {p95:.2f}ms exceeds 600ms"
```

#### 手动测试检查清单

- [ ] 使用 `curl` 测量单次请求 TTFP
- [ ] 使用 Wireshark 分析网络延迟
- [ ] 在不同网络条件下测试（WiFi/4G/限流）
- [ ] 记录 10 次测量的平均值和中位数

### 5.2 WebSocket 10 分钟稳定性验证

#### 自动化测试

```python
# tests/stability/test_websocket_stability.py
import pytest
import asyncio
import websockets
import random
import string

@pytest.mark.asyncio
@pytest.mark.slow
async def test_10_minute_continuous_stream():
    """测试连续 10 分钟不断线"""
    start_time = time.time()
    chunks_received = 0
    errors = []

    async with websockets.connect('ws://localhost:8000/v1/tts/stream') as ws:
        # 发送请求
        await ws.send(json.dumps({
            'type': 'start',
            'text': 'A' * 100,  # 短文本循环
            'voice_id': 'zh_female_1',
        }))

        end_time = start_time + 600  # 10 minutes

        while time.time() < end_time:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=5.0)
                if isinstance(msg, bytes):
                    chunks_received += 1
            except asyncio.TimeoutError:
                # 超时，可能是连接断开
                pass
            except Exception as e:
                errors.append(str(e))

    # 验证
    assert len(errors) == 0, f"Errors occurred: {errors}"
    assert chunks_received > 1000, "Too few chunks received"
    print(f"Received {chunks_received} chunks in 10 minutes")
```

#### 手动测试检查清单

- [ ] 启动测试脚本，监控终端输出
- [ ] 使用 `netstat` 监控连接状态
- [ ] 在第 5 分钟时模拟网络抖动
- [ ] 检查服务器内存/CPU 是否有泄漏

### 5.3 播放控制验证

#### 自动化测试

```python
# tests/ui/test_playback_controls.py
import pytest
from appium import webdriver
from appium.webdriver.common.appiumby import AppiumBy

@pytest.mark.mobile
class TestTTSPlaybackControls:

    @pytest.fixture(autouse=True)
    def setup(self, driver):
        self.driver = driver
        self.driver.find_element(AppiumBy.TEXT, "TTS")

    def test_play_button_starts_playback(self):
        """播放按钮开始播放"""
        # 输入文本
        text_input = self.driver.find_element(AppiumBy.ID, "text_input")
        text_input.send_keys("测试文本")

        # 点击播放
        play_btn = self.driver.find_element(AppiumBy.ID, "play_button")
        play_btn.click()

        # 验证播放状态
        time.sleep(1)
        assert self._is_playing(), "Playback should have started"

    def test_pause_preserves_buffer(self):
        """暂停保留已接收音频"""
        # 开始播放
        self._start_playback("A" * 1000)
        time.sleep(0.5)  # 等待一些数据

        # 暂停
        pause_btn = self.driver.find_element(AppiumBy.ID, "pause_button")
        pause_btn.click()

        # 继续播放
        pause_btn.click()
        time.sleep(0.5)

        # 应该无缝衔接
        assert self._get_played_position() > 0

    def test_stop_disconnects_websocket(self):
        """停止断开 WebSocket"""
        # 开始播放
        self._start_playback("A" * 1000)
        time.sleep(0.5)

        # 停止
        stop_btn = self.driver.find_element(AppiumBy.ID, "stop_button")
        stop_btn.click()

        # WebSocket 应该已关闭（通过日志验证）
        assert self._websocket_closed(), "WebSocket should be closed"
```

#### 手动测试检查清单

- [ ] 播放过程中点击暂停，检查进度条停在当前位置
- [ ] 暂停 10 秒后恢复，验证音频无缝衔接
- [ ] 点击停止，检查播放立即停止
- [ ] 验证错误状态 UI 显示（网络断开时）

### 5.4 自动化测试策略

#### 测试分类

| 测试类型 | 运行频率 | 工具 |
|---------|---------|------|
| 单元测试 | 每次 PR | pytest |
| 集成测试 | 每次 PR | pytest + Docker |
| 性能测试 | 每日 | locust |
| E2E 测试 | 每周 | Appium |
| 压力测试 | 每月 | k6 |

#### CI/CD 集成

```yaml
# .github/workflows/tts-tests.yml
name: TTS Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests
        run: pytest tests/unit/ -v

  integration-tests:
    runs-on: ubuntu-latest
    services:
      tts-server:
        image: vibevoice/server:latest
        ports:
          - 8000:8000
    steps:
      - name: Run integration tests
        run: pytest tests/integration/ -v

  mobile-e2e:
    runs-on: macos-latest
    steps:
      - name: Run Appium tests
        run: |
          flutter test integration_test/
```

### 5.5 手动测试检查清单

#### REQ-06 (云端 TTS 流式播放)

- [ ] 打开 TTS Tab
- [ ] 输入文本 "你好，世界"
- [ ] 选择中文女声音色
- [ ] 点击播放按钮
- [ ] 确认听到语音输出
- [ ] 验证音频质量和流畅度

#### REQ-07 (首音频 chunk 延迟 < 500ms)

- [ ] 使用秒表测量点击播放到听到声音的时间
- [ ] 重复 5 次，记录平均值
- [ ] 在不同网络条件下测试（WiFi/4G）

#### REQ-11 (音色选择器 UI)

- [ ] 点击音色选择器下拉框
- [ ] 验证显示 5 个预设音色
- [ ] 选择不同音色后播放
- [ ] 验证音色切换生效（听感差异）

#### 边界情况

- [ ] 空文本提交（应显示错误）
- [ ] 超长文本（应限制或分段）
- [ ] 网络断开时播放（应显示错误并重连）
- [ ] 快速暂停/恢复（应无音频断裂）
- [ ] 快速切换 Tab（ASR ↔ TTS）

</validation_architecture>

---

## 6. 风险与未知项

### 6.1 高风险项

| 风险 | 影响 | 概率 | 缓解 |
|------|------|------|------|
| VibeVoice-Realtime 不兼容 vLLM | 高 | 中 | 先测试验证，备选自定义 FastAPI |
| RTX 4060 显存不足 | 高 | 高 | 分开加载模型，降低 utilization |
| 中文 TTS 质量不佳 | 中 | 高 | 使用 Qwen3-TTS 代替 |

### 6.2 未知项

| 问题 | 需要验证 |
|------|---------|
| VibeVoice-Realtime 能否被 vLLM 加载 | 需要测试 |
| TTS 模型是否支持 INT4 量化 | 需要测试 |
| VibeVoice 中文支持程度 | 需要测试 |
| 流式输出是否稳定 | 需要测试 |

### 6.3 建议的下一步

1. **立即验证**: 在 RTX 4060 上测试 vLLM 加载 VibeVoice-Realtime-0.5B
2. **备选方案**: 准备 FastAPI 自定义封装代码
3. **显存测试**: 测试 ASR + TTS 同时加载的显存占用
4. **中文测试**: 验证 VibeVoice 中文 TTS 质量是否可接受

---

## 7. 参考资料

- [VibeVoice-Realtime-0.5B HuggingFace](https://huggingface.co/microsoft/VibeVoice-Realtime-0.5B)
- [vLLM Streaming Realtime API](https://blog.vllm.ai/2026/01/31/streaming-realtime.html)
- [vLLM-Omni Speech API](https://docs.vllm.ai/projects/vllm-omni/en/latest/serving/speech_api/)
- [flutter_soloud Streaming](https://docs.page/alnitak/flutter_soloud_docs/advanced/streaming)
- [Voxtral TTS (竞争方案)](https://mistral.ai/news/voxtral-tts)

---

*Research completed: 2026-04-10*
*Next: Proceed to /gsd-plan-phase for detailed planning*
