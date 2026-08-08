# REPORT_WIRE (Wave 3)

**Agent:** WIRE  
**Branch:** `feat/playback-wire`  
**Date:** 2026-08-08  
**Status:** Complete

## Summary

Wired desktop media_kit into the app factory and `PlayerPage` surface path:

1. `createPlaybackService()` → `MediaKitPlaybackService` on Windows/Linux/macOS; `NativePlaybackService` elsewhere.
2. `PlayerPage` defaults to `createPlaybackService()`; after `initialize()`, if `MediaKitSurfaceHost`, stores `videoController` and passes it to `PlayerVideoSurface`.
3. Focus continues to listen to `PlaybackService.states` (unchanged state machine).
4. Docs: `PLAYBACK_BACKEND.md` current matrix; README one-line desktop note.

## Platform matrix

| Platform | Backend | Surface |
|----------|---------|---------|
| Linux / Windows / macOS | `MediaKitPlaybackService` | `PlayerVideoSurface(videoController: …)` (`textureId` null) |
| Android | `NativePlaybackService` | `PlayerVideoSurface(textureId: …)` |
| iOS / other | `NativePlaybackService` | Texture path (channel Android-oriented) |
| Unit tests (injected) | Fake / explicit service | Unchanged |
| VM factory test (Linux) | Expects `MediaKitPlaybackService` | N/A |

## Files

| Path | Action |
|------|--------|
| `lib/services/playback_service_factory.dart` | Real platform branch |
| `lib/features/player/player_page.dart` | Minimal: factory + controller + surface args |
| `test/playback_service_factory_test.dart` | Desktop → MediaKit expectation |
| `docs/PLAYBACK_BACKEND.md` | Wave 3 current state |
| `README.md` | Desktop media_kit experimental note |
| `docs/agent-reports/REPORT_WIRE.md` | This report |

**Not touched:** Android Kotlin Media3, focus timer state machine, playurl/cookie/mediakit service implementations, `main.dart` (already has `MediaKit.ensureInitialized()`).

## PlayerPage diff (minimal)

- Imports: `playback_service_factory.dart`, `playback_service_media_kit_ext.dart`
- State: `Object? _mediaKitVideoController`
- `initState`: `_playbackService = widget.playbackService ?? createPlaybackService()`
- `_initializeNativePlayback`: after `initialize()`, if `is MediaKitSurfaceHost`, set controller from host
- `_buildVideoOutput`: show surface when `textureId != null || mediaKitController != null`; pass both into `PlayerVideoSurface`

## Testing

```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter analyze   # No issues found
flutter test      # All tests passed
```

| Command | Result |
|---------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **299/299 passed** |

Includes `focus_timer_controller_test`, factory, media_kit service (fakes), player surface, and full widget suite. Live libmpv Player is not required in unit tests (media_kit service tests inject `MediaKitHostFactory`).

## Residual risks

1. **libmpv on Linux desktop builds** — runtime needs `media_kit_libs_video` / packaged mpv; CI unit tests do not exercise live Player.
2. **Login / cookie still separate** — many CDN URLs need cookie; desktop prefs/channel providers exist but end-to-end login UX is not part of this wire.
3. **EDL dual-track** — no automatic video-only fallback if `edl://` open fails (documented in MEDIAKIT report).
4. **iOS** — still factory-native; no Media3 parity claimed.
5. **Factory constructs real `MediaKitPlaybackService` on Linux VM** — constructor does not open Player until `initialize()`; factory test only constructs + `dispose`.

## Explicit non-goals (not done)

- Kotlin Media3 changes
- Focus state machine rewrite
- EDL fallback / screenshot JPEG path
- Force dual media_kit on Android
