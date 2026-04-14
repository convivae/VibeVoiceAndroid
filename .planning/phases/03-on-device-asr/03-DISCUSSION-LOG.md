# Phase 3: On-Device ASR - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 03-on-device-asr
**Areas discussed:** 推理框架, 在线/离线切换策略, 模型分发, 交互模式

---

## 推理框架

| Option | Description | Selected |
|--------|-------------|----------|
| MNN | SPEC.md 推荐，VibeVoice ASR/TTS 有 TaoAvatar 迁移案例，量化工具成熟 | |
| llama.cpp (GGUF) | GGUF 量化生态成熟，OpenCL GPU 加速（骁龙 8 Gen3），llamafile 0.10 全面 GPU 支持 | |
| ExecuTorch | PyTorch 原生，对 VibeVoice 代码改动最小 | |
| TensorFlow Lite | 生态成熟，便于后续迁移到 Gemma4 | ✓ |

**User's choice:** TensorFlow Lite
**Notes:** 采用 TensorFlow Lite 的理由是后续能迁移到 Gemma4。用户明确以此为选型依据。

---

## 在线/离线切换策略

| Option | Description | Selected |
|--------|-------------|----------|
| 端侧优先，网络不可用时自动切云端 | 用户拿到手机就能用，离线也能转写，有网时用云端（可能精度更高） | ✓ |
| 云端优先，手动切换到离线模式 | 类似飞行模式开关，用户主动控制 | |
| 始终只用端侧（完全离线） | 简化逻辑，但失去云端高精度选项 | |

**User's choice:** 端侧优先，网络不可用时自动切云端
**Notes:** 离线能力是"保底"，用户期望端侧作为主力推理路径。

---

## 模型分发

| Option | Description | Selected |
|--------|-------------|----------|
| 首次使用时下载 | APK 保持苗条（~20-30MB），用户首次使用时从服务器下载模型。需考虑下载进度 UI、存储位置、增量更新 | ✓ |
| 直接打包进 APK | 用户安装即完整可用，无下载等待。但 Play Store 单 APK 上限 200MB | |
| 应用商店扩展包 | Google Play 的 OBB 格式，最大 2GB，或 iOS 的 On-Demand Resources | |

**User's choice:** 首次使用时下载
**Notes:** APK 保持苗条，模型按需下载。

---

## 交互模式

| Option | Description | Selected |
|--------|-------------|----------|
| 保持 Push-to-Talk（和 Phase 1 一致） | 和 Phase 1/2 一致，用户最熟悉，不需要额外开发 | ✓ |
| 新增持续监听 + 本地 VAD | 说话自动开始，空闲自动结束，体验更流畅。但本地 VAD 需要额外的模型或规则 | |
| 两种模式都支持 | 用户可选，Toggle 切换 | |

**User's choice:** 保持 Push-to-Talk（和 Phase 1 一致）
**Notes:** Phase 1 明确排除了 VAD，Phase 3 延续此决策。不做 VAD，不做持续监听。

---

## Claude's Discretion

以下决策由 Claude 在规划阶段决定（用户选择"Let Claude decide"或该领域无明显偏好）：
- TensorFlow Lite 模型格式的具体导出流程
- 模型下载的存储路径和清理策略
- 模型版本检测和增量更新机制
- 端侧推理的线程数/内存配置

---

## Deferred Ideas

- VAD 功能 — 属于 Phase 4 或更后期
- 输入法 IME 集成 — 属于 Phase 4
- 自动语言检测 — 属于 Phase 4
- Gemma4 迁移 — 后续迭代
- 离线 TTS — Phase 4
