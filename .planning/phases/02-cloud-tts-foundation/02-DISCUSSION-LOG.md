# Phase 2: Cloud TTS Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 02-cloud-tts-foundation
**Areas discussed:** 交互模式, 音色策略, 流式播放策略, 显存管理, 部署架构

---

## 交互模式

| Option | Description | Selected |
|--------|-------------|----------|
| 独立 TTS Tab | 底部导航切换，ASR Tab 和 TTS Tab 分开，职责清晰 | ✓ |
| 底部切换 Tab（ASR / TTS） | 类似微信底部 Tab | |
| 同屏两个模块 | 主页同时显示 ASR + TTS | |

**User's choice:** 独立 TTS Tab
**Notes:** 职责清晰，用户通过 Tab 切换，TTS Tab 包含：文本输入框 + 音色选择器 + 播放控制区

---

## 音色策略

| Option | Description | Selected |
|--------|-------------|----------|
| 预设音色列表 | 服务器 /voices 端点返回预设音色，Phase 2 先做 3-5 个 | ✓ |
| 自定义 Voice Prompt | 用户上传参考音频 .wav | |
| 预设 + 用户自定义 | 预设快速切换 + 高级选项自定义 | |

**User's choice:** 预设音色列表
**Notes:** Phase 2 快速验证，预设 5 个音色（2 中文 + 2 英文 + 1 中英混合）

---

## 流式播放策略

| Option | Description | Selected |
|--------|-------------|----------|
| 边收边播 | 收到第一个 chunk 就播放，追求最低延迟 < 500ms | ✓ |
| 先收后播 | 等待完整音频收集后再播放 | |
| 先收后播 + 快速播放 | 收集少量 chunks 后快速开始播放 | |

**User's choice:** 边收边播
**Notes:** 目标 TTFP < 500ms，追求实时感

---

## 播放控制

| Option | Description | Selected |
|--------|-------------|----------|
| 播放/暂停 + 停止 + 进度条 | 完整播放控制，进度条基于 estimated_chunks | ✓ |
| 播放/暂停 + 停止 | 核心控制，进度感知通过时长数字 | |
| 仅播放/暂停 | 最简 | |

**User's choice:** 播放/暂停 + 停止 + 进度条
**Notes:** 暂停时保留已接收 audio buffer，恢复时从断点继续；停止时立即中断 WebSocket 连接

---

## 显存管理

| Option | Description | Selected |
|--------|-------------|----------|
| TTS 也量化（INT4） | TTS 0.5B INT4（~250MB），ASR 7B INT4（~4GB），共 ~5GB | |
| TTS 不量化 | TTS 0.5B bf16（~1GB）+ ASR INT4，共 ~5GB | |
| 分开部署 | ASR 和 TTS 各自独立，按需加载，显存互不干扰 | ✓ |

**User's choice:** 分开部署
**Notes:** 显存互不干扰，更稳定

---

## 部署架构

| Option | Description | Selected |
|--------|-------------|----------|
| 共享端口，按需加载 | FastAPI 同一进程加载两个 vLLM 模型，通过路由区分 ASR/TTS | ✓ |
| 固定双端口独立服务 | ASR 8000，TTS 8001，两个独立 FastAPI 服务 | |
| Docker Compose 端口映射 | nginx 统一对外 8000，按路径路由 | |

**User's choice:** 共享端口，按需加载
**Notes:** FastAPI 统一管理，共用显存调度

---

## Deferred Ideas

- 自定义 Voice Prompt — Phase 4+ 才做
- 语音变声 — Phase 3+ 后续
- TTS 历史记录 — 后续迭代
- 全双工对话（Voice → Voice）— Phase 3+
