# Phase 2: Cloud TTS Foundation - Research (Updated)

**Status:** Research Updated (2026-04-17)
**Date:** 2026-04-17

---

## Executive Summary

经过深入调研市面上最新的流式 TTS 模型/方案，结合我们 RTX 4060 8GB GPU + Windows Server 的实际环境，**推荐方案**：

### 方案 A（推荐）：基于现有 Qwen3-TTS 0.6B 模型，新增 vLLM-Omni 流式服务（新端口）

**优势**：
- Qwen3-TTS 已部署在服务器上（9880 端口）
- vLLM-Omni 原生支持 Qwen3-TTS 流式输出（WebSocket + HTTP streaming）
- TTFP ~131ms（H100），RTX 4060 预计 ~300-500ms
- 中英文双语支持（中文+英文+10种其他语言）
- 9 个预设音色（Serena, Vivian, Ryan, Aiden 等）
- VRAM 占用 ~2.6-2.9GB（0.6B 模型）
- 同一台服务器，与 Phase 1 ASR 分开部署
- **无需修改现有 9880 端口**，新服务使用新端口

**劣势**：
- TTFP ~300-500ms（RTX 4060 vs H100 的 ~131ms）
- vLLM-Omni 需要 Linux 环境（WSL2 可行，但需额外安装）

### 方案 B（备选）：CosyVoice2-0.5B

**优势**：
- 真正的流式生成（非 batch then chunk）
- TTFP ~150ms
- 中英文双语 + 零样本音色克隆
- VRAM ~3-4GB（0.5B）

**劣势**：
- 需要下载新模型到服务器
- 部署复杂度更高

---

## 1. 候选模型全面调研

### 1.1 模型对比表

| 模型 | 参数量 | 流式支持 | TTFP | VRAM | 中文 | 英文 | License | 备注 |
|------|--------|----------|------|------|------|------|---------|------|
| **Qwen3-TTS + vLLM-Omni** | 0.6B / 1.7B | ✅ HTTP Streaming + WebSocket | ~131ms (H100) | ~2.9GB | ✅ | ✅ | Apache 2.0 | 已在服务器上 |
| VibeVoice-Realtime-0.5B | 0.5B | ✅ 流式输入 | ~300ms | ~1GB | ❌ 仅英文 | ✅ | MIT | 需研究 |
| CosyVoice2-0.5B | 0.5B | ✅ 流式生成 | ~150ms | ~3-4GB | ✅ | ✅ | BSD-3 | 需下载 |
| Mistral Voxtral TTS | 4B | ✅ 流式生成 | ~70ms | ~3GB | ❌ 无 | ✅ | CC BY-NC 4.0 | 商业不可用 |
| ChatTTS | ? | ✅ 流式生成 | ? | ? | ✅ | ✅ | BSD-4 | 质量一般 |
| Fish-Speech | ? | 部分 | ? | ? | ✅ | ✅ | ? | 需验证 |
| GPT-SoVITS | ? | ❌ | ? | ? | ✅ | ✅ | ? | 无流式 |

### 1.2 深度分析：Qwen3-TTS 流式能力

**关键发现：** Qwen3-TTS 的 `non_streaming_mode=False` 参数的实际含义：

官方文档明确说明：
> "Using non-streaming text input, this option currently only **simulates streaming text input** when set to `false`, rather than enabling true streaming input or streaming generation."

即：**`non_streaming_mode=False` 只是模拟流式文本输入，生成仍是批量完成所有 codec tokens 后再输出**。

**但是：** vLLM-Omni 的实现不同！

vLLM-Omni PR #1719 实现了真正的流式音频输出：
- WebSocket 端点 `/v1/audio/speech/stream`
- `stream_audio: true` 参数启用流式输出
- 每个句子输出为：`audio.start` + 多个 binary PCM chunks + `audio.done`
- 支持逐步解码（async_chunk 模式）

**vLLM-Omni 的 TTFP 数据（H200/H100）：
- 并发 1：Mean TTFP 131ms（Median: 126ms，P99: 179ms）
- 并发 4：Median TTFP 200ms

**vLLM-Omni WebSocket 协议（参考）：**

```json
// Client → Server
{"type": "session.config", "voice": "Vivian", "task_type": "CustomVoice", "language": "Auto", "split_granularity": "sentence", "stream_audio": true, "response_format": "pcm"}
{"type": "input.text", "text": "Hello, how are you? "}
{"type": "input.done"}

// Server → Client
{"type": "audio.start", "sentence_index": 0, "sentence_text": "Hello, how are you?", "format": "pcm", "sample_rate": 24000}
// binary PCM frame(s)
{"type": "audio.done", "sentence_index": 0, "total_bytes": 96000, "error": false}
{"type": "session.done", "total_sentences": 1}
```

### 1.3 深度分析：VibeVoice-Realtime-0.5B

**模型信息：**
- HuggingFace: `microsoft/VibeVoice-Realtime-0.5B`
- 架构：Qwen2.5-0.5B LLM + σ-VAE Acoustic Tokenizer (7.5Hz) + Diffusion Head
- 上下文：8K tokens，约 10 分钟音频
- 输出：24kHz，单声道

**关键限制：仅支持英文**（其他语言官方标注为 unsupported）。支持额外 9 种语言（德法意日韩荷波葡西），**中文不在列表中**。

**部署选项：**
1. vLLM-Omni 可能支持（需要测试）
2. Microsoft 官方推理代码（`example_inference.py`）

### 1.4 深度分析：CosyVoice2-0.5B

**模型信息：**
- HuggingFace: `FunAudioLLM/CosyVoice2-0.5B`
- 架构：Qwen2.5-0.5B LLM + FSQ Tokenizer (25Hz) + Flow Matching + HiFiGAN
- **支持中文 + 英文 + 日韩德法西意俄**（9 种语言）
- 零样本音色克隆（3 秒参考音频）
- 情绪标记支持

**流式能力：**
- 官方声称 TTFP ~150ms（支持流式生成）
- KV Cache + SDPA 优化
- chunk-aware causal flow matching

**VRAM：** 初步估算 3-4GB（0.5B 模型 + vocoder）

---

## 2. 性能基准对比

| 指标 | 目标 | Qwen3-TTS (batch, 当前) | Qwen3-TTS + vLLM-Omni | CosyVoice2 | VibeVoice-Realtime |
|------|------|--------------------|----------------------|-------------|---------------------|
| TTFP | < 500ms | ~7000ms | ~131-500ms | ~150ms | ~300ms |
| 流式协议 | WebSocket | ❌ HTTP batch | ✅ WebSocket | ✅ 流式 | ✅ 流式 |
| 中文支持 | 必须 | ✅ | ✅ | ✅ | ❌ 不支持 |
| 英文支持 | 必须 | ✅ | ✅ | ✅ | ✅ |
| VRAM | < 8GB | ~4GB | ~2.9GB | ~3-4GB | ~1GB |
| License | 可商用 | Qwen (Apache 2.0) | Qwen (Apache 2.0) | BSD-3 | MIT |
| 现有部署 | - | ✅ 9880 端口 | 需新增 | 需下载 | 需下载 |

---

## 3. 实现方案详解

### 方案 A：vLLM-Omni 流式服务（新端口，Qwen3-TTS）

**架构：**
```
Flutter App (Phase 2 TTS Tab)
    ↓ WebSocket / HTTP
Windows Server WSL2
    ├── 9880: Qwen3-TTS (batch, 现有业务保留)
    └── 9881: vLLM-Omni + Qwen3-TTS (流式, 新增)
            └── RTX 4060 GPU
```

**部署步骤：**

1. **WSL2 环境准备**
```bash
# 检查 CUDA 版本
nvidia-smi  # 应显示 RTX 4060

# 安装 vLLM-Omni（需要从源码构建）
git clone https://github.com/vllm-project/vllm-omni.git
cd vllm-omni
pip install -e .

# 或使用预编译 wheel
pip install vllm --torch-backend=auto
pip install vllm-omni
```

2. **启动流式服务（新端口 9881）**
```bash
vllm serve Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice \
    --omni \
    --port 9881 \
    --trust-remote-code \
    --enforce-eager
```

3. **FastAPI WebSocket 封装**（整合到现有 Phase 1 服务器）

由于 vLLM-Omni 已是完整服务，可以：
- **方案 1（推荐）：**直接让 Flutter 客户端连接 vLLM-Omni 的 WebSocket（`ws://server:9881/v1/audio/speech/stream`）
- **方案 2：**在 Phase 1 的 FastAPI 服务器中反向代理到 vLLM-Omni

**VRAM 评估：**
- Qwen3-TTS 0.6B CustomVoice: ~2.9GB
- Phase 1 ASR（若需共存）: ~4GB
- 合计：~6.9GB，留 ~1GB 给 KV cache（RTX 4060 8GB 总计）

**TTFP 预期：**
- H100/H200 上：~131ms
- RTX 4060（计算力约为 H100 的 40%）：预计 ~300-500ms
- 取决于并发数和模型大小

### 方案 B：CosyVoice2-0.5B

**部署步骤：**
```bash
# 下载模型
git lfs install
git clone FunAudioLLM/CosyVoice2-0.5B

# 启动服务
python api.py --port 9881 --stream
```

**优势：**
- 官方声称真正流式生成
- 零样本音色克隆
- 中文支持更好

**劣势：**
- 需要新模型（约 2-3GB）
- 需要验证流式 WebSocket 端点实现

---

## 4. 最终推荐

### 推荐：方案 A - vLLM-Omni + Qwen3-TTS（新端口 9881）

**理由：**
1. **已有模型**：Qwen3-TTS 已在服务器上
2. **中文支持**：Qwen3-TTS 支持中文 + 英文（Phase 2 核心需求）
3. **vLLM-Omni 流式**：PR #1719 已合并，真正支持流式音频输出
4. **不改现有端口**：新服务在 9881 端口，现有 9880 业务不受影响
5. **TTFP 可接受**：~300-500ms（RTX 4060），接近 500ms 目标
6. **License**：Apache 2.0，可商用

### 实施计划

**Phase 2-S（Server 新增）：**
1. 在 WSL2 中安装 vLLM-Omni
2. 启动 vLLM-Omni + Qwen3-TTS 流式服务（端口 9881）
3. 测试 TTFP 是否 < 500ms
4. 如 TTFP 不达标，考虑 CosyVoice2 备选方案

**待验证项：**
- [ ] vLLM-Omni 在 RTX 4060 上的 TTFP 实测值
- [ ] RTX 4060 8GB 是否足够（ASR + TTS 共存）
- [ ] vLLM-Omni 在 WSL2 中的安装兼容性

---

## 5. 风险与缓解

| 风险 | 影响 | 概率 | 缓解 |
|------|------|------|------|
| vLLM-Omni 在 WSL2 中安装失败 | 高 | 中 | 考虑 Docker 容器方式 |
| RTX 4060 TTFP 超 500ms | 中 | 中 | 接受 ~600-800ms 或切换 CosyVoice2 |
| VRAM 不足（ASR+TTS 共存） | 高 | 中 | ASR/TTS 分开加载（ModelManager） |
| Qwen3-TTS 中文质量不佳 | 中 | 低 | 先用现有 batch 版本测试音质 |
| 现有 Qwen3-TTS 0.6B 模型不兼容 vLLM-Omni | 高 | 低 | vLLM-Omni 官方支持 Qwen3-TTS |

---

## 6. 参考资料

- [vLLM-Omni Qwen3-TTS 文档](https://docs.vllm.ai/projects/vllm-omni/en/stable/user_guide/examples/online_serving/qwen3_tts/)
- [vLLM-Omni PR #1719 - 流式音频输出](https://github.com/vllm-project/vllm-omni/pull/1719)
- [Qwen3-TTS GitHub](https://github.com/QwenLM/Qwen3-TTS)
- [Qwen3-TTS 流式文档](https://qwenlm-qwen3-tts.mintlify.app/guides/streaming)
- [vLLM-Omni 安装指南](https://docs.vllm.ai/projects/vllm-omni/en/latest/getting_started/installation/)
- [CosyVoice2 GitHub](https://github.com/FunAudioLLM/CosyVoice)
- [VibeVoice-Realtime-0.5B HuggingFace](https://huggingface.co/microsoft/VibeVoice-Realtime-0.5B)

---

*Research updated: 2026-04-17*
*Next: Proceed to /gsd-plan-phase for Phase 2-S planning*
