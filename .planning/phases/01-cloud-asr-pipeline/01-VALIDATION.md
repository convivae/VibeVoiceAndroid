---
phase: "01"
slug: "cloud-asr-pipeline"
status: planned
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
created_by: "GSD plan-phase"
last_updated: 2026-04-06
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

|| Property | Value |
|----------|---------|
| **Framework** | pytest 7.x (cloud_server) + flutter test (flutter_app) |
| **Config file** | `cloud_server/tests/conftest.py` (Wave 0 creates) |
| **Quick run command** | `pytest cloud_server/tests/ -v --tb=short` |
| **Full suite command** | `pytest cloud_server/tests/ -v && flutter test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `pytest cloud_server/tests/ -v --tb=short`
- **After every plan wave:** Run `pytest cloud_server/tests/ -v && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

|| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | REQ-04 | T-01-03 | Max 2 concurrent connections enforced | integration | `pytest cloud_server/tests/ -k test_health` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | REQ-04 | T-01-01 | Max audio buffer 10MB enforced | unit | `pytest cloud_server/tests/ -k test_buffer_limit` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | REQ-02 | T-02-02 | PCM16 bytes validation | unit | `pytest flutter_app/test/ -k test_pcm_chunks` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | REQ-10 | T-02-01 | Exponential backoff reconnection | unit | `pytest flutter_app/test/ -k test_reconnect` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | REQ-03 | T-02-03 | Permission check before recording | integration | `pytest flutter_app/test/ -k test_permission` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | REQ-01 | — | N/A | widget | `flutter test flutter_app/test/` | ❌ W0 | ⬜ pending |
| 01-03-03 | 03 | 2 | REQ-05 | — | N/A | build | `flutter build apk --debug` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Requirement → Automated Test Coverage

|| Requirement | Description | Test Type | Automated Command | Gap |
|-------------|-------------|-----------|-------------------|-----|
| REQ-01 | 中文普通话ASR识别 | Integration: send Mandarin PCM to WebSocket ASR endpoint, verify Chinese text returned | integration | `pytest cloud_server/tests/ -k test_mandarin_asr` | Wave 0 creates test |
| REQ-02 | WebSocket实时流式传输（16kHz PCM, 50ms chunks） | Unit: verify chunk size ~1600 bytes, send binary PCM chunks | unit | `pytest cloud_server/tests/ -k test_pcm_chunks` | Wave 0 creates test |
| REQ-03 | 麦克风权限+网络状态UI反馈 | Integration: simulate permission denied/network disconnect, verify UI state transitions | integration | `flutter test flutter_app/test/widgets/` | Wave 0 creates test |
| REQ-04 | RTX 4060 GPU推理服务 | Integration: `docker compose up`, health endpoint returns 200, model loaded | integration | `pytest cloud_server/tests/ -k test_health` | Wave 0 creates test |
| REQ-05 | APK Android 12+打包 | Build: `flutter build apk --debug` succeeds, APK exists | build | `ls flutter_app/build/app/outputs/flutter-apk/app-debug.apk` | Wave 0 creates test |
| REQ-10 | WebSocket断线重连 | Unit: kill WebSocket, verify exponential backoff reconnection (1s→30s, max 5 retries) | unit | `pytest cloud_server/tests/ -k test_reconnect` | Wave 0 creates test |

---

## Wave 0 Requirements

- [ ] `cloud_server/tests/conftest.py` — shared pytest fixtures (FastAPI test client, mock WebSocket)
- [ ] `cloud_server/tests/test_health.py` — covers REQ-04 (health endpoint, Docker container startup)
- [ ] `cloud_server/tests/test_asr_stream.py` — covers REQ-01, REQ-02 (WebSocket ASR, PCM chunk validation, buffer limit)
- [ ] `cloud_server/tests/test_reconnect.py` — covers REQ-10 (exponential backoff reconnection)
- [ ] `flutter_app/test/services/websocket_service_test.dart` — covers REQ-10 (exponential backoff)
- [ ] `flutter_app/test/widgets/status_indicator_test.dart` — covers REQ-03 (permission + network UI states)
- [ ] `flutter_app/test/widgets/mic_button_test.dart` — covers REQ-03 (recording state transitions)

*Wave 0 tests are STUBS that assert expected behavior (TDD Red phase). They should FAIL until the actual implementation is done.*

---

## Manual-Only Verifications

|| Behavior | Requirement | Why Manual | Test Instructions |
|---------|-------------|------------|-------------------|
| GPU inference accuracy (Chinese text correctness) | REQ-01 | Requires real RTX 4060 GPU + model weights | 1. Deploy Docker container on Windows Server  2. Send known Mandarin WAV file  3. Verify transcribed text matches expected output |
| APK installs and runs on Android 12+ device | REQ-05 | Real device/emulator required | 1. `flutter install` to connected device  2. Grant microphone permission  3. Press mic button and speak  4. Verify transcription appears |
| End-to-end WebSocket ASR streaming | REQ-02 | Real server + client + audio hardware | 1. Start cloud server (`docker compose up`)  2. Install APK on Android device  3. Long-press mic, speak Mandarin  4. Verify real-time transcription appears |

*All phase requirements have automated test stubs created in Wave 0. Manual verifications above are for hardware-specific validation that automated tests cannot cover.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
