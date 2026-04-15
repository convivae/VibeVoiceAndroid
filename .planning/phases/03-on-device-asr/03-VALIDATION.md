---
phase: 03
slug: on-device-asr
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Python scripts + Android/iOS manual testing |
| **Config file** | `quantize/validate_model.py` (Wave 0) |
| **Quick run command** | `python quantize/validate_model.py --quick` |
| **Full suite command** | `python quantize/validate_model.py --full` |
| **Estimated runtime** | ~600s (full WER evaluation on Librispeech) |

---

## Sampling Rate

- **After every task commit:** Run quick validation (model size, basic inference)
- **After every plan wave:** Run full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~600 seconds (WER full eval)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | REQ-08 | T-03-01 | N/A | model_size | `ls -la *.tflite` | ✅ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | REQ-08 | — | N/A | quantization | `python validate.py --check-int4` | ✅ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | REQ-09 | T-03-02 | Model integrity verification | model_load | `python validate.py --load-model` | ✅ W0 | ⬜ pending |
| 03-03-01 | 03 | 2 | REQ-09 | — | N/A | integration | `flutter test integration_test/` | ✅ W0 | ⬜ pending |
| 03-04-01 | 04 | 2 | REQ-09 | — | Network boundary | routing | `flutter test routing_test/` | ✅ W0 | ⬜ pending |
| 03-05-01 | 05 | 3 | REQ-12 | — | N/A | wer_eval | `python evaluate_wer.py --dataset librispeech` | ❌ W0 | ⬜ pending |
| 03-05-02 | 05 | 3 | C-03 | — | N/A | memory | Android Profiler / Xcode Instruments | N/A manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `quantize/validate_model.py` — model size check, INT4 quantization verification, basic inference test
- [ ] `quantize/evaluate_wer.py` — WER evaluation on Librispeech test-clean subset
- [ ] `flutter_app/test/integration/` — routing logic tests (offline detection, fallback)
- [ ] `flutter_app/test/unit/asr_backend_test.dart` — OnDeviceAsrBackend unit tests
- [ ] `flutter_app/test/unit/model_download_test.dart` — model download manager tests

*Existing infrastructure covers Wave 1 (Flutter unit tests via `flutter test`). Wave 0 must create quantize scripts.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Memory peak < 1.5GB VRAM | C-03 | Requires Android Profiler / Xcode Instruments on real device | 1. Flash the app on Pixel 6+ or iPhone 12+<br>2. Start Android Profiler (Memory tab)<br>3. Run 60s audio through OnDevice ASR<br>4. Record peak VRAM from profiler |
| Model size < 500MB | REQ-08 | File size check is automated, but actual APK bundle impact is manual | 1. `./gradlew assembleRelease`<br>2. Check APK size increase<br>3. Verify < 30MB APK delta |
| Inference latency < 5s for 60s audio | REQ-08 | Real-device timing with cold/warm starts | 1. Launch app, ensure model loaded<br>2. Record 60s audio sample<br>3. Time from push-to-talk release to last token<br>4. Average over 5 runs |
| WER loss < 15% vs FP16 baseline | REQ-12 | Requires Librispeech test-clean full eval + FP16 baseline run | 1. Run FP16 baseline: `python evaluate_wer.py --model fp16 --dataset librispeech`<br>2. Run INT4 AWQ: `python evaluate_wer.py --model int4 --dataset librispeech`<br>3. Calculate WER difference |

*All phase behaviors have automated verification except memory/performance metrics.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 600s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
