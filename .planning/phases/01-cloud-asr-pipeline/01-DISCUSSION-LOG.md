# Phase 1: Cloud ASR Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 01-cloud-asr-pipeline
**Areas discussed:** Product Type, Network Protocol, Cloud Inference, Flutter Audio Library, Language Strategy, Recording Interaction, Text Output, Server Environment

---

## Product Type

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| Standalone App (独立 App) | MVP 快速上线，用户手动复制文字 | ✓ |
| Android IME + iOS Keyboard (真正的输入法) | 系统级输入法，文字直接注入文本框 | |
| Standalone first, IME later | MVP 用独立 App 快速验证，Phase 2 做输入法 | |

**User's choice:** Standalone App first, IME later — MVP 用独立 App 快速验证，Phase 2 再做输入法集成

**Notes:** 用户明确核心产品是语音输入法，但 Phase 1 先做独立 App 快速验证体验。Android IME / iOS Keyboard Extension 推迟到 Phase 2。

---

## Network Protocol

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| WebSocket (推荐) | 实时流式传输，边说边出字，体验好但实现复杂 | ✓ |
| REST 批量上传 | 等用户说完一次性上传，体验差（3-10s 延迟才能看到文字） | |

**User's choice:** WebSocket

**Notes:** 语音输入法的核心竞争力是"说完即出字"的流畅感，批量 REST 体验接近没有。

---

## Cloud Inference

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| vLLM Serving (推荐) | Continuous Batching + CUDA 优化，吞吐高，显存利用率好，SPEC.md 已选 | ✓ |
| INT4 量化后推理 | 把 7B 模型量化到 ~4GB，单卡可跑，但需要额外量化步骤 | |
| HF Transformers 直接推理 | 最简单，但无批处理优化，显存利用率低 | |

**User's choice:** vLLM Serving + INT4 量化

**Notes:** RTX 4060 8GB VRAM 限制，7B FP16 (~14GB) 不可直接运行，必须 INT4 AWQ 量化（~4GB）。vLLM 作为推理引擎。

---

## Flutter Audio Library

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| flutter_record (推荐) | 轻量，API 简洁，支持流式读取 PCM chunks，适合 WebSocket 实时上传 | ✓ |
| audio_waveforms | 录音 + 波形显示，适合带 UI 的场景，但重量级 | |
| just_audio + platform channel | 用原生 Android/iOS API，需要自己写 platform channel | |

**User's choice:** flutter_record

---

## Language Strategy

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| 手动选择 (推荐) | App 里放一个语言切换按钮（中文/English)，用户自己选，最简单 | ✓ |
| 自动检测 | 实时检测音频语言，自动切换 ASR 模型/参数 | |
| 混合模式 | 中英文 ASR 同时跑，返回置信度高的结果（最慢） | |

**User's choice:** 手动选择

**Notes:** Phase 1 MVP 先做中文普通话 ASR（国内产品核心)，英文 ASR 后续加。手动切换最简单，也给用户明确预期。

---

## Recording Interaction

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| 长按说话 Push-to-Talk (推荐) | 按住按钮说话，松开结束，最精确，减少误触发 | ✓ |
| 点击切换 Tap-to-Toggle | 点击开始，再次点击结束，操作简单但容易误触发 | |
| 声控 VAD | 开始说话自动检测，停顿自动结束，全程无按钮操作 | |

**User's choice:** 长按说话

**Notes:** 声控（VAD）体验最好但 VAD 本身就是个复杂模块，Phase 1 先不做。

---

## Text Output

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| App 内显示 + 复制按钮 (推荐) | MVP 最简单，文字显示在输入框，用户手动复制 | ✓ |
| App 内显示 + 一键粘贴到剪贴板 | 文字出现后直接复制到系统剪贴板，体验稍好 | |
| 自动填入目标 App | 需要 Android Accessibility / iOS App Extension，Phase 2 IME 再做 | |

**User's choice:** App 内显示 + 复制按钮

**Notes:** Phase 1 MVP 最简方案，后续 Phase 2 IME 集成时再做自动填入。

---

## Server Environment

|| Option | Description | Selected |
|--------|--------|-------------|----------|
| WSL2 + Docker Desktop on Windows (推荐) | Windows Server 装 WSL2，GPU passthrough，SPEC.md 方案，不需要重装系统 | ✓ |
| 原生 Ubuntu VM + Docker | Windows Server 上装 Hyper-V，VM 里跑 Ubuntu + Docker，GPU 直通 | |
| 裸机 Ubuntu | 直接装 Ubuntu Server，不要 Windows 层，最干净但需要重装系统 | |

**User's choice:** WSL2 + Docker Desktop

**Notes:** SPEC.md 里也是这个方案，Windows Server 不需要重装，WSL2 GPU passthrough 对 RTX 4060 支持成熟。

---

## Claude's Discretion

以下由规划阶段决定，未在讨论中覆盖：
- Flutter App 的 UI 配色和视觉风格
- Flutter 状态管理选型（Riverpod vs BLoC）
- ASR 分句策略（实时返回 tokens vs 完整句子）
- vLLM 并发连接数上限配置
- 具体音色/Voice preset 选择器的 UI 设计（Phase 2 TTS 相关）

## Deferred Ideas

- **Android IME / iOS Keyboard Extension** — Phase 2 再做
- **声控 VAD** — Phase 2 或更后期
- **自动语言检测** — Phase 2 或更后期
- **英文 ASR** — Phase 2 再加
- **flutter_soloud 音频播放** — Phase 2 TTS 才需要
- **离线 ASR 模式** — Phase 3
- **端侧 TTS** — Phase 4
