# FIX: Codemagic Android split-per-abi APKs only

## Summary

`android-apk` workflow now builds with `flutter build apk --release --split-per-abi` and publishes only per-ABI artifacts. Fat `app-release.apk` / non-ABI `FocuBili-android-latest.apk` are no longer release artifacts.

## Changes (`codemagic.yaml`)

1. **Build**: `--split-per-abi` with `BUILD_NAME` (default `1.2.${PROJECT_BUILD_NUMBER}`) and `PROJECT_BUILD_NUMBER`.
2. **Package loop** for:
   - `app-armeabi-v7a-release.apk`
   - `app-arm64-v8a-release.apk`
   - `app-x86_64-release.apk`
3. **Renamed outputs**:
   - `FocuBili-android-${abi}-b${PROJECT_BUILD_NUMBER}.apk` (+ `.sha256`)
   - `FocuBili-android-${abi}-latest.apk` (+ `.sha256`)
4. **artifacts**: only `codemagic-artifacts/FocuBili-android-*.apk` and matching sha256; removed `build/app/outputs/flutter-apk/*.apk` glob (avoids accidental fat APK pickup).
5. Header comments updated for multi-ABI / no fat.

## Branch / commit

- Branch: `feat/android-codemagic-split-apk`
- Message: `ci(codemagic): build Android split-per-abi APKs only`
