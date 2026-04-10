# Phase 1: Cloud ASR Pipeline - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

2 周内完成 MVP：Flutter Standalone App（语音输入法）+ 云端 VibeVoice-ASR (7B) 推理服务跑在 RTX 4060 Windows Server 上。

用户流程：打开 App → 长按麦克风按钮说话 → 实时流式语音传输到云端 → 实时返回转写文字 → 文字显示在输入框 → 点击复制使用。

**产品类型**：独立 App（MVP），非输入法 IME。Phase 2 再做 Android IME / iOS Keyboard Extension 集成。

**Scope**：Flutter App（MVP）+ 云端 ASR 推理服务（FastAPI + vLLM）+ WebSocket 协议
**Out of scope**：Android IME、iOS Keyboard Extension、声控 VAD、自动语言检测、端侧推理、离线模式
</domain>

<decisions>
## Implementation Decisions

### 网络协议
- **D-01:** 使用 WebSocket 实时流式传输（而非 REST 批量上传）。说完即出字，追求"边说边出字"的流畅体验。
- **D-02:** WebSocket 协议：客户端发送 `start`（音频 metadata）+ 实时 PCM chunks，服务器流式返回 JSON 转写结果 chunks。参照 SPEC.md 1.2 节协议格式。

### 云端推理架构
- **D-03:** 推理引擎：vLLM Serving（Continuous Batching + CUDA 优化）。非 HuggingFace Transformers 直接推理。
- **D-04:** 模型量化：VibeVoice-ASR 7B 需要 INT4 AWQ 量化（~14GB FP16 → ~4GB INT4）才能在 RTX 4060 8GB VRAM 单卡上运行。Phase 1 前需完成量化步骤。
- **D-05:** 模型量化工具：autoawq，`w_bit: 4`，`q_group_size: 128`。
- **D-06:** CUDA 版本：CUDA 12+，FlashAttention-2，bf16 推理。
- **D-07:** 服务器部署：WSL2 + Docker Desktop on Windows Server，GPU passthrough 到 WSL2。参照 SPEC.md 1.5 节 Docker Compose 配置。
- **D-08:** FastAPI WebSocket 端点：`/v1/asr/stream`，健康检查：`/health`。

### Flutter App 架构
- **D-09:** 麦克风录音库：`record`。API 支持流式读取 PCM chunks，适合 WebSocket 实时上传。
- **D-10:** 音频参数：16kHz 或 24kHz 采样率（对齐 VibeVoice-ASR 输入要求），mono，16-bit PCM。
- **D-11:** 音频 chunk 大小：50ms chunks（~800-1200 bytes per chunk at 16kHz）。
- **D-12:** Flutter 状态管理：Riverpod（或 BLoC，参照 SPEC.md 1.3 节模块设计）。
- **D-13:** Flutter 音频播放：无（Phase 1 MVP 纯 ASR，不需要播放）。Phase 2 TTS 才需要 flutter_soloud。

### 交互模式
- **D-14:** 录音触发：长按说话（Push-to-Talk）。按住麦克风按钮开始录音，松开结束并发送。
- **D-15:** 语言选择：手动切换按钮（中文普通话 / English）。Phase 1 先做中文普通话 ASR，英文 ASR 后续加。
- **D-16:** 文字输出：App 内文本框显示 ASR 结果 + 一键复制到剪贴板按钮。
- **D-17:** 不做 VAD（Voice Activity Detection）。Phase 1 用手动长按结束，不做声控自动开始/结束。

### 错误处理与可靠性
- **D-18:** WebSocket 断线重连：指数退避策略（Base delay 1s，Max delay 30s，Max retries 5）。参照 SPEC.md 1.4.3 节实现。
- **D-19:** 网络状态 UI：麦克风权限申请中 / 录音中 / 发送中 / 等待结果 / 错误 / 断线重连 — 每种状态有明确 UI 反馈。
- **D-20:** 错误提示：网络断开、麦克风权限拒绝、服务器错误各有独立 UI 提示文案。

### Claude's Discretion
以下由 Claude（规划阶段）决定具体实现：
- Flutter App 的 UI 配色和视觉风格（未在 Phase 1 讨论中涉及）
- 具体音色/Voice preset 选择器的 UI 设计（Phase 2 TTS 相关）
- vLLM 的并发连接数上限配置
- ASR 转写结果的分句策略（实时返回 tokens vs 完整句子）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 协议与架构
- `raw/SPEC.md` §1.1-1.6 — Phase 1 (云端 API) 架构图、WebSocket 协议格式、Flutter 模块设计、关键技术实现细节、Docker 部署配置
- `raw/SPEC.md` §0.1-0.4 — VibeVoice 模型家族、核心技术创新、最终目标、关键约束
- `.planning/ROADMAP.md` — Phase 1 目标、验收标准
- `.planning/REQUIREMENTS.md` — REQ-01 到 REQ-05（Phase 1 必须项）

### 推理框架参考
- `raw/SPEC.md` §2.2 — vLLM 作为云端推理引擎的选型理由
- `raw/SPEC.md` §1.4.3 — WebSocket 断线重连策略代码参考
- `raw/SPEC.md` §1.5.1 — Docker Compose 配置参考

### Flutter 音频参考
- `raw/SPEC.md` §1.4.1 — VoiceRecorder 录音代码参考（flutter_voice_engine / AudioRecord）
- `raw/SPEC.md` §1.4.3 — WebSocketService 断线重连完整代码参考

### 量化参考（Phase 1 前置步骤）
- `raw/SPEC.md` §2.3.1-2.3.2 — INT4 AWQ 量化方案对比与量化流程

### 模型文档
- HuggingFace: `microsoft/VibeVoice-ASR` — 7B 模型输入输出格式、voice prompt 要求
- HuggingFace: `microsoft/VibeVoice-Realtime-0.5B` — TTS 模型（Phase 2 用，同一服务器部署）
- vLLM 官方文档 — Streaming API、Continuous Batching 配置

### RTX 4060 约束
- 8GB VRAM 上限：7B FP16 (~14GB) 不可直接运行，必须 INT4 量化
- CUDA 12+ 要求：FlashAttention-2 依赖
- 同一台服务器 Phase 1 跑 ASR，Phase 2 叠加 TTS，需注意显存分配

[If no external specs: "Requirements fully captured in decisions above"]
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **None** — greenfield project, no existing Flutter/Dart code
- SPEC.md 包含参考代码 scaffold（VoiceRecorder、VoicePlayer、WebSocketService），可作为起步参考直接 copy-paste 后改写

### Established Patterns
- Flutter 音频：flutter_record 流式 API 模式（参照 SPEC.md 1.4.1）
- WebSocket：JSON 握手 + binary chunks 模式（参照 SPEC.md 1.2 协议格式）
- 重连：指数退避模式（参照 SPEC.md 1.4.3）

### Integration Points
- Flutter App → WebSocket → FastAPI 云端服务（端口 8000）
- FastAPI → vLLM（本地 CUDA 推理）
- Docker Compose：nginx 反向代理 + FastAPI + vLLM service（参照 SPEC.md 1.5.1）
- HuggingFace cache volume mount：`~/.cache/huggingface` 挂载到容器内

### Creative Options
- RTX 4060 8GB VRAM 可同时跑 ASR (INT4) + TTS (0.5B INT4)，需 vLLM 多模型配置
- WSL2 GPU passthrough 需要 `nvidia-smi` 在 WSL2 内可见，安装顺序重要（Windows CUDA driver 先装）
</code_context>

<specifics>
## Specific Ideas

- 用户长按说话时，按钮有明显的视觉反馈（录音中状态 + 波形动画）
- 文字出现时有打字机效果（逐字显示），让用户感知"正在实时转写"
- App 内置一个历史记录列表（本次会话的转写历史），方便用户选择复制

[If none: "No specific requirements — open to standard approaches"]
</specifics>

<deferred>
## Deferred Ideas

### 功能扩展（不属于 Phase 1）
- **Android IME / iOS Keyboard Extension** — Phase 2 再做，真正的输入法集成
- **声控 VAD（Voice Activity Detection）** — Phase 2 或更后期，自动检测说话开始/结束
- **自动语言检测** — Phase 2 或更后期，实时检测音频语言自动切换 ASR 参数
- **英文 ASR 支持** — Phase 2 再加，Phase 1 专注中文普通话
- **flutter_soloud 音频播放** — Phase 2 TTS 才需要
- **离线 ASR 模式** — Phase 3（端侧推理）
- **端侧 TTS** — Phase 4

### 技术债务
- **Flutter 状态管理选型** — Riverpod vs BLoC 未最终确定，规划阶段决定
- **ASR 分句策略** — 实时返回 tokens vs 完整句子，规划阶段决定

None — discussion stayed within phase scope
</deferred>

---

*Phase: 01-cloud-asr-pipeline*
*Context gathered: 2026-04-02*
