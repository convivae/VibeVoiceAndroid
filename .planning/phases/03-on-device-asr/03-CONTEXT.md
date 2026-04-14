# Phase 3: On-Device ASR - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

将 VibeVoice-ASR 7B 量化为移动端可用大小（INT4，~400MB），打包进 APK，实现在线/离线语音识别。

**Scope：** 模型量化（RTX 4060 服务器）+ 端侧推理引擎（Flutter） + 混合路由（端侧优先，网络不可用时自动切云端）+ 模型下载管理

**用户流程：** 打开 App → 首次使用时下载模型 → 按住麦克风说话 → 离线实时转写 → 文字显示在输入框

**Out of scope：** 本地 VAD（Voice Activity Detection）、持续监听模式、输入法 IME 集成、自定义 Voice Prompt
</domain>

<decisions>
## Implementation Decisions

### 推理框架
- **D-01:** 推理框架：TensorFlow Lite（而非 MNN/llama.cpp/ExecuTorch）。选型理由：生态成熟，便于后续迁移到 Gemma4。

### 在线/离线切换策略
- **D-02:** 端侧优先，网络不可用时自动切云端。用户拿到手机就能用，离线也能转写；有网时优先端侧（降低服务器成本），无网时无缝切换到 Phase 1 的云端 ASR。
- **D-03:** App 内无需额外 UI（自动切换，透明）。Phase 1/2 的网络状态 UI 组件（`NetworkStatusBar`）复用即可。
- **D-04:** 切换逻辑在 `VoiceRepository` 层实现：`AsrRepository` 封装端侧推理和云端推理两个后端，根据网络状态自动路由。

### 模型分发
- **D-05:** 首次使用时下载。APK 保持苗条（~20-30MB），模型（~400MB）从服务器按需下载。
- **D-06:** 下载进度 UI：首次使用时有下载引导页，展示进度条和存储空间说明。
- **D-07:** 模型存储在 App 的 internal storage 或 external storage（用户可清理）。
- **D-08:** 模型更新策略：服务器端版本检测，有新版本时静默下载更新（类似 TensorFlow Lite 的 Hub 模式）。

### 交互模式
- **D-09:** 保持 Push-to-Talk（和 Phase 1 一致）。长按说话，松开结束。不做 VAD，不做持续监听。
- **D-10:** 语言切换：手动切换按钮（中文普通话 / English），继承 Phase 1 D-15 决策。

### 模型量化（服务器端）
- **D-11:** 量化方法：INT4 AWQ（参照 SPEC.md §2.3.1 决策）。
- **D-12:** 量化参数：`w_bit: 4`，`q_group_size: 128`。
- **D-13:** 量化验证：LibriSpeech test-clean 验证，WER 损失 < 15%（REQ-12）。
- **D-14:** 量化目标：模型 < 500MB（REQ-08）。

### 架构集成
- **D-15:** Flutter 端新增 `OnDeviceAsrEngine` 类，封装 TensorFlow Lite 推理逻辑，对外接口与现有 `VoiceRepository` 对齐。
- **D-16:** `VoiceRepository` 扩展：新增 `AsrBackend` 抽象，`CloudAsrBackend`（Phase 1 实现）和 `OnDeviceAsrBackend`（新增）实现该接口。
- **D-17:** 路由策略：`connectivity_plus` 检测网络状态，网络可用且模型已下载时用端侧，否则用云端。

### Claude's Discretion
以下由 Claude（规划阶段）决定具体实现：
- TensorFlow Lite 模型格式的具体导出流程（量化参数与 AWQ 输出的衔接）
- 模型下载的存储路径和清理策略
- 模型版本检测和增量更新机制
- 端侧推理的线程数/内存配置（根据设备动态调整）
- VibeVoice-ASR 到 TFLite 的算子映射处理（自定义 op 解决方案）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1/2 上下文
- `.planning/phases/01-cloud-asr-pipeline/01-CONTEXT.md` — Phase 1 决策（Push-to-Talk、云端 ASR 架构、Flutter Riverpod、Repository 层）
- `.planning/phases/02-cloud-tts-foundation/02-CONTEXT.md` — Phase 2 决策（WebSocket 协议、Flutter Riverpod、Repository 层）
- `.planning/ROADMAP.md` — Phase 3 目标、验收标准（REQ-08、REQ-09、REQ-12）
- `.planning/REQUIREMENTS.md` — REQ-08、REQ-09、REQ-12（C-01、C-03）

### 协议与架构参考
- `raw/SPEC.md` §2.3.1 — INT4 AWQ 量化方案对比与量化流程
- `raw/SPEC.md` §2.3.2 — 量化流程参考代码（autoawq + 校准数据）
- `raw/SPEC.md` §1.4.3 — WebSocket 断线重连策略（可复用给混合路由）
- `raw/SPEC.md` §1.4.1 — Flutter 音频录制参考代码（AudioRecorderService）

### TensorFlow Lite 参考
- TensorFlow Lite 官方文档 — Android/iOS 集成指南、GPU 委托、模型优化
- TensorFlow Lite Model Maker — 量化工具链参考
- TensorFlow Model Optimization Toolkit — INT8/FP16 量化文档

### 量化框架参考
- `raw/SPEC.md` §2.3 — 端侧推理框架选型（MNN、ExecuTorch、llama.cpp）
- autoawq 官方文档 — AWQ 量化流程参考

### Flutter 音频参考
- `flutter_app/lib/services/audio/audio_recorder_service.dart` — 现有录音服务（16kHz PCM16）
- `flutter_app/lib/domain/repositories/voice_repository.dart` — 现有 Repository 接口
- `flutter_app/lib/presentation/providers/voice_provider.dart` — 现有 ASR 状态管理
- `flutter_app/lib/presentation/widgets/network_status_bar.dart` — 现有网络状态 UI（复用给混合路由）

### 模型文档
- HuggingFace: `microsoft/VibeVoice-ASR` — 7B 模型输入输出格式
- HuggingFace: `google/gemma-4-9b-it` — 后续 Gemma4 迁移参考（模型格式对齐）
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VoiceRepository` — 已有抽象接口，新增 `AsrBackend` 即可扩展
- `AsrState` / `AsrNotifier` — 已有状态管理，端侧推理结果复用相同 stream 接口
- `AudioRecorderService` — 已有 16kHz PCM16 录音，端侧推理复用相同音频输入
- `NetworkStatusBar` — 已有网络状态 UI，混合路由时复用
- `ConnectionProvider` — 已有连接状态管理，可扩展支持端侧/云端路由状态

### Established Patterns
- Flutter: Riverpod 状态管理（Phase 1/2 决策）
- WebSocket: JSON 握手 + binary chunks（Phase 1 决策）
- 指数退避断线重连（Phase 1/2 决策）
- Push-to-Talk 交互（Phase 1 决策 D-14）
- 明确状态 UI 反馈（Phase 1 决策 D-19）

### Integration Points
- Flutter ASR Tab → `VoiceRepository` → `OnDeviceAsrBackend`（新增）或 `CloudAsrBackend`（Phase 1）
- `connectivity_plus` → 网络状态检测 → 路由决策
- 模型下载管理器 → App 存储 → 首次使用引导 UI
- TensorFlow Lite Engine → Flutter Platform Channel → Dart 侧调用

### Creative Options
- RTX 4060 服务器：量化后的 TFLite 模型上传到模型服务器（或 HuggingFace Hub）
- 模型格式：TFLite FlatBuffer 格式（.tflite），支持 GPU 委托（NPU/GPU 加速）
- Android NPU：Pixel 6+ / 三星 Exynos 设备通过 TFLite GPU 委托使用 NPU
- iOS：Core ML 委托（通过 TFLite iOS API 底层调用）
</code_context>

<specifics>
## Specific Ideas

- 首次使用下载引导页：简洁、清晰，展示"正在下载语音模型..."和进度百分比
- 模型下载完成后自动开始使用，无需手动操作
- 离线模式下，网络状态栏显示"离线模式 · 使用本地模型"

[If none: "No specific requirements — open to standard approaches"]
</specifics>

<deferred>
## Deferred Ideas

### 属于其他阶段的功能
- **本地 VAD（Voice Activity Detection）** — Phase 4 或更后期，实现持续监听 + 声控开始/结束
- **输入法 IME 集成** — Phase 4 或更后期，Android IME / iOS Keyboard Extension
- **自动语言检测** — Phase 4 或更后期，实时检测音频语言自动切换
- **Gemma4 迁移** — Phase 4 或后续迭代，在 TensorFlow Lite 基础上做模型替换
- **离线 TTS** — Phase 4（端侧 Realtime TTS）
- **模型压缩进一步优化** — INT4 + 稀疏，目标 200-300MB（未来迭代）
- **LoRA 微调补偿精度** — 用手机录制数据微调，补偿量化精度损失

### 讨论中的 Scope Creep 记录
- VAD 功能被排除（保持 Push-to-Talk，Phase 1 决策延续）
- 完全离线模式被排除（端侧优先但保留云端降级）

None — discussion stayed within phase scope
</deferred>

---

*Phase: 03-on-device-asr*
*Context gathered: 2026-04-14*
