# Requirements

## Must-Have

| ID | Requirement | Phase | Notes |
|----|-------------|-------|-------|
| REQ-01 | 中文普通话（Mandarin）和英文 ASR 识别 | Phase 1 | Core product language support |
| REQ-02 | WebSocket 实时流式传输音频（16kHz PCM chunks） | Phase 1 | 50ms per chunk |
| REQ-03 | Flutter App 麦克风权限 + 网络状态 UI 反馈 | Phase 1 | Clear UX for microphone/network states |
| RE-04 | Windows Server RTX 4060 GPU 推理服务 | Phase 1 | CUDA 12+, 8GB VRAM |
| REQ-05 | APK 可打包并运行在 Android 12+ | Phase 1 | 真机测试通过 |
| REQ-06 | 云端 TTS 流式播放（RTX 4060 同一台服务器） | Phase 2 | 过渡方案 |
| REQ-07 | 首音频 chunk 延迟 < 500ms | Phase 2 | TTS UX 标准 |
| REQ-08 | On-device ASR INT4 量化 < 500MB | Phase 3 | MNN 导出 |
| REQ-09 | 离线语音识别功能完整 | Phase 3 | 飞行模式测试 |

## Should-Have

| ID | Requirement | Phase |
|----|-------------|-------|
| REQ-10 | 断线自动重连（WebSocket） | Phase 1 |
| REQ-11 | 音色选择器 UI（TTS） | Phase 2 |
| REQ-12 | 量化后 ASR WER 损失 < 15% | Phase 3 |

## Constraints

| ID | Constraint |
|----|------------|
| C-01 | Android API 24+（覆盖 98%+ 设备） |
| C-02 | iOS 14+（覆盖 95%+ 设备） |
| C-03 | 端侧推理内存峰值 < 2GB |
| C-04 | RTX 4060 单卡 8GB VRAM（云端推理上限） |
