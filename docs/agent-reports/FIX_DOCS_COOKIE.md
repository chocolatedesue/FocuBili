# FIX_DOCS_COOKIE — desktop docs + auth prefs Cookie bridge

**Branch:** `feat/fix-docs-desktop-cookie`  
**Date:** 2026-08-08  
**Agent:** C-DOCS-COOKIE

## Goals

1. Align README / CODEMAGIC / `codemagic.yaml` comments with `docs/PLAYBACK_BACKEND.md` (desktop media_kit experimental; Android Media3 primary).
2. Desktop `BilibiliAuthService` default Cookie store shares prefs key with playback `CookieHeaderProvider`.
3. Login page: desktop prefers Cookie paste; hide official WebView path on Windows only.

## Code changes

### `lib/services/cookie_header_provider.dart`

Unchanged key (single source of truth):

- `kFocubiliBiliCookieHeaderPrefsKey = 'focubili_bili_cookie_header'`
- `PrefsCookieHeaderProvider` / `createCookieHeaderProvider()` already use this key on desktop.

### `lib/services/bilibili_auth_service.dart`

- Added `PrefsBilibiliCookieStore` implementing `BilibiliCookieStore`, delegating to `PrefsCookieHeaderProvider` with the **same** prefs key.
- Added `createDefaultBilibiliCookieStore()`:
  - Android → `PlatformBilibiliCookieStore`
  - desktop / else → `PrefsBilibiliCookieStore`
- `BilibiliAuthService` default store: `cookieStore ?? createDefaultBilibiliCookieStore()` (no longer hard-codes Platform only).

### `lib/features/profile/login_page.dart`

- Desktop IO defaults segmented mode to Cookie.
- Windows: do not auto-open official WebView; hide bottom “打开 B 站网页登录”; phone/password segments redirect to Cookie paste.
- Cookie copy explains desktop prefs + playback session sharing.

### Docs

- `README.md`: removed “Win/mac compile shell / Media3-only desktop” contradiction; honest experimental media_kit + Cookie notes.
- `docs/CODEMAGIC.md`: desktop capability table; Windows via GHA noted; FMP diff row updated.
- `codemagic.yaml` header: removed “until desktop playback backends are added”.

## Forbidden (not touched)

- `media_kit_playback_service.dart` open/EDL
- player_page focus / history resume
- force-push

## Tests

```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter test test/cookie_header_provider_test.dart test/bilibili_auth_service_test.dart
flutter analyze lib/services/bilibili_auth_service.dart \
  lib/services/cookie_header_provider.dart \
  lib/features/profile/login_page.dart
```

## Residual honesty

- Desktop playback remains **experimental** (libmpv).
- Some streams still need a valid Cookie.
- Windows WebView login remains limited / disabled in UI.
