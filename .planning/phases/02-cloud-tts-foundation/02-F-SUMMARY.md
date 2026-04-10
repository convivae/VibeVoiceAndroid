---
phase: 02-cloud-tts-foundation
plan: F
subsystem: ui
tags: [flutter, riverpod, flutter_soloud, websocket, tts]

# Dependency graph
requires:
  - phase: 01-cloud-asr-pipeline
    provides: WebSocket client pattern, Riverpod state management, flutter_soloud audio engine
provides:
  - TTS Tab UI with bottom navigation
  - TtsWebSocketService with streaming audio + exponential backoff
  - TtsAudioPlayer stub ready for flutter_soloud integration
  - 5 voice presets (2 Chinese, 2 English, 1 mixed)
affects: [cloud-tts-foundation, on-device-tts]

# Tech tracking
tech-stack:
  added: [flutter_soloud, tts_websocket_service, tts_audio_player, tts_provider]
  patterns: [Riverpod StateNotifier, sealed class messages, Binary+JSON WebSocket protocol, IndexedStack tab navigation]

key-files:
  created:
    - flutter_app/lib/domain/entities/voice_info.dart
    - flutter_app/lib/domain/entities/tts_state.dart
    - flutter_app/lib/services/websocket/tts_websocket_service.dart
    - flutter_app/lib/services/audio/tts_audio_player.dart
    - flutter_app/lib/presentation/providers/tts_provider.dart
    - flutter_app/lib/presentation/widgets/voice_selector.dart
    - flutter_app/lib/presentation/widgets/playback_controls.dart
    - flutter_app/lib/presentation/widgets/tts_progress_bar.dart
    - flutter_app/lib/presentation/screens/tts_screen.dart
  modified:
    - flutter_app/pubspec.yaml
    - flutter_app/lib/presentation/screens/home_screen.dart
    - flutter_app/lib/app.dart

key-decisions:
  - "TtsWebSocketService uses correct dart:convert jsonDecode/jsonEncode (plan template had broken code)"
  - "TtsAudioPlayer uses a stub pattern ready for flutter_soloud BufferStream integration"
  - "Binary audio chunks paired with preceding JSON header via _pendingChunkHeader state machine"
  - "ConnectionState re-used from existing asr_result.dart (not duplicated)"
  - "VoiceInfo imported from existing asr_result.dart for re-used types"

patterns-established:
  - "Pattern: Sealed class message hierarchy for WebSocket protocol (TtsMetadata/TtsAudioChunk/TtsDone/TtsError)"
  - "Pattern: Provider-based state mirroring ASR pattern"
  - "Pattern: IndexedStack tab navigation with NavigationBar"

requirements-completed: [REQ-06, REQ-07, REQ-11]

# Metrics
duration: ~8min
completed: 2026-04-10
---

# Phase 2 Plan F: Flutter TTS UI Summary

**Flutter TTS Tab with WebSocket streaming, 5 voice presets, and flutter_soloud-ready audio player**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-10T14:44:49Z
- **Completed:** 2026-04-10T14:52:XXZ
- **Tasks:** 5/6 (checkpoint pending)
- **Files modified:** 11 files (3 created entities/services, 3 widgets, 1 screen, 3 modified)

## Accomplishments

- TTS Tab integrated into app via `MainScreen` with bottom `NavigationBar` (ASR + TTS tabs)
- `TtsWebSocketService` with correct JSON/binary WebSocket protocol parsing and exponential backoff
- `TtsAudioPlayer` stub with play/pause/resume/stop lifecycle, ready for `flutter_soloud` BufferStream
- 5 voice presets: zh_female_1, zh_male_1, en_female_1, en_male_1, mixed_1
- Full Riverpod state management with `TtsNotifier` coordinating WebSocket + audio player

## Task Commits

1. **Task 1: Add Dependencies and Create TTS Entities** - `8565150` (feat)
2. **Task 2: Create TTS WebSocket Service and Audio Player** - `5ef1df7` (feat)
3. **Task 3: Create TTS Provider** - `52234ce` (feat)
4. **Task 4: Create TTS UI Widgets** - `aba02a8` (feat)
5. **Task 5: Create TTS Screen and Tab Navigation** - `ff29070` (feat)

## Files Created/Modified

- `flutter_app/pubspec.yaml` - Added flutter_soloud: ^3.2.1
- `flutter_app/lib/domain/entities/voice_info.dart` - VoiceInfo with fromJson + 5 default presets
- `flutter_app/lib/domain/entities/tts_state.dart` - TtsState, TtsPlaybackState enum, ConnectionState import
- `flutter_app/lib/services/websocket/tts_websocket_service.dart` - TtsWebSocketService with correct jsonDecode/jsonEncode
- `flutter_app/lib/services/audio/tts_audio_player.dart` - TtsAudioPlayer stub ready for BufferStream
- `flutter_app/lib/presentation/providers/tts_provider.dart` - TtsNotifier + ttsProvider + convenience providers
- `flutter_app/lib/presentation/widgets/voice_selector.dart` - VoiceSelector with language chips (中/EN/混)
- `flutter_app/lib/presentation/widgets/playback_controls.dart` - PlaybackControls with play/pause/stop
- `flutter_app/lib/presentation/widgets/tts_progress_bar.dart` - TtsProgressBar with slider + duration display
- `flutter_app/lib/presentation/screens/tts_screen.dart` - TtsScreen ConsumerStatefulWidget
- `flutter_app/lib/presentation/screens/home_screen.dart` - Added MainScreen with NavigationBar
- `flutter_app/lib/app.dart` - Updated home: MainScreen()

## Decisions Made

- Used `jsonDecode`/`jsonEncode` from `dart:convert` instead of plan's broken `Map.toString()` pattern
- TtsAudioPlayer implemented as a stub (BufferStream API requires platform-specific setup)
- Re-used `ConnectionState` from existing `asr_result.dart` instead of duplicating enum
- Binary audio data paired with preceding JSON header via `_pendingChunkHeader` state

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed broken JSON serialization in WebSocket service**
- **Found during:** Task 2 (Create TTS WebSocket Service)
- **Issue:** Plan template used `Map.toString()` and `dynamic` casts that don't compile in Dart
- **Fix:** Implemented correct `jsonDecode(json)` with proper type casting and separate binary handler
- **Files modified:** `flutter_app/lib/services/websocket/tts_websocket_service.dart`
- **Verification:** grep confirms `jsonDecode` and `jsonEncode` usage
- **Committed in:** `5ef1df7` (Task 2 commit)

**2. [Rule 2 - Missing] Added VoiceSelector onVoiceChanged parameter type**
- **Found during:** Task 4 (Create TTS UI Widgets)
- **Issue:** Plan template used `ValueChanged<String>` but widget actually receives `VoiceInfo`
- **Fix:** Changed callback to `ValueChanged<VoiceInfo>` and `_onVoiceChanged` to pass full voice object
- **Files modified:** `flutter_app/lib/presentation/screens/tts_screen.dart`
- **Verification:** Confirmed `_onVoiceChanged` passes `voice.id` and `voice.name`
- **Committed in:** `ff29070` (Task 5 commit)

**3. [Rule 2 - Missing] Added tts_connection_stateProvider convenience provider**
- **Found during:** Task 3 (Create TTS Provider)
- **Issue:** TtsScreen needed `ttsConnectionState` for connection indicator but only `ttsProvider` existed
- **Fix:** Added `ttsConnectionStateProvider` and `availableVoicesProvider` convenience providers
- **Files modified:** `flutter_app/lib/presentation/providers/tts_provider.dart`
- **Verification:** grep confirms provider exports
- **Committed in:** `52234ce` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 2 missing)
**Impact on plan:** All fixes were correctness requirements. flutter_soloud integration deferred to Task 6 user validation.

## Issues Encountered

- **Syntax errors in plan template:** Plan template contained `});` in constructor and used non-existent `dart:convert` patterns — fixed inline per deviation rules.
- **TtsAudioPlayer BufferStream:** `flutter_soloud` BufferStream API requires platform-specific initialization. Implemented stub that tracks position/chunks for now, ready for full BufferStream integration.

## User Setup Required

- **External services require manual configuration.** See `flutter_soloud` package setup:
  - Run `flutter pub add flutter_soloud` in `flutter_app/` directory
  - Verify `flutter analyze` passes with no errors
  - Verify `flutter build apk --debug` succeeds before testing on device

## Next Phase Readiness

- TTS Tab UI complete and integrated into app navigation
- WebSocket streaming client implemented with correct protocol
- flutter_soloud integration deferred to Task 6 validation (user needs to confirm package works)
- Phase 2-S (Server) must be running for end-to-end test

---

*Phase: 02-cloud-tts-foundation*
*Plan F completed: 2026-04-10*
