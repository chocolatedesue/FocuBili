# REPORT_COOKIE (Wave 1-B)

**Agent:** COOKIE  
**Branch:** `feat/playback-cookie`  
**Date:** 2026-08-08  
**Status:** Complete

## Summary

Implemented `CookieHeaderProvider` concrete types and `createCookieHeaderProvider()` without touching auth service body, playurl, player UI, or pubspec.

- **Prefs** path for desktop paste-login persistence (`focubili_bili_cookie_header`).
- **Channel** path wrapping existing `com.focubili.app/auth` methods discovered from `BilibiliCookieController.kt` / `PlatformBilibiliCookieStore`.
- **Memory** helper for tests and non-persistent injection.
- Factory: Android → channel; other platforms (incl. desktop io) → prefs.

## Files changed

| Path | Action |
|------|--------|
| `lib/services/cookie_header_provider.dart` | **New** — Memory / Prefs / Channel + factory |
| `test/cookie_header_provider_test.dart` | **New** — unit tests |
| `docs/agent-reports/REPORT_COOKIE.md` | **New** — this report |

**Not modified:** `playback_contracts.dart`, `bilibili_auth_service.dart`, `pubspec.yaml`, Kotlin, player/focus.

## API

Implements contract from `lib/services/playback_contracts.dart`:

```dart
abstract interface class CookieHeaderProvider {
  Future<String> readCookieHeader();
  Future<void> replaceCookies(String cookieHeader);
  Future<void> clear();
}
```

### Implementations

| Class | Storage | Notes |
|-------|---------|--------|
| `MemoryCookieHeaderProvider` | in-memory | tests / DI |
| `PrefsCookieHeaderProvider` | SharedPreferences key `focubili_bili_cookie_header` | trim on read/write; empty replace removes key |
| `ChannelCookieHeaderProvider` | MethodChannel `com.focubili.app/auth` | `readCookies`, `replaceCookies`+`cookie`, `clearBilibiliCookies` |

### Factory choice

```dart
CookieHeaderProvider createCookieHeaderProvider() {
  if (!kIsWeb && Platform.isAndroid) {
    return const ChannelCookieHeaderProvider();
  }
  return const PrefsCookieHeaderProvider();
}
```

**Rationale:** Channel methods are solid (Kotlin + existing Dart store). Android uses WebView jar via channel so login UI and playurl share one session. Desktop has no WebView cookie bridge in this wave → prefs paste path.

**WIRE TODO (optional):** If desktop later gets a unified auth bridge, swap factory branch only. No Android prefs fallback needed unless channel is unavailable in a future embedder.

## Channel method map (read-only discovery)

From `android/.../BilibiliCookieController.kt`:

| Flutter method | Behavior |
|----------------|----------|
| `readCookies` | joined `name=value; ...` |
| `setCookies` / `replaceCookies` | require SESSDATA; replace bilibili-domain cookies |
| `clearCookies` / `clearBilibiliCookies` | expire bilibili cookies only |

Dart wrapper uses `readCookies` / `replaceCookies` / `clearBilibiliCookies` to match `PlatformBilibiliCookieStore`.

## Test / analyze

Environment:

```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

| Command | Result |
|---------|--------|
| `flutter analyze lib/services/cookie_header_provider.dart test/cookie_header_provider_test.dart` | **No issues found** |
| `flutter test test/cookie_header_provider_test.dart` | **All tests passed** (`+8`) |

## Non-goals

- Editing `bilibili_auth_service.dart`
- Wiring playurl / media_kit / player_page to the provider (W2/W3)
- SESSDATA validation on prefs path (desktop paste trusts caller; Android channel validates natively)
