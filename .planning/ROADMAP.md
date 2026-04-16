# Roadmap: VibeVoice Android

## Overview

移植 Microsoft VibeVoice 语音 AI 到 Android/iOS，核心产品是**语音输入法**（ASR 语音转文字），以云端推理为过渡，逐步迁移到端侧部署。

**Strategy**: Cloud ASR first (Phase 1) → Cloud TTS foundation (Phase 2) → On-device ASR (Phase 3) → On-device Realtime TTS (Phase 4)

**Hardware**: Windows Server + RTX 4060 (8GB VRAM, CUDA) 作为云端开发/迭代服务器

## Phases

- [ ] **Phase 1: Cloud ASR Pipeline** - 云端 VibeVoice-ASR 推理服务 + Flutter 语音输入 App (MVP)
- [ ] **Phase 2: Cloud TTS Foundation** - 云端 VibeVoice-Realtime TTS 服务 + Flutter TTS UI（过渡方案）
- [ ] **Phase 3: On-Device ASR** - 端侧 ASR 部署（MNN INT4 量化，7B 模型降到 ~400MB）
- [ ] **Phase 4: On-Device Realtime TTS** - 端侧 Realtime TTS 部署（0.5B 模型）

## Phase Details

### Phase 1: Cloud ASR Pipeline
**Goal**: 2 周内完成 MVP。Flutter 语音输入 App + 云端 VibeVoice-ASR (7B) 推理服务，RTX 4060 服务器作为 GPU 后端。用户长按麦克风 → 语音发送云端 → 实时转文字返回 → 插入到文本框。
**Depends on**: Nothing (first phase)
**Success Criteria** (what must be TRUE):
  1. 用户在 Flutter App 中长按麦克风按钮说完话，文字在 5s 内显示在输入框
  2. ASR 支持中文普通话（mandarin）和英文识别
  3. 麦克风权限申请、网络状态、断线重连有明确 UI 反馈
  4. 云端服务在 RTX 4060 服务器上稳定运行，支持并发 2 路推理
  5. App 可打包为 APK，在 Android 12+ 真机上测试通过
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Cloud ASR Server (FastAPI WebSocket + Transformers inference + Docker)
- [x] 01-02-PLAN.md — Flutter App Foundation (Audio + WebSocket services + Repository layer)
- [x] 01-03-PLAN.md — Flutter UI Layer (Home screen + Push-to-Talk + State management + APK build)

### Phase 2: Cloud TTS Foundation
**Goal**: 在 Phase 1 基础设施上叠加云端 TTS 能力。VibeVoice-Realtime (0.5B) 部署到同一台 RTX 4060 服务器。App 中添加文本输入 → 选择音色 → 播放语音的功能。TTS 是产品验证的过渡方案。
**Depends on**: Phase 1
**Success Criteria** (what must be TRUE):
  1. 用户在 App 中输入文本，选择音色，点击播放，实时收到流式音频并播放
  2. 首音频 chunk 延迟 < 500ms（从发送到收到第一块 PCM）
  3. WebSocket 连续 10 分钟不断线，支持断线重连
  4. 音色切换有 UI，支持中文和英文音色
**Plans**: TBD

### Phase 3: On-Device ASR
**Goal**: 3 个月内将 VibeVoice-ASR (9B) 量化为移动端可用大小（INT4 AWQ ~4-5GB），实现 iOS/Android 离线语音识别。模型通过按需下载方式提供（APK 保持苗条），支持 2-3GB 内存占用的现代设备。
**Depends on**: Phase 2
**Success Criteria** (what must be TRUE):
  1. 模型大小 < 5GB（INT4 AWQ），通过 ModelDownloadManager 下载使用
  2. 内存峰值 < 3GB（Android Profiler 验证）
  3. 推理延迟 < 5s（60s 音频），离线模式下功能完整
  4. ASR WER 相比 FP16 损失 < 15%（LibriSpeech test-clean 验证）
**Plans:** 5 plans

**Important Note**: VibeVoice-ASR is actually 9B parameters (not 7B). INT4 AWQ quantized model is ~4-5GB. Model is downloaded separately via ModelDownloadManager (APK stays lean). Option-b selected: accept 4-5GB target, proceed with full 9B model.

Plans:
- [ ] 03-01-PLAN.md — Model Quantization & TFLite Export (Wave 1, server-side)
- [ ] 03-02-PLAN.md — Flutter TFLite Integration (Wave 1, Flutter-side)
- [ ] 03-03-PLAN.md — Model Download & Management (Wave 2)
- [ ] 03-04-PLAN.md — Hybrid Routing & State Management (Wave 2)
- [ ] 03-05-PLAN.md — Performance Validation & Integration Tests (Wave 3)

### Phase 4: On-Device Realtime TTS
**Goal**: 将 VibeVoice-Realtime (0.5B) 移植到移动端，实现离线实时语音合成。Phase 3 的终极目标。
**Depends on**: Phase 3
**Success Criteria** (what must be TRUE):
  1. 模型可打包进 APK，内存峰值 < 2GB
  2. 离线模式下 TTS 端到端延迟 < 2s（可接受）
  3. MOS 主观评分 > 3.5（用户评测）
  4. 连续播放不发烫（温度 < 45°C）
**Plans**: TBD

---

*Roadmap version: v1.0 — Phase 1 pivoted from cloud TTS to cloud ASR per user direction*
