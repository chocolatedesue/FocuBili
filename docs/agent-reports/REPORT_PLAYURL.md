# REPORT_PLAYURL (Wave 1-A)

**Agent:** PLAYURL  
**Branch:** `feat/playback-playurl`  
**Date:** 2026-08-08  
**Status:** Complete — ready for MEDIAKIT_SVC consumption

## Summary

Implemented Dart UGC playurl client that mirrors native `NativePlaybackController` DASH selection:

- `GET https://api.bilibili.com/x/player/playurl` with `qn` / `fnval=16` / `fourk=1`
- Desktop Chrome UA + video-page Referer (same style as Kotlin / `bilibili_service`)
- Cookie **only** via `fetch(cookieHeader: ...)`
- DASH video/audio track pick + quality menu → `PlayUrlManifest` from `playback_contracts.dart`
- No new model file; no GPL paste; no live network in tests

## Files

| Path | Action |
|------|--------|
| `lib/services/bilibili_playurl_service.dart` | **New** — `BilibiliPlayUrlService` + helpers |
| `test/bilibili_playurl_service_test.dart` | **New** — fixture JSON unit tests |
| `docs/agent-reports/REPORT_PLAYURL.md` | **New** — this report |

**Not touched:** `pubspec.yaml`, `main.dart`, `player_page.dart`, focus/*, android/**, cookie providers, media_kit service, factory.

**Reused (import only):**

- `PlayUrlManifest` / `BilibiliPlayUrlClient` → `lib/services/playback_contracts.dart`
- `PlaybackQuality` → `lib/services/native_playback_service.dart`
- UA/Referer habits → `BilibiliRequestPolicy` + desktop UA constant aligned with Kotlin / `bilibili_service`

## Quality / track selection

Aligned with Kotlin `loadPlaybackSources` + `selectMediaTrack` + `PlaybackTrackPolicy`:

1. **Actual quality** = `data.quality` if `> 0`, else requested `qn` (default **64**).
2. **Video track score** (higher wins):
   - `+1e12` if `id == actualQuality`
   - codec bonus (only when selecting with preferred id): AVC `avc1`/`avc3` ≫ HEVC `hev1`/`hvc1` ≫ other (AV1 etc. = 0)
   - `height * 1e6` + `bandwidth`
3. **Audio track**: same scorer **without** preferred id → highest height/bandwidth (typically best audio).
4. **URLs**: `base_url`/`baseUrl` + `backup_url`/`backupUrl`; only `https://*.bilivideo.com|*.bilivideo.cn`.
5. **Manifest**: first safe video URL; first safe audio URL or `null`; `qualities` from `accept_quality`+`accept_description`, else unique `dash.video` ids, ensure current quality present, sort id descending.
6. **httpHeaders** for media open: `Accept */*`, `Accept-Encoding: identity`, `Origin`, `Referer` (video page), `User-Agent`, optional `Cookie`.

Fallback labels: 127/120/116/112/80/64/32/16 → 中文档名（与原生一致）.

## API surface for MEDIAKIT_SVC

```dart
final client = BilibiliPlayUrlService(); // or inject PlayUrlJsonRequest for tests
final PlayUrlManifest m = await client.fetch(
  bvid: bvid,
  cid: cid,
  quality: 64,
  cookieHeader: await cookieProvider.readCookieHeader(),
);
// m.videoUrl, m.audioUrl?, m.quality, m.qualities, m.httpHeaders
```

Injectable `PlayUrlJsonRequest` for tests / offline.

Static helpers usable without I/O: `parsePlayUrlResponse`, `isSafeMediaUrl`, `compatibilityScore`, `buildPlayUrlEndpoint`, `buildMediaHttpHeaders`.

Errors: `BilibiliPlayUrlException` with user-facing Chinese messages.

## Test results

```text
flutter analyze lib/services/bilibili_playurl_service.dart test/bilibili_playurl_service_test.dart
→ No issues found

flutter test test/bilibili_playurl_service_test.dart
→ 00:00 +13: All tests passed!
```

Coverage highlights:

- DASH success → 64 AVC + top audio
- Cookie on request + media headers only when provided
- qn 80 prefers AVC over HEVC same id
- accept_quality missing → derive from dash.video + camelCase URL keys
- invalid BV / cid / API code / no dash / unsafe CDN URLs

## Blockers / notes for MEDIAKIT_SVC

| Item | Notes |
|------|--------|
| Cookie | PLAYURL does not read WebView/prefs; **must** pass `cookieHeader` from W1-B `CookieHeaderProvider` or higher-qn DASH may fail / degrade. |
| Audio | Separate DASH audio URL — media_kit must open **video + audio** (or merge); null audio is rare but possible. |
| Backup URLs | Manifest exposes **primary only**; native rotates backups on 403/404. MEDIAKIT may need retry/`parse` again or extend client later for full URL lists. |
| Non-DASH | No `durl`/FLV path — only DASH (`fnval=16`). Old formats throw. |
| WBI / appkey | UGC web playurl as native; no WBI sign. If API tightens, revisit. |
| PGC/bangumi | Not implemented (UGC `bvid`+`cid` only). |
| Factory | Not wired; WIRE/MEDIAKIT constructs `BilibiliPlayUrlService` + cookie provider. |
| Live network | Default `HttpClient` path untested in CI by design; smoke on device/desktop when wiring. |

## Git

Branch: `feat/playback-playurl`  
Commit: see `git log -1` on this branch after push of this report.
