# Playback backend selection

FocuBili keeps a single `PlaybackService` surface (see
`lib/services/native_playback_service.dart`) and selects the concrete backend
via `createPlaybackService()` in `lib/services/playback_service_factory.dart`.

## Current (Wave 0)

| Platform | Backend | Notes |
|----------|---------|--------|
| Android | `NativePlaybackService` | Media3 via MethodChannel |
| iOS / desktop / others | `NativePlaybackService` | Same factory path; native channel is Android-oriented today |

Behavior is intentionally unchanged from pre-migration: callers that used
`NativePlaybackService()` directly still get equivalent behavior when they
switch to `createPlaybackService()`.

## Target (Wave 3 wire-up)

| Platform | Default backend | Optional |
|----------|-----------------|----------|
| Linux / Windows / macOS | `MediaKitPlaybackService` (media_kit) | — |
| Android | `NativePlaybackService` (Media3) | media_kit dual-backend if needed |
| Tests | Injected fake / `NativePlaybackService` | Prefer constructor injection on `PlayerPage` |

Desktop focus follow-watch timing depends on a real `isPlaying` / phase stream
from media_kit; that is why desktop defaults move off the Android-only channel.

## Related contracts

Defined in `lib/services/playback_contracts.dart` (implementations land in later waves):

| Contract | Wave | Responsibility |
|----------|------|----------------|
| `BilibiliPlayUrlClient` → `PlayUrlManifest` | W1-A | Dart playurl / DASH select |
| `CookieHeaderProvider` | W1-B | Cookie header for playurl / media HTTP |
| `PlayerVideoSurface` (feature UI) | W1-C | Texture vs media_kit `Video` widget |
| `MediaKitPlaybackService` | W2 | Implements `PlaybackService` with media_kit |

## Dependencies

Pinned in `pubspec.yaml` (Wave 0):

- `media_kit` ^1.2.6
- `media_kit_video` ^2.0.1
- `media_kit_libs_video` ^1.0.7

`MediaKit.ensureInitialized()` is called from `lib/main.dart` after
`WidgetsFlutterBinding.ensureInitialized()`. Unit tests do not invoke `main()`,
so they do not require native media_kit libs unless a test constructs a Player.

## Factory API

```dart
PlaybackService createPlaybackService();
```

Cookie / playurl factories are owned by W1-B / W1-A and are not required at
Wave 0; interfaces live only in `playback_contracts.dart` until those waves.
