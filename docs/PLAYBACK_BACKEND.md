# Playback backend selection

FocuBili keeps a single `PlaybackService` surface (see
`lib/services/native_playback_service.dart`) and selects the concrete backend
via `createPlaybackService()` in `lib/services/playback_service_factory.dart`.

**End-user install:** [GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)  
**Desktop user guide (中文):** [`DESKTOP.md`](DESKTOP.md)  
**Cloud builds:** [`CODEMAGIC.md`](CODEMAGIC.md)

## Current

| Platform | Backend | Notes |
|----------|---------|--------|
| Linux / Windows / macOS | `MediaKitPlaybackService` | **Experimental** media_kit / libmpv — real playback, not a compile-only shell; `PlayerVideoSurface` embeds `VideoController` |
| Android | `NativePlaybackService` | Media3 via MethodChannel + Flutter `Texture` (primary mobile path) |
| iOS / other / web guard | `NativePlaybackService` | Channel is Android-oriented today |
| Unit tests | Injected fake preferred | VM on Linux gets `MediaKitPlaybackService` if factory is used |

Desktop focus follow-watch timing depends on a real `isPlaying` / phase stream
from media_kit; that is why desktop defaults move off the Android-only channel.

`PlayerPage` defaults to `widget.playbackService ?? createPlaybackService()`.
After `initialize()`, if the service `is MediaKitSurfaceHost`, the page passes
`host.videoController` into `PlayerVideoSurface`.

## Auth cookie (desktop = playback)

Desktop login and playurl / media HTTP share one SharedPreferences key:

| Symbol | Value |
|--------|--------|
| `kFocubiliBiliCookieHeaderPrefsKey` | `'focubili_bili_cookie_header'` |

- Playback: `createCookieHeaderProvider()` → `PrefsCookieHeaderProvider` on desktop.
- Auth: `createDefaultBilibiliCookieStore()` → `PrefsBilibiliCookieStore` on non-Android (same key).
- Android still uses the WebView / platform cookie channel for the primary path.
- **Cookie paste** is the reliable desktop login path (especially Windows, where official WebView login is unavailable).

Paste once in the login UI; the same header is used for media requests that need a session.

## History resume

Opening a watch-history entry goes through `WatchHistoryLauncher`, which builds
`PlayerRouteArgs` (part CID when resolved, initial position, source label
`PlayerInitialPositionSource.history`) instead of a bare `VideoPreview`.

- Home wide layout and the full history page both call the launcher.
- Router accepts `PlayerRouteArgs` while remaining backward-compatible with plain previews.
- Part resolution prefers page number then title; if CID cannot be resolved, position may still be applied on the default part (see residual risks / product notes).

## Focus timer vs buffering

Focus “actually playing” is **not** limited to `phase == ready`.

- Helper: `isFocusPlaybackActuallyPlaying(PlaybackSnapshot)` on the player page.
- Counts as playing when `isPlaying == true` and phase is **`ready` or `loading`**.
- Still not playing for `!isPlaying`, `ended`, `error`, `idle`.
- Prevents normal rebuffer (media_kit often keeps `isPlaying` while phase flips to `loading`) from pausing the focus timer via `FocusPauseReason.playback`.
- Seek still has its own short grace (`_focusSeekTransitionActive`).

## Related contracts

Defined in `lib/services/playback_contracts.dart` (and related modules):

| Contract | Responsibility |
|----------|----------------|
| `BilibiliPlayUrlClient` → `PlayUrlManifest` | Dart playurl / DASH select |
| `CookieHeaderProvider` | Cookie header for playurl / media HTTP |
| `PlayerVideoSurface` (feature UI) | Texture vs media_kit `Video` widget |
| `MediaKitPlaybackService` | Implements `PlaybackService` + `MediaKitSurfaceHost` |
| `PlayerRouteArgs` / `WatchHistoryLauncher` | History → player resume args |

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

- **Experimental desktop playback**: libmpv path; codecs / EDL dual-track behavior may change. DASH video+audio uses mpv `edl://`; no automatic video-only fallback yet if EDL fails.
- **libmpv on Linux**: packages need `media_kit_libs_video` / system mpv; CI unit tests avoid live Player via fakes.
- **Cookie still required for many streams**: public trial may work with empty cookie depending on CDN; higher qualities often need a valid session.
- **Public content service vs prefs cookie**: `BilibiliHttpPublicContentService` may still default to `PlatformBilibiliCookieStore` rather than the desktop prefs key — account-ish public APIs can diverge from the playback cookie path until unified.
- **macOS unsigned**: Codemagic / Release macOS zips are typically **not** Apple-notarized; Gatekeeper may block first launch (see [`DESKTOP.md`](DESKTOP.md)).
- **Android-only features**: system alarm / DND / progressive download cache are not 1:1 on desktop.
- **History part mismatch**: if page/title cannot resolve CID, resume may seek on the wrong part without a strong user warning.
- **Android**: unchanged Media3 path; dual-backend optional later.
