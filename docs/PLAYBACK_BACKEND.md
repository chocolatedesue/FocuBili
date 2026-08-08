# Playback backend selection

FocuBili keeps a single `PlaybackService` surface (see
`lib/services/native_playback_service.dart`) and selects the concrete backend
via `createPlaybackService()` in `lib/services/playback_service_factory.dart`.

**End-user install:** [GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)  
**Desktop user guide (中文):** [`DESKTOP.md`](DESKTOP.md)  
**Cloud builds:** [`CODEMAGIC.md`](CODEMAGIC.md)  
**Android media_kit + ABI split plan:** [`PLAN_ANDROID_MEDIA_KIT.md`](PLAN_ANDROID_MEDIA_KIT.md)

## Current

| Platform | Backend | Notes |
|----------|---------|--------|
| Linux / Windows / macOS | `MediaKitPlaybackService` | **Experimental** media_kit / libmpv — real playback, not a compile-only shell; `PlayerVideoSurface` embeds `VideoController` |
| **Android** | **`MediaKitPlaybackService` (default)** | Same experimental media_kit / libmpv stack as desktop (shared path). `NativePlaybackService` (Media3 + MethodChannel + Flutter `Texture`) stays in-tree for injection / debug fallback |
| iOS / other / web guard | `NativePlaybackService` | Channel is Android-oriented today; **iOS is not on media_kit** in this plan |
| Unit tests | Injected fake preferred | VM on Linux gets `MediaKitPlaybackService` if factory is used |

Android and desktop focus follow-watch timing both depend on a real `isPlaying` /
phase stream from media_kit. That is why the default factory path uses media_kit
on Android as well as on desktop.

`PlayerPage` defaults to `widget.playbackService ?? createPlaybackService()`.
After `initialize()`, if the service `is MediaKitSurfaceHost`, the page passes
`host.videoController` into `PlayerVideoSurface`.

### Native retention (Android)

- Kotlin Media3 / MethodChannel code is **not** deleted in this phase.
- Call sites may still **inject** `NativePlaybackService` (tests, debug, or an
  optional env / debug switch such as `FOCUBILI_USE_NATIVE_PLAYBACK` when wired).
- Media3 Gradle deps may remain while the native path is a supported fallback.

## Auth cookie (desktop = playback)

Desktop login and playurl / media HTTP share one SharedPreferences key:

| Symbol | Value |
|--------|--------|
| `kFocubiliBiliCookieHeaderPrefsKey` | `'focubili_bili_cookie_header'` |

- Playback: `createCookieHeaderProvider()` → `PrefsCookieHeaderProvider` on desktop.
- Auth: `createDefaultBilibiliCookieStore()` → `PrefsBilibiliCookieStore` on non-Android (same key).
- Android still uses the WebView / platform cookie channel for the primary login path.
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
// Optional testable pure branch (when present):
// PlaybackService createPlaybackServiceForPlatform({required bool isAndroid, required bool isDesktop, ...});
```

Branching (simplified target):

```dart
if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
  return MediaKitPlaybackService();
}
if (!kIsWeb && Platform.isAndroid) {
  return MediaKitPlaybackService(); // default; Native retained for inject/fallback
}
return NativePlaybackService(); // iOS / other
```

## Residual risks

- **Experimental media_kit (desktop + Android default)**: libmpv path; codecs / EDL dual-track behavior may change. DASH video+audio uses mpv `edl://`; no automatic video-only fallback yet if EDL fails.
- **libmpv on Linux**: packages need `media_kit_libs_video` / system mpv; CI unit tests avoid live Player via fakes.
- **Android APK size**: media_kit native libs are large; release packaging uses **per-ABI split APKs** (no fat universal) — see [`CODEMAGIC.md`](CODEMAGIC.md). Prefer **arm64-v8a** on most phones.
- **Cookie still required for many streams**: public trial may work with empty cookie depending on CDN; higher qualities often need a valid session.
- **Public content service vs prefs cookie**: `BilibiliHttpPublicContentService` may still default to `PlatformBilibiliCookieStore` rather than the desktop prefs key — account-ish public APIs can diverge from the playback cookie path until unified.
- **macOS unsigned**: Codemagic / Release macOS zips are typically **not** Apple-notarized; Gatekeeper may block first launch (see [`DESKTOP.md`](DESKTOP.md)).
- **Android-native-only features on media_kit path**: system alarm / DND remain platform services; progressive download cache, MediaSession depth, and frame capture may be weaker or stubbed vs the old Media3 primary path (same class of limits as desktop media_kit).
- **History part mismatch**: if page/title cannot resolve CID, resume may seek on the wrong part without a strong user warning.
- **iOS**: not migrated to media_kit; still `NativePlaybackService` / channel-oriented.
