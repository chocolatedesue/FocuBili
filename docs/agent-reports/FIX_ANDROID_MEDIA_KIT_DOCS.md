# FIX_ANDROID_MEDIA_KIT_DOCS — Android media_kit default + split ABI packaging docs

**Branch:** `feat/android-mediakit-docs`  
**Date:** 2026-08-08  
**Agent:** D-DOCS  
**Plan:** [`docs/PLAN_ANDROID_MEDIA_KIT.md`](../PLAN_ANDROID_MEDIA_KIT.md)

## Summary

Documented the product/docs target for:

1. **Android default playback** → `MediaKitPlaybackService` (shared experimental media_kit stack with desktop).
2. **Native Media3** retained in-tree for injection / debug fallback (not deleted).
3. **Release packaging** → ABI split APKs only; **no fat** `app-release.apk` as a publish artifact.
4. Explicitly **no iOS media_kit** claim.

## Files touched (ownership only)

| Path | Change |
|------|--------|
| `docs/PLAYBACK_BACKEND.md` | Android row → MediaKit default; Native retention; factory snippet; risks (APK size, Android-native features on mk path); plan link; iOS not mk |
| `docs/CODEMAGIC.md` | Split-per-abi product names; no fat; which ABI to install (arm64-v8a primary); local/CM commands; playback table Android→media_kit |
| `README.md` | v1.2.1 notes, player section, limits, download ABI guide, local build `--split-per-abi`, CM table, backend callout |
| `docs/agent-reports/FIX_ANDROID_MEDIA_KIT_DOCS.md` | This report |

**Not touched:** `lib/**`, `codemagic.yaml`, `android/**`, `docs/DESKTOP.md` (cross-link already sufficient via PLAYBACK_BACKEND / CODEMAGIC).

## Key claims (for merge consistency)

- Default factory: Desktop + **Android** → `MediaKitPlaybackService`; iOS/other → `NativePlaybackService`.
- Artifacts: `FocuBili-android-{armeabi-v7a|arm64-v8a|x86_64}-bN.apk` (+ optional `-latest` / `.sha256`).
- Users: prefer **arm64-v8a** on most phones.
- Docs describe **target** aligned with plan; code/yaml may land from A-FACTORY / B-GRADLE / C-CM in the same merge wave.

## Commit message

```
docs: Android media_kit default and split ABI packaging
```
