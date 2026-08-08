# FIX: Android ABI splits（无 universal fat APK）

## 变更

- 文件：`android/app/build.gradle`
- 在 `android { }` 内 `buildTypes` 之后启用 `splits.abi`：
  - `enable true`、`universalApk false`
  - `include "armeabi-v7a", "arm64-v8a", "x86_64"`
- 按 ABI 覆盖 `versionCode`（`base * 10 + abiCode`），便于多 APK 发布。
- Media3 依赖保持不变（Native 回退代码仍在树中）。

## 对齐

与 `flutter build apk --split-per-abi` 一致：按 ABI 产出独立 APK，不打 fat 包，配合 media_kit 原生库减小体积。

## 验证建议

```bash
cd android && ./gradlew :app:assembleRelease
# 或
flutter build apk --split-per-abi
```

应看到各 ABI 独立 APK，无 `*-universal-*.apk` / 全 ABI fat 包。
