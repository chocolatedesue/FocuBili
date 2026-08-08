# REPORT_FOUNDATION (Wave 0)

**Agent:** FOUNDATION  
**Branch:** `feat/playback-foundation`  
**Date:** 2026-08-08  
**Status:** Complete — gate open for parallel W1

## Summary

Wave 0 foundation for media_kit playback migration:

- Added pub.dev media_kit dependencies (resolved cleanly on Flutter 3.44.9 / Dart 3.12.2).
- Called `MediaKit.ensureInitialized()` from app `main()` only (tests do not call `main()`).
- Introduced playback contracts + factory that still returns `NativePlaybackService` (behavior unchanged).
- Documented backend selection for W1–W3.

No `MediaKitPlaybackService` implementation, no `player_page` rewrite, no Kotlin changes.

## Files changed

| Path | Action |
|------|--------|
| `pubspec.yaml` | Modified — media_kit deps |
| `pubspec.lock` | Modified — lockfile after `flutter pub get` |
| `lib/main.dart` | Modified — `MediaKit.ensureInitialized()` after binding |
| `lib/services/playback_contracts.dart` | **New** — `PlayUrlManifest`, `BilibiliPlayUrlClient`, `CookieHeaderProvider` |
| `lib/services/playback_service_factory.dart` | **New** — `createPlaybackService()` → native |
| `docs/PLAYBACK_BACKEND.md` | **New** — backend matrix & wave map |
| `docs/agent-reports/REPORT_FOUNDATION.md` | **New** — this report |
| `test/playback_service_factory_test.dart` | **New** — factory + manifest smoke tests |

## Dependency versions

Declared in `pubspec.yaml` (pub.dev stable):

| Package | Constraint | Resolved (`pubspec.lock`) |
|---------|------------|---------------------------|
| `media_kit` | `^1.2.6` | `1.2.6` |
| `media_kit_video` | `^2.0.1` | `2.0.1` |
| `media_kit_libs_video` | `^1.0.7` | `1.0.7` |

Transitive libs pulled by `media_kit_libs_video` (lock):  
`media_kit_libs_android_video 1.3.8`, `media_kit_libs_ios_video 1.1.4`, `media_kit_libs_linux 1.2.1`, `media_kit_libs_macos_video 1.1.4`, `media_kit_libs_windows_video 1.0.11`.

Resolve used China mirrors:

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

No version bumps required beyond the documented stable set.

## Contracts (for W1)

### `PlayUrlManifest` (`playback_contracts.dart`)

- `videoUrl` (required)
- `audioUrl` (optional DASH audio)
- `quality` (int)
- `qualities` → `List<PlaybackQuality>` (reuses type from `native_playback_service.dart`)
- `httpHeaders` → `Map<String, String>` (Referer / UA)

### `BilibiliPlayUrlClient`

```dart
Future<PlayUrlManifest> fetch({
  required String bvid,
  required int cid,
  int quality = 64,
  String cookieHeader = '',
});
```

### `CookieHeaderProvider`

```dart
Future<String> readCookieHeader();
Future<void> replaceCookies(String cookieHeader);
Future<void> clear();
```

No `createCookieHeaderProvider` / `createPlayUrlClient` stubs in the factory (interfaces only until W1-A/B own those files).

### `createPlaybackService()`

Always returns `NativePlaybackService()` on all platforms. W3 will branch desktop → media_kit.

## Test / analyze results

| Command | Result |
|---------|--------|
| `flutter pub get` | OK (14 packages added) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **All tests passed** (`+258`) |
| `test/playback_service_factory_test.dart` | 2/2 passed (requires `TestWidgetsFlutterBinding` because `NativePlaybackService` registers a MethodChannel) |

## Explicit non-goals (not done)

- Full `MediaKitPlaybackService`
- Wiring `player_page.dart` to the factory (still constructs `NativePlaybackService()` directly — W3/SURFACE)
- Playurl / cookie implementations
- Kotlin / focus feature edits
- Copying from `/tmp/PiliPlus`

## Blockers / notes for W1

| Wave | Owner files | Notes / deps on FOUNDATION |
|------|-------------|----------------------------|
| **W1-A PLAYURL** | `lib/services/bilibili_playurl_service.dart`, tests | Implement `BilibiliPlayUrlClient`; return `PlayUrlManifest`. Import contracts; reuse `bilibili_request_policy.dart` for UA/Referer. Do **not** edit `pubspec.yaml` or `main.dart`. |
| **W1-B COOKIE** | `cookie_header_provider.dart` (+ prefs/channel impls), tests | Implement `CookieHeaderProvider` (`read` / `replace` / `clear`). Factory `createCookieHeaderProvider()` lives in W1-B ownership. Do **not** edit contracts file unless a bug is found — prefer extending in own files. |
| **W1-C SURFACE** | `player_video_surface.dart`, minimal `player_page` texture swap | Can land without media_kit service; keep Texture path for native. media_kit `Video` path can accept a controller type once W2 exists — design API so W2 can plug in without rewriting page again. |

### No hard blockers

- Contracts are stable and importable.
- media_kit is on the dependency graph; W2 can `import package:media_kit/...` immediately after W1-A/B.
- Factory not yet used by `PlayerPage` — intentional until W3 wire. W1-C may introduce surface abstraction without calling factory.

### Soft risks for later waves

1. **Linux CI / desktop builds** may need system mpv/libmpv packages for `media_kit_libs_linux` at runtime (not required for unit tests that avoid constructing `Player`).
2. **`NativePlaybackService` constructor** requires Flutter binding (MethodChannel). Factory tests must call `TestWidgetsFlutterBinding.ensureInitialized()`.
3. **Dual ownership of surface + service**: SURFACE should expose how media_kit embeds video (e.g. optional `VideoController` / widget builder) without depending on unfinished W2 class names if possible — document the expected hook in SURFACE report.
4. **Cookie + playurl composition** happens in W2 (`MediaKitPlaybackService`), not W1: W1-A takes `cookieHeader` string; W1-B only stores/reads it.

## Recommended merge / next step

1. Review + merge `feat/playback-foundation` into integration branch.
2. Launch W1-A, W1-B, W1-C in parallel (worktrees), each limited to ownership globs in `docs/PLAN_MEDIA_KIT_PLAYBACK.md`.
