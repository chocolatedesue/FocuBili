# A-FACTORY: Android default → MediaKit

## Change
- `createPlaybackService()` now routes **Android** to `MediaKitPlaybackService` (same as desktop).
- iOS / Web / unknown stay on `NativePlaybackService`.
- Extracted `@visibleForTesting` `createPlaybackServiceForTargets(...)` pure function so VM tests cover Android without faking `Platform`.

## Files
- `lib/services/playback_service_factory.dart`
- `test/playback_service_factory_test.dart`

## Verify
```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter test test/playback_service_factory_test.dart
flutter analyze lib/services/playback_service_factory.dart
```
