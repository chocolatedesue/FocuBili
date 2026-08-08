# Playback backend selection

FocuBili keeps a single `PlaybackService` surface (see
`lib/services/native_playback_service.dart`) and selects the concrete backend
via `createPlaybackService()` in `lib/services/playback_service_factory.dart`.

## Current (Wave 3 wire-up)

| Platform | Backend | Notes |
|----------|---------|--------|
| Linux / Windows / macOS | `MediaKitPlaybackService` | media_kit / libmpv; `PlayerVideoSurface` embeds `VideoController` |
| Android | `NativePlaybackService` | Media3 via MethodChannel + Flutter `Texture` |
| iOS / other / web guard | `NativePlaybackService` | Channel is Android-oriented today |
| Unit tests | Injected fake preferred | VM on Linux gets `MediaKitPlaybackService` if factory is used |

Desktop focus follow-watch timing depends on a real `isPlaying` / phase stream
from media_kit; that is why desktop defaults move off the Android-only channel.

`PlayerPage` defaults to `widget.playbackService ?? createPlaybackService()`.
After `initialize()`, if the service `is MediaKitSurfaceHost`, the page passes
`host.videoController` into `PlayerVideoSurface`.

## Related contracts

Defined in `lib/services/playback_contracts.dart`:

| Contract | Responsibility |
|----------|----------------|
| `BilibiliPlayUrlClient` → `PlayUrlManifest` | Dart playurl / DASH select |
| `CookieHeaderProvider` | Cookie header for playurl / media HTTP |
| `PlayerVideoSurface` (feature UI) | Texture vs media_kit `Video` widget |
| `MediaKitPlaybackService` | Implements `PlaybackService` + `MediaKitSurfaceHost` |

## Dependencies

Pinned in `pubspec.yaml`:

- `media_kit` ^1.2.6
- `media_kit_video` ^2.0.1
- `media_kit_libs_video` ^1.0.7

`MediaKit.ensureInitialized()` is called from `lib/main.dart` after
`WidgetsFlutterBinding.ensureInitialized()`. Unit tests do not invoke `main()`,
so they do not require native media_kit libs unless a test constructs a live Player
without a fake `MediaKitHostFactory`.

## Factory API

```dart
PlaybackService createPlaybackService();
```

Branching (simplified):

```dart
if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
  return MediaKitPlaybackService();
}
return NativePlaybackService();
```

## Residual risks

- **libmpv on Linux**: desktop packages need `media_kit_libs_video` / system mpv
  available; CI unit tests avoid live Player via fakes.
- **Login / cookie**: desktop playback still needs a valid cookie path for
  many streams; public trial may work with empty cookie depending on CDN.
- **EDL dual-track**: DASH video+audio uses mpv `edl://`; no automatic
  video-only fallback yet if EDL fails.
- **Android**: unchanged Media3 path; dual-backend optional later.
