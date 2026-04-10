# Phase 2: Cloud TTS Foundation - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

在 Phase 1 云端 ASR 基础设施上叠加云端 TTS（Text-to-Speech）能力。

**Scope：** VibeVoice-Realtime 0.5B 部署到 RTX 4060 服务器 + Flutter App TTS UI（文本输入 → 音色选择 → 播放语音）。

**用户流程：** 打开 App → 切换到 TTS Tab → 输入文本 → 选择音色 → 点击播放 → 实时收到流式音频并播放。

**Out of scope：** 自定义 Voice Prompt、录音功能、TTS 历史记录、语音变声、离线 TTS
</domain>

<decisions>
## Implementation Decisions

### 交互模式
- **D-01:** 独立 TTS Tab — App 底部导航有 ASR Tab（麦克风）和 TTS Tab（文本输入），两屏职责清晰，用户通过 Tab 切换。
- **D-02:** TTS Tab UI 布局：顶部文本输入框 + 音色选择器 + 播放控制区（播放/暂停/停止/进度条）。

### 音色策略
- **D-03:** 预设音色列表 — 不做自定义 Voice Prompt，Phase 2 先做预设音色快速验证。
- **D-04:** 预设 5 个音色：2 中文 + 2 英文 + 1 中英混合。通过服务器 `/voices` 端点获取音色列表。

### 流式播放策略
- **D-05:** 边收边播 — 收到第一个 PCM chunk 就立即开始播放，追求最低延迟（目标 < 500ms TTFP）。
- **D-06:** 完整播放控制：播放/暂停 + 停止 + 进度条 + 时长显示。进度条基于服务器 start 时提供的 estimated_chunks 和当前已接收 chunks 计算。
- **D-07:** 暂停时保留已接收音频 buffer，恢复时从断点继续（而非重新请求）。
- **D-08:** 停止时立即中断 WebSocket 连接。

### 显存与部署架构
- **D-09:** 分开部署架构 — ASR 和 TTS 模型各自独立，按需加载，显存互不干扰。
- **D-10:** FastAPI 同一进程管理两个 vLLM 模型实例（ASR + TTS），通过路由区分 `/v1/asr/stream` vs `/v1/tts/stream`，共享显存管理。
- **D-11:** 端口统一：对外一个端口（8000），FastAPI 内部路由分发。

### 继承自 Phase 1 的决策（直接复用）
- WebSocket 协议模式（JSON 握手 + binary chunks）
- Flutter 状态管理：Riverpod
- Repository 层架构
- `flutter_soloud` 用于低延迟音频播放
- 指数退避断线重连策略
- 错误状态 UI 反馈模式

### Claude's Discretion
以下由 Claude（规划阶段）决定具体实现：
- TTS Tab 的具体 UI 配色和视觉风格（对齐 Phase 1 ASR Tab）
- 5 个预设音色的具体名称/ID
- 进度条的具体 UI 样式（滑块 vs 进度条）
- 音频 chunk 缓冲策略（buffer size 设置）
- 错误状态文案和 UI 反馈样式
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 上下文
- `.planning/phases/01-cloud-asr-pipeline/01-CONTEXT.md` — Phase 1 决策（WebSocket 协议、Flutter Riverpod、Repository 层、flutter_soloud）
- `.planning/ROADMAP.md` — Phase 2 目标、验收标准（REQ-06、REQ-07、REQ-11）
- `.planning/REQUIREMENTS.md` — REQ-06、REQ-07、REQ-11

### 协议与架构参考
- `raw/SPEC.md` §1.1-1.6 — Flutter 目录结构（tts_bloc、voice_player_widget、text_input_panel、voice_selector）
- `raw/SPEC.md` §1.4.2 — flutter_soloud 低延迟播放参考代码
- `raw/SPEC.md` §1.4.3 — WebSocket 断线重连策略参考（可复用给 TTS）
- `raw/SPEC.md` §1.5.1 — Docker Compose 配置参考（扩展支持双模型）
- `raw/SPEC.md` §2.2 — vLLM Streaming Realtime API 参考

### TTS 协议参考
- `raw/SPEC.md` — TTS WebSocket 协议格式（/v1/tts/stream），JSON handshake + PCM binary chunks
- `raw/SPEC.md` — /voices 端点返回音色列表格式
- `raw/SPEC.md` — StreamingTTSService 代码框架参考

### 模型文档
- HuggingFace: `microsoft/VibeVoice-Realtime-0.5B` — TTS 模型，Phase 2 部署到 RTX 4060

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 1 已实现的 WebSocket 客户端封装 — 可作为 TTS WebSocket 客户端的参考
- Phase 1 已实现的 Repository 层 — TTS 复用相同模式（TTSRepository + TTSApiClient）
- Phase 1 已实现的 Flutter bloc 架构 — TTSBloc 复用相同模式
- Phase 1 已实现的指数退避重连 — TTS WebSocket 复用相同策略

### Established Patterns
- Flutter: Riverpod 状态管理（Phase 1 决策）
- WebSocket: JSON 握手 + binary chunks（Phase 1 决策）
- 音频: 16kHz, PCM16, mono（Phase 1 决策）
- UI: 明确状态反馈（录音中/播放中/错误等）

### Integration Points
- Flutter TTS Tab → WebSocket → FastAPI `/v1/tts/stream` → TTS vLLM 模型
- FastAPI 与 ASR 服务共用同一进程，通过路由分发
- Flutter ASR Tab 和 TTS Tab 共用底部导航（`flutter_bloc` 或 `go_router` 管理 Tab 切换）

### Creative Options
- RTX 4060 8GB VRAM：分开加载 ASR (INT4 ~4GB) + TTS (0.5B bf16 ~1GB)，共 ~5GB，留 3GB 给中间结果
- TTS Tab 可以复用 Phase 1 的 error snackbar 组件展示 WebSocket 错误
</code_context>

<specifics>
## Specific Ideas

- TTS Tab 的视觉风格和 Phase 1 ASR Tab 保持一致（同一设计语言）
- 音色选择器使用下拉菜单或网格卡片形式，清晰展示音色名称

[If none: "No specific requirements — open to standard approaches"]
</specifics>

<deferred>
## Deferred Ideas

### 属于其他阶段的功能
- **自定义 Voice Prompt** — Phase 4 端侧 TTS 或更后期，用户上传参考音频作为音色
- **语音变声** — Phase 3+ 后续功能
- **TTS 历史记录** — 后续迭代
- **语音输入文本（语音合成对话）** — Phase 3+ 全双工对话

None — discussion stayed within phase scope
</deferred>

---

*Phase: 02-cloud-tts-foundation*
*Context gathered: 2026-04-10*
