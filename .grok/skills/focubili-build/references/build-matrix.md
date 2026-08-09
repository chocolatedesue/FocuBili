# FocuBili build matrix (quick reference)

## Channels

| Platform | Primary CI | Workflow ID / name | Free-tier note |
|----------|------------|--------------------|----------------|
| Android | Codemagic | `android-apk` | OK on `mac_mini_m2` |
| macOS | Codemagic | `macos-build` | OK on `mac_mini_m2`, often unsigned |
| Windows | GitHub Actions | `Windows Build` | Preferred |
| Windows | Codemagic | `windows-build` | Needs `windows_x2` (often paid) |

## Android artifacts (release)

| ABI | Local output | Release name pattern |
|-----|--------------|----------------------|
| arm64-v8a | `app-arm64-v8a-release.apk` | `FocuBili-vX.Y.Z-android-arm64-v8a.apk` |
| armeabi-v7a | `app-armeabi-v7a-release.apk` | `FocuBili-vX.Y.Z-android-armeabi-v7a.apk` |
| x86_64 | `app-x86_64-release.apk` | `FocuBili-vX.Y.Z-android-x86_64.apk` |

**Do not ship** `app-release.apk` / `FocuBili-*-android.apk` fat as the main asset.

Codemagic intermediate names:

- `FocuBili-android-{abi}-b{N}.apk`
- `FocuBili-android-{abi}-latest.apk`

## Commands

```bash
# Local Android
flutter build apk --release --split-per-abi

# Codemagic trigger
APP_ID=6a769232581b36b2411fd1e6
curl -sS -X POST https://api.codemagic.io/builds \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $CM_TOKEN" \
  -d "{\"appId\":\"$APP_ID\",\"workflowId\":\"android-apk\",\"branch\":\"master\"}"

# GHA Windows
gh workflow run "Windows Build" -R chocolatedesue/FocuBili --ref master

# Scripts
./scripts/fetch_codemagic_android_split.sh <buildId> ./dist/android 1.2.1
./scripts/download_release.sh v1.2.1 ./dist arm64
./scripts/publish_github_release.sh v1.2.1 ./dist --notes-file docs/RELEASE_NOTES_v1.2.1.md
```

## Playback backend (build-time relevance)

| OS | Default `PlaybackService` |
|----|---------------------------|
| Android | MediaKit |
| Windows / macOS / Linux | MediaKit |
| iOS | Native (not media_kit in this project) |

media_kit pulls native libs → split APKs matter for size.

## IDs

- GitHub repo: `chocolatedesue/FocuBili`
- Codemagic appId: `6a769232581b36b2411fd1e6`
- Latest public tag example: `v1.2.1`
