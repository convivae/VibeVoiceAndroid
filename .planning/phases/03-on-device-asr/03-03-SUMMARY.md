---
phase: 03-on-device-asr
plan: 03
subsystem: model-download
tags: [asr, model-download, security, riverpod]
dependency_graph:
  requires:
    - 03-01-PLAN.md
    - 03-02-PLAN.md
  provides:
    - ModelDownloadManager
    - ModelDownloadProvider
    - ModelDownloadScreen
  affects:
    - flutter_app/lib/services/asr/
    - flutter_app/lib/presentation/
tech_stack:
  added:
    - crypto (^3.0.3) for SHA256
    - dio (^5.7.0) for download
  patterns:
    - StateNotifier for download state
    - Provider for manager singleton
key_files:
  created:
    - flutter_app/lib/services/asr/model_info.dart
    - flutter_app/lib/services/asr/model_download_manager.dart
    - flutter_app/lib/presentation/providers/model_download_provider.dart
    - flutter_app/lib/presentation/screens/model_download_screen.dart
  modified:
    - flutter_app/pubspec.yaml (crypto dependency)
decisions:
  - Use sealed class for ModelDownloadState (D-06)
  - SHA256 checksum verification before model use (T-03-06)
  - App documents directory for model storage (D-07)
  - model_info.json for version tracking (D-08)
metrics:
  duration: ~45 seconds
  completed: "2026-04-16T16:28"
  tasks: 5/5
---

# Phase 03 Plan 03: Model Download & Management Summary

## One-liner

Model download manager with progress tracking, SHA256 integrity verification, version detection, and first-use guidance UI.

## Implementation

Created 4 new files implementing model download infrastructure for on-device ASR:

| File | Purpose | Lines |
|------|---------|-------|
| `model_info.dart` | ModelInfo metadata + sealed ModelDownloadState hierarchy | 100 |
| `model_download_manager.dart` | Download with dio, progress callbacks, SHA256 verification | 193 |
| `model_download_provider.dart` | Riverpod StateNotifier + convenience providers | 94 |
| `model_download_screen.dart` | First-use guidance UI with progress bar | 177 |

## Task Execution

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Define ModelInfo and ModelDownloadState | f9b9e3e | model_info.dart |
| 2 | Implement ModelDownloadManager | 56084a4 | model_download_manager.dart |
| 3 | Implement ModelDownloadProvider | 05a2f77 | model_download_provider.dart |
| 4 | Create ModelDownloadScreen | cbdd9da | model_download_screen.dart |
| 5 | Add crypto dependency | d0a0e98 | pubspec.yaml |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Import] Added model_info.dart import to screen**
- **Found during:** Task 4 (ModelDownloadScreen)
- **Issue:** Screen referenced `ModelDownloadState` and subclasses without importing them
- **Fix:** Added `import '../../services/asr/model_info.dart';` to model_download_screen.dart
- **Files modified:** `flutter_app/lib/presentation/screens/model_download_screen.dart`
- **Commit:** cbdd9da

## Threat Surface

| Flag | File | Description |
|------|------|-------------|
| mitigation:checksum | model_download_manager.dart:367 | SHA256 verification before model use (T-03-06) |
| mitigation:https | model_download_manager.dart:333 | Download over HTTPS only |
| mitigation:storage | model_download_manager.dart:257 | Model stored in app-private documents (D-07) |

## Commits

```
d0a0e98 chore(03-on-device-asr-03): add crypto package for SHA256 checksum verification
cbdd9da feat(03-on-device-asr-03): create ModelDownloadScreen first-use guidance UI
05a2f77 feat(03-on-device-asr-03): implement ModelDownloadProvider with Riverpod state management
56084a4 feat(03-on-device-asr-03): implement ModelDownloadManager with progress tracking
f9b9e3e feat(03-on-device-asr-03): define ModelInfo and ModelDownloadState
```

## Self-Check

- [x] All files exist on disk
- [x] All commits in git log
- [x] All tasks committed individually
- [x] crypto package added to pubspec.yaml
- [x] No modifications to STATE.md or ROADMAP.md (orchestrator owns those)

## Verification

```bash
# Check all files compile
cd flutter_app && flutter analyze \
  lib/services/asr/model_info.dart \
  lib/services/asr/model_download_manager.dart \
  lib/presentation/providers/model_download_provider.dart \
  lib/presentation/screens/model_download_screen.dart

# Verify crypto dependency
grep "crypto" pubspec.yaml
```