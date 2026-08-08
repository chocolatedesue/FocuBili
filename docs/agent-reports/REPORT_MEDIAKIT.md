# REPORT_MEDIAKIT (Wave 2)

**Agent:** MEDIAKIT_SVC  
**Branch:** `feat/playback-mediakit`  
**Date:** 2026-08-08  
**Status:** Complete — ready for W3 WIRE

## Summary

Implemented `MediaKitPlaybackService` as a full `PlaybackService` + `MediaKitSurfaceHost`:

- Injects `BilibiliPlayUrlClient` + `CookieHeaderProvider` (defaults to real impls).
- `initialize()` creates media_kit `Player` + `VideoController`; **textureId is always `null`** (desktop uses Widget surface).
- `openVideo()` → cookie → playurl fetch → `player.open(Media(...))` with `manifest.httpHeaders`.
- Player streams mapped to `PlaybackSnapshot` (phase / isPlaying / position / duration / speed / qualities / aspect).
- Transport: play / pause / seekBy / seekTo / setPlaybackSpeed / selectQuality (re-fetch + position restore) / dispose.
- Desktop stubs: prefs saved state, default brightness/volume, volume → player, PiP false, capture null.
- Unit tests use injectable `MediaKitPlayerHost` fake (no GUI / no libmpv required).

## Files (ownership only)

| Path | Action |
|------|--------|
| `lib/services/media_kit_playback_service.dart` | **New** — service + helpers + host abstraction |
| `lib/services/playback_service_media_kit_ext.dart` | **New** — `MediaKitSurfaceHost` |
| `test/media_kit_playback_service_test.dart` | **New** — helpers + service tests with fake host |
| `docs/agent-reports/REPORT_MEDIAKIT.md` | **New** — this report |

**Not touched:** `pubspec.yaml`, `player_page.dart`, focus/*, android/**, playurl/cookie implementations.

## Dual-track (video + audio) status

| Case | Behavior |
|------|----------|
| `manifest.audioUrl != null` | **Supported:** open mpv **`edl://` multi-stream** URI (`!new_stream` length-prefixed video + audio). Same EDL idea used by libmpv DASH clients; **not** a paste of PiliPlus sources. |
| `manifest.audioUrl == null` | Plain `Media(videoUrl)` (video-only / muxed). |
| HTTP headers | `Media(..., httpHeaders: manifest.httpHeaders)` (Referer / UA / Cookie from playurl service). |
| `AudioTrack.uri` alternative | **Not used** as primary path: external audio-add does not cleanly attach the same HTTP header map as `Media.httpHeaders` for bilibili CDN. EDL keeps both streams under one open with headers. |

**WARNING:** EDL dual-open depends on libmpv EDL support in `media_kit_libs_*`. If a platform fails to demux EDL, video may error — there is **no automatic video-only fallback** in this wave (could be added in W3 if needed). Code comments mark the dual-track path.

Helpers (pure, tested):

- `MediaKitPlaybackHelpers.buildDashEdlUri`
- `MediaKitPlaybackHelpers.buildPlayableResource`
- `MediaKitPlaybackHelpers.buildMedia`

## API notes for WIRE (VideoController → PlayerVideoSurface)

```dart
// factory (W3):
PlaybackService createPlaybackService() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return MediaKitPlaybackService();
  }
  return NativePlaybackService();
}

// PlayerPage:
final PlaybackService playback = widget.playbackService ?? createPlaybackService();
final int? textureId = await playback.initialize();

Object? videoController;
if (playback is MediaKitSurfaceHost) {
  videoController = playback.videoController;
}

// In build:
PlayerVideoSurface(
  textureId: textureId,
  videoController: videoController, // media_kit VideoController
);
```

- Interface: `lib/services/playback_service_media_kit_ext.dart` → `MediaKitSurfaceHost.videoController`.
- Also exposed as public getter on `MediaKitPlaybackService.videoController` (same value).
- Do **not** change `PlaybackService` method table for this; use `is MediaKitSurfaceHost`.
- `MediaKit.ensureInitialized()` already called from `main.dart` (FOUNDATION).

## Testing

```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter analyze lib/services/media_kit_playback_service.dart \
  lib/services/playback_service_media_kit_ext.dart
flutter test test/media_kit_playback_service_test.dart
```

Coverage:

- EDL / plain resource builders + header attachment
- Snapshot event mapping (playing, buffering, completed, position, size, error)
- `openVideo` calls playurl with cookie and opens media
- play/pause/seek/speed/selectQuality
- saved state restore
- desktop stubs

## Blockers / follow-ups for W3

1. Wire factory + PlayerPage controller pass-through (above).
2. Optional: automatic fallback to video-only if EDL open errors.
3. Optional: `captureCurrentFrame` write JPEG from `player.screenshot()` via path_provider.
4. Real device / desktop smoke play not required in this wave.
