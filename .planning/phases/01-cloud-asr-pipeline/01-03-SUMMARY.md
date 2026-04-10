# Phase 1: Cloud ASR Pipeline — Plan 03 Summary

## Flutter UI Layer Implementation

**Status:** ✅ Implementation complete (awaiting APK build)
**Date:** 2026-04-07
**Phase:** 01-cloud-asr-pipeline / plan 03
**Wave:** 2 (depends on plan 02)

---

## What Was Built

### 1. Riverpod State Management

| File | Purpose |
|------|---------|
| `lib/presentation/providers/providers.dart` | Service providers (AudioRecorderService, WebSocketService, VoiceRepository) |
| `lib/presentation/providers/connection_provider.dart` | Connection state, network connectivity providers |
| `lib/presentation/providers/voice_provider.dart` | `AsrNotifier` + `AsrState` + convenience providers |

**Key exports:**
- `asrProvider` — main StateNotifier provider
- `currentConnectionStateProvider` — synchronous connection state
- `isNetworkAvailableProvider` — network connectivity
- Convenience providers: `isRecordingProvider`, `transcriptionTextProvider`, `transcriptionHistoryProvider`, `currentLanguageProvider`, `microphonePermissionProvider`, `isProcessingProvider`, `asrErrorMessageProvider`

### 2. UI Widgets

| Widget | File | Features |
|--------|------|---------|
| `MicButton` | `widgets/mic_button.dart` | Long-press Push-to-Talk, scale + pulse animation, 3 visual states |
| `TranscriptionDisplay` | `widgets/transcription_display.dart` | Current text + copy button, session history with reverse list |
| `StatusIndicator` | `widgets/status_indicator.dart` | 7-state indicator with animated dots (connected/disconnected/recording/processing/error) |
| `LanguageToggle` | `widgets/language_toggle.dart` | SegmentedButton zh/en |
| `NetworkStatusBar` | `widgets/network_status_bar.dart` | Top bar for network/server issues |

### 3. Home Screen

**`lib/presentation/screens/home_screen.dart`**
- Assembles all 5 widgets
- Layout: AppBar → Language toggle → Transcription area → Mic button
- Dynamic instruction text: "长按麦克风开始说话" / "松开结束录音..." / "等待连接..."
- Permission hint when unknown, settings redirect when denied

### 4. Android Configuration

| File | Key Settings |
|------|-------------|
| `android/app/src/main/AndroidManifest.xml` | `RECORD_AUDIO`, `INTERNET`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE` permissions; `usesCleartextTraffic="true"` |
| `android/app/build.gradle` | `minSdk = 24`, `targetSdk = 35`, `compileSdk = 35`, Java 17, Kotlin 1.9.22 |
| `android/build.gradle` | Kotlin plugin 1.9.22, Android Gradle plugin 8.1.0 |
| `android/settings.gradle` | Flutter plugin loader |
| `android/gradle.properties` | AndroidX + Jetifier enabled |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Standard FlutterActivity |

---

## Files Created (20 files)

```
flutter_app/lib/
├── app.dart                          (updated — now imports HomeScreen)
└── presentation/
    ├── providers/
    │   ├── providers.dart           (new)
    │   ├── connection_provider.dart  (new)
    │   └── voice_provider.dart       (new)
    ├── widgets/
    │   ├── mic_button.dart           (new)
    │   ├── transcription_display.dart (new)
    │   ├── status_indicator.dart      (new)
    │   ├── language_toggle.dart       (new)
    │   └── network_status_bar.dart    (new)
    └── screens/
        └── home_screen.dart          (new)

flutter_app/android/
├── app/
│   ├── build.gradle                  (new)
│   └── src/main/
│       ├── AndroidManifest.xml        (new)
│       ├── kotlin/.../MainActivity.kt (new)
│       └── res/
│           ├── values/styles.xml     (new)
│           └── drawable/launch_background.xml (new)
├── build.gradle                      (new)
├── settings.gradle                   (new)
├── gradle.properties                 (new)
└── gradle/wrapper/gradle-wrapper.properties (new)
```

---

## Architecture Notes

### Data Flow
```
User long-press → MicButton → AsrNotifier.startRecording()
                              ↓
                    VoiceRepository.connect()
                    VoiceRepository.startRecording()
                              ↓
                    AudioRecorderService (mic stream)
                              ↓
                    WebSocketService.sendAudioChunk()
                              ↓
                    Server ASR (vLLM)
                              ↓
                    WebSocketService.messageStream
                              ↓
                    AsrNotifier._onTranscriptionResult()
                              ↓
                    AsrState.transcriptionText + history
                              ↓
                    TranscriptionDisplay (UI update)
```

### State Slices (via convenience providers)
- `asrProvider` — all state in one StateNotifier
- `isRecordingProvider` — just the recording flag
- `transcriptionTextProvider` — current text
- `transcriptionHistoryProvider` — session history list
- `currentLanguageProvider` — 'zh' or 'en'
- `microphonePermissionProvider` — permission status
- `isProcessingProvider` — waiting for result
- `asrErrorMessageProvider` — current error

---

## Dependencies (from pubspec.yaml)

Already configured in plan 01:
- `flutter_riverpod: ^3.3.1` — state management (D-12)
- `record: ^6.2.0` — audio recording (D-09)
- `web_socket_channel: ^3.0.1` — WebSocket client (D-01)
- `connectivity_plus: ^6.1.1` — network status (D-19)
- `permission_handler: ^11.3.1` — mic permission (D-03)
- `go_router: ^14.6.2` — routing
- `dio: ^5.7.0` — HTTP client

---

## Pending: APK Build

Flutter SDK is being installed on this machine. Once available, run:

```bash
cd flutter_app

# Configure server IP first
# Edit lib/core/config/api_config.dart
# Replace {SERVER_IP} with actual RTX 4060 server address
# e.g.: ws://192.168.1.100:8000/v1/asr/stream

flutter pub get
flutter analyze
flutter build apk --debug
```

Expected output: `build/app/outputs/flutter-apk/app-debug.apk` (~15-25MB)

---

## Verification Checklist

| Criteria | Status |
|----------|--------|
| Long-press mic button triggers recording | ✅ Code complete |
| Release mic button stops recording | ✅ Code complete |
| Transcription appears with animation | ✅ AnimatedSwitcher in TranscriptionDisplay |
| Copy button copies to clipboard | ✅ Clipboard.setData in TranscriptionDisplay |
| Connection status visible on screen | ✅ StatusIndicator with 7 states |
| Language toggle switches zh/en | ✅ SegmentedButton in LanguageToggle |
| APK builds successfully | ⏳ Pending Flutter SDK |
| minSdk = 24 (Android 7.0+) | ✅ Configured |
| RECORD_AUDIO + INTERNET permissions | ✅ AndroidManifest.xml |

---

## Known Gaps

1. **Flutter SDK not installed** — APK build requires Flutter SDK. Run `brew install --cask flutter` first.
2. **Server IP not configured** — Replace `{SERVER_IP}` in `lib/core/config/api_config.dart` with actual server address.
3. **Launcher icon** — `ic_launcher` not yet added. For MVP, uses default Flutter icon.
4. **Dark mode** — App uses light theme only. Dark mode support can be added in future.
