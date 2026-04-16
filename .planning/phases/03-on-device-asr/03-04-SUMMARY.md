---
phase: 03-on-device-asr
plan: 04
subsystem: asr
tags: [flutter, connectivity_plus, dio, riverpod, tflite]

# Dependency graph
requires:
  - phase: 03-02-PLAN.md
    provides: OnDeviceAsrBackend with TFLite model loading
  - phase: 03-03-PLAN.md
    provides: CloudAsrBackend placeholder
provides:
  - HybridAsrService with automatic on-device/cloud routing
  - VoiceRepositoryImpl wired with hybrid routing
  - AsrState with isOfflineMode field
  - NetworkStatusBar showing offline mode message
affects:
  - Phase 03-05: Full end-to-end verification
  - Phase 04: On-device TTS

# Tech tracking
tech-stack:
  added: [connectivity_plus, dio]
  patterns: [hybrid backend routing, automatic fallback, connectivity monitoring]

key-files:
  created:
    - flutter_app/lib/services/asr/hybrid_asr_service.dart
  modified:
    - flutter_app/lib/data/repositories/voice_repository_impl.dart
    - flutter_app/lib/presentation/providers/voice_provider.dart
    - flutter_app/lib/presentation/widgets/network_status_bar.dart

key-decisions:
  - "D-02: On-device priority with auto-fallback to cloud"
  - "D-03: Show offline mode in NetworkStatusBar, not separate UI"
  - "D-04: Switching logic in VoiceRepository layer"
  - "D-17: Use connectivity_plus for network detection"

patterns-established:
  - "Hybrid backend pattern: multiple ASR backends with automatic selection"
  - "Periodic routing status polling for UI updates"

requirements-completed: [REQ-09, D-02, D-03, D-04, D-17]

# Metrics
duration: 5min
completed: 2026-04-17
---

# Phase 03 Plan 04: Hybrid ASR Routing Summary

**HybridAsrService with on-device/cloud automatic routing using connectivity_plus**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-17T12:00:00Z
- **Completed:** 2026-04-17T12:05:00Z
- **Tasks:** 4 (automated tasks completed, checkpoint pending human verification)
- **Files modified:** 4

## Accomplishments
- Created HybridAsrService with automatic backend selection
- Wired hybrid routing into VoiceRepositoryImpl
- Extended AsrState with isOfflineMode field and provider
- Updated NetworkStatusBar to display "离线模式 · 使用本地模型" in offline mode

## Task Commits

Each task was committed atomically:

1. **Task 1: Create HybridAsrService** - `8f6cdd9` (feat)
2. **Task 2: Wire HybridAsrService into VoiceRepositoryImpl** - `46b8376` (feat)
3. **Task 3: Extend AsrState and AsrNotifier for Offline Mode** - `79dd910` (feat)
4. **Task 4: Update NetworkStatusBar for Offline Mode** - `16003b7` (feat)

## Files Created/Modified
- `flutter_app/lib/services/asr/hybrid_asr_service.dart` - Hybrid routing service with on-device/cloud backend selection
- `flutter_app/lib/data/repositories/voice_repository_impl.dart` - VoiceRepository with hybrid routing wired
- `flutter_app/lib/presentation/providers/voice_provider.dart` - AsrState with isOfflineMode field
- `flutter_app/lib/presentation/widgets/network_status_bar.dart` - NetworkStatusBar showing offline mode

## Decisions Made
- Used connectivity_plus for network detection (D-17)
- On-device preferred even when online (for battery/privacy)
- Green status bar for offline mode (distinct from orange/red error bars)
- HybridRoutingStatus enum for UI status display

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Fixed missing WsConnectionState import in network_status_bar.dart (Rule 3 - Blocking)
- Removed unused serverIssue variable to eliminate warning

## Human Verification Required

**Task 5: Verify Hybrid Routing End-to-End (checkpoint)**

Test the following scenarios:

### Scenario 1: Offline Mode (Airplane Mode)
1. Enable airplane mode on device/emulator
2. Ensure model is downloaded
3. Open app
4. Start recording
5. **Expected**: NetworkStatusBar shows green "离线模式 · 使用本地模型"
6. **Expected**: Transcription works without network

### Scenario 2: Online Mode (Normal Network)
1. Disable airplane mode
2. Ensure network connected
3. Open app
4. Start recording
5. **Expected**: NetworkStatusBar hidden (no issues)
6. **Expected**: Transcription uses cloud ASR

### Scenario 3: Model Not Downloaded + Online
1. Delete local model
2. Ensure network connected
3. Open app
4. **Expected**: Cloud ASR fallback works

### Scenario 4: Model Not Downloaded + Offline
1. Delete local model
2. Enable airplane mode
3. Open app
4. Start recording
5. **Expected**: Error message shown, no transcription possible

## Next Phase Readiness
- HybridAsrService ready for integration with Phase 03-05
- VoiceRepositoryImpl updated with hybrid routing
- NetworkStatusBar shows correct offline mode messages
- End-to-end verification pending human testing

---
*Phase: 03-on-device-asr*
*Completed: 2026-04-17*
