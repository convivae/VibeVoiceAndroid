---
phase: 02
slug: cloud-tts-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-10
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|---------|-------|
| **Framework** | pytest 7.x + pytest-asyncio |
| **Config file** | tests/conftest.py (Wave 0 creates) |
| **Quick run command** | `pytest tests/unit/ -v -x` |
| **Full suite command** | `pytest tests/ -v --tb=short` |
| **Estimated runtime** | ~30 seconds (unit), ~120 seconds (full) |
| **Mobile tests** | Appium (manual checklist only) |

---

## Sampling Rate

- **After every task commit:** Run `pytest tests/unit/ -v -x`
- **After every plan wave:** Run `pytest tests/ -v --tb=short`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds (unit), 120 seconds (full)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-S-01 | S | 1 | REQ-06 (TTS stream) | T-02-01 | N/A | unit | `pytest tests/unit/test_tts_websocket.py -v` | ✅ W0 | ⬜ pending |
| 02-S-02 | S | 1 | REQ-06 (voices endpoint) | T-02-01 | Input validation | unit | `pytest tests/unit/test_voices_endpoint.py -v` | ✅ W0 | ⬜ pending |
| 02-S-03 | S | 1 | REQ-07 (TTFP perf) | T-02-02 | Rate limiting | perf | `pytest tests/performance/test_ttfp.py -v` | ✅ W0 | ⬜ pending |
| 02-S-04 | S | 1 | REQ-06 (stability 10min) | T-02-02 | Resource limits | integration | `pytest tests/integration/test_stability.py -v` | ✅ W0 | ⬜ pending |
| 02-F-01 | F | 2 | REQ-06 (TTS audio player) | — | N/A | unit | `pytest tests/unit/test_tts_player.py -v` | ✅ W0 | ⬜ pending |
| 02-F-02 | F | 2 | REQ-06 (WebSocket lifecycle) | T-02-01 | N/A | unit | `pytest tests/unit/test_tts_ws_manager.py -v` | ✅ W0 | ⬜ pending |
| 02-F-03 | F | 2 | REQ-06 (pause buffer) | — | N/A | unit | `pytest tests/unit/test_pause_buffer.py -v` | ✅ W0 | ⬜ pending |
| 02-F-04 | F | 2 | REQ-11 (voice selector UI) | — | N/A | widget | `pytest tests/unit/test_voice_selector.py -v` | ✅ W0 | ⬜ pending |
| 02-F-05 | F | 2 | REQ-11 (playback controls UI) | — | N/A | widget | `pytest tests/unit/test_playback_controls.py -v` | ✅ W0 | ⬜ pending |
| 02-F-06 | F | 2 | REQ-06+11 (e2e TTS flow) | — | N/A | integration | `pytest tests/integration/test_tts_e2e.py -v` | ✅ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/conftest.py` — shared fixtures (WebSocket mock, audio fixture)
- [ ] `tests/unit/test_tts_websocket.py` — stubs for TTS WebSocket protocol
- [ ] `tests/unit/test_voices_endpoint.py` — stubs for /voices endpoint
- [ ] `tests/unit/test_tts_player.py` — stubs for TTS audio player
- [ ] `tests/unit/test_tts_ws_manager.py` — stubs for WebSocket lifecycle
- [ ] `tests/unit/test_pause_buffer.py` — stubs for pause/resume buffer
- [ ] `tests/unit/test_voice_selector.py` — stubs for voice selector widget
- [ ] `tests/unit/test_playback_controls.py` — stubs for playback controls widget
- [ ] `tests/performance/test_ttfp.py` — stubs for TTFP performance test
- [ ] `tests/integration/test_tts_e2e.py` — stubs for E2E TTS flow
- [ ] `tests/integration/test_stability.py` — stubs for 10-minute stability test
- [ ] `pytest.ini` or `pyproject.toml` — pytest configuration

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| TTFP < 500ms (perceived latency) | REQ-07 | 需要秒表 + 主观感知测试 | 1. 打开 App TTS Tab<br>2. 输入文本<br>3. 点击播放并用秒表计时<br>4. 记录听到声音的时间<br>5. 重复 5 次，取平均值 |
| 10-min WebSocket stability | REQ-06 | 长时间运行测试 | 1. 运行 `pytest tests/integration/test_stability.py`<br>2. 监控连接不断开<br>3. 检查 chunks_received > 1000 |
| 中文 TTS 音频质量 | REQ-06 | 主观 MOS 评分 | 1. 播放中文文本<br>2. 听感评估音质<br>3. 对比参考音频 |
| 英文 TTS 音频质量 | REQ-06 | 主观 MOS 评分 | 1. 播放英文文本<br>2. 听感评估音质<br>3. 对比参考音频 |
| 音色切换听感差异 | REQ-11 | 主观判断 | 1. 选择不同音色<br>2. 播放相同文本<br>3. 确认听感有差异 |
| 进度条与音频同步 | REQ-06 | UI 实际体验 | 1. 播放长文本<br>2. 观察进度条与实际播放进度是否一致<br>3. 检查时长显示正确 |
| 错误状态 UI | REQ-06 | 网络异常场景 | 1. 飞行模式点击播放<br>2. 确认错误提示显示 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (unit tests)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
