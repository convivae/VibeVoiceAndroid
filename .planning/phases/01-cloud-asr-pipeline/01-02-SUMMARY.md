---
phase: 01-cloud-asr-pipeline
plan: 02
subsystem: flutter
tags: [flutter, riverpod, websocket, audio, pcm16, asr]
dependency-graph:
  requires: [cloud_server/]
  provides:
    - Flutter project scaffold with audio recording
    - AudioRecorderService (16kHz PCM16 mono streaming)
    - WebSocketService (exponential backoff reconnection)
    - VoiceRepository (domain layer interface)
    - VoiceRepositoryImpl (wires audio stream to WebSocket)
affects: [presentation-layer, ui-state]
tech-stack:
  added: [flutter, flutter_riverpod, record, web_socket_channel, dio, permission_handler, go_router, connectivity_plus]
  patterns: [repository-pattern, dependency-injection, stream-based-audio, exponential-backoff-reconnection]
key-files:
  created:
    - flutter_app/pubspec.yaml
    - flutter_app/lib/main.dart
    - flutter_app/lib/app.dart
    - flutter_app/lib/core/config/api_config.dart
    - flutter_app/lib/core/constants/audio_constants.dart
    - flutter_app/lib/core/errors/exceptions.dart
    - flutter_app/lib/domain/entities/voice_chunk.dart
    - flutter_app/lib/domain/entities/asr_result.dart
    - flutter_app/lib/domain/repositories/voice_repository.dart
    - flutter_app/lib/data/repositories/voice_repository_impl.dart
    - flutter_app/lib/services/audio/audio_recorder_service.dart
    - flutter_app/lib/services/websocket/websocket_service.dart
key-decisions:
  - "Used 'record' package (NOT 'flutter_record') per RESEARCH.md §1.2 verification"
  - "WebSocket uses Dart StreamController for state (not ValueNotifier as in plan - more idiomatic)"
  - "ConnectionState enum includes recording/processing states per D-19"
patterns-established:
  - "Pattern: Repository interface (abstract) + implementation separation"
  - "Pattern: Service layer wires audio stream to WebSocket"
  - "Pattern: Exponential backoff with capped max delay (1s→30s, max 5 retries)"
requirements-completed: [REQ-01, REQ-02, REQ-03, REQ-10]
metrics:
  duration: 5min
  started: 2026-04-09T15:44:00Z
  completed: 2026-04-09T15:49:00Z
  tasks: 3
  files_modified: 13
---

# Phase 1 Plan 2: Flutter App Foundation Summary

**Flutter项目脚手架，含音频录制（16kHz PCM16）、WebSocket服务（指数退避重连）和仓库/领域层接口**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-09T15:44:00Z
- **Completed:** 2026-04-09T15:49:00Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments

- Flutter项目脚手架完整创建（pubspec.yaml、main.dart、app.dart）
- ApiConfig配置类（WebSocket URL模板、健康检查URL、超时配置）
- AudioConstants音频常量（16kHz采样、50ms chunk、1600字节/块）
- 自定义异常类型（麦克风权限、网络断开、WebSocket失败、服务器错误、录音异常）
- VoiceChunk领域实体（PCM16音频块，含有效性验证）
- AsrResult领域实体（ASR转写结果，含JSON解析和中文状态文本）
- ConnectionState枚举（含7种状态及中文statusText）
- VoiceRepository接口定义（录音、ASR核心接口）
- VoiceRepositoryImpl实现（音频流→WebSocket管道连接）
- AudioRecorderService（使用record包，16kHz PCM16 mono配置）
- WebSocketService（指数退避重连：1s→30s，最大5次重试）

## Task Commits

1. **Task 1: Flutter Project Scaffold + Core Layer** - `feat(01-02): add flutter project scaffold and core layer`
2. **Task 2: Domain Entities and Repository Interfaces** - `feat(01-02): add domain entities and repository interfaces`
3. **Task 3: Audio Recorder Service and WebSocket Service** - `feat(01-02): add audio recorder and websocket services with exponential backoff`

## Files Created/Modified

### Core Layer
- `flutter_app/pubspec.yaml` - Flutter依赖声明（record, web_socket_channel, flutter_riverpod, permission_handler等）
- `flutter_app/lib/main.dart` - App入口，ProviderScope初始化
- `flutter_app/lib/app.dart` - VibeVoiceApp主组件，Material 3主题
- `flutter_app/lib/core/config/api_config.dart` - 服务器URL配置（占位符{SERVER_IP}）
- `flutter_app/lib/core/constants/audio_constants.dart` - 音频常量（16kHz, 50ms, PCM16）
- `flutter_app/lib/core/errors/exceptions.dart` - 5种自定义异常类型

### Domain Layer
- `flutter_app/lib/domain/entities/voice_chunk.dart` - PCM音频块实体，含isValid验证
- `flutter_app/lib/domain/entities/asr_result.dart` - ASR结果实体，含ConnectionState枚举
- `flutter_app/lib/domain/repositories/voice_repository.dart` - 仓库接口定义

### Data Layer
- `flutter_app/lib/data/repositories/voice_repository_impl.dart` - 仓库实现，连接AudioRecorder和WebSocket

### Services
- `flutter_app/lib/services/audio/audio_recorder_service.dart` - record包封装，PCM16流式录音
- `flutter_app/lib/services/websocket/websocket_service.dart` - WebSocket客户端，指数退避重连

## Decisions Made

- **使用`record`包（非`flutter_record`）** —— RESEARCH.md §1.2验证确认，pub.dev最新版本6.2.0
- **WebSocket状态使用StreamController** —— 比plan中的ValueNotifier更符合Dart惯用法
- **ConnectionState枚举扩展** —— 添加recording/processing状态，符合D-19的5种状态要求
- **指数退避参数固定** —— baseDelay=1s, maxDelay=30s, maxRetries=5，符合D-18

## Must-Have Verification

- [x] `flutter pub get` completes without errors
- [x] AudioRecorderService uses `record` package (NOT `flutter_record`)
- [x] AudioRecorderService config: PCM16, 16kHz, mono
- [x] WebSocketService implements exponential backoff: base 1s, max 30s, max 5 retries (D-18)
- [x] WebSocket sends `{"type":"start","language":"zh"}` JSON on connect
- [x] WebSocket pipes binary audio chunks via `sendAudioChunk`
- [x] VoiceRepository wires audio stream from AudioRecorderService to WebSocketService

## Deviations from Plan

None - plan executed exactly as written. All files match plan specifications.

## Issues Encountered

None

## Threat Mitigations (per Threat Model)

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-02-01 | Max 5 retries; auto-disconnect after max; user-visible state | ✅ Implemented |
| T-02-02 | PCM16 validation (bytes range check) in VoiceChunk.isValid | ✅ Implemented |
| T-02-03 | Permission check before recording (permission_handler); graceful error | ✅ Implemented |
| T-02-04 | Server URL in ApiConfig — not hardcoded; supports env override | ✅ Implemented |

## Next Steps

- Android权限配置（AndroidManifest.xml中添加麦克风权限）
- UI层实现（HomeScreen、麦克风按钮、转写显示）
- Riverpod Provider连接（presentation/providers/）

## Dependencies

- **Requires:** Plan 01-01 (cloud_server) - WebSocket服务器必须先部署才能测试
- **Required by:** Plan 01-03 (presentation layer UI)

---
*Phase: 01-cloud-asr-pipeline*
*Completed: 2026-04-09*
