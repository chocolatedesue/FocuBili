# Plan: Android 默认 media_kit + ABI split APK（不打 fat）

## 目标

1. **Android 默认播放后端**改为 `MediaKitPlaybackService`（与桌面一致），保留 `NativePlaybackService` 可注入/可选开关以便回退。
2. **云构建与本地 release** 使用 **ABI split** 产出多 APK，**不发布 fat `app-release.apk`**。
3. 并行子 agent 按文件所有权实施；编排者合并、全量 test、push、触发 Codemagic。

## 非目标

- 删除 Kotlin Media3 代码（本阶段保留，供 debug/回退）。
- 改 playurl/EDL 核心算法（除非 Android 编译硬失败）。
- iOS 迁移。
- 打 AAB（用户明确 split apk，不 fat；AAB 另议）。

## 架构

```
createPlaybackService()
  ├── Android  → MediaKitPlaybackService   // 本计划变更
  ├── Desktop  → MediaKitPlaybackService   // 不变
  └── 可选: FOCUBILI_USE_NATIVE_PLAYBACK=1 或 kDebug 开关 → Native（若实现）
```

Gradle / Flutter:

```
flutter build apk --release --split-per-abi
→ build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
→ app-arm64-v8a-release.apk
→ app-x86_64-release.apk
（无 fat app-release.apk 作为发布物）
```

可选 `android/app/build.gradle` `splits.abi` 与 Flutter 对齐，避免误产 universal。

## 并行 DAG

```
        [W0 PLAN 本文件 / 已写入]
              |
    ┌─────────┼─────────┬────────────┐
    ▼         ▼         ▼            ▼
 [A-FACTORY] [B-GRADLE] [C-CM]    [D-DOCS]
  Android默认  splits ABI  Codemagic  文档
  MediaKit     无 fat      收多 APK
    └─────────┴─────────┴────────────┘
                    │
              [ORCH merge + test + push + build]
```

| Agent | 所有权 | 禁止 |
|-------|--------|------|
| **A-FACTORY** | `playback_service_factory.dart`, `test/playback_service_factory_test.dart`, 可选 `playback_backend.dart` 开关 | 不改 gradle/codemagic；不改 media_kit 大实现 |
| **B-GRADLE** | `android/app/build.gradle` splits/abiFilters 注释与配置 | 不改 dart；不改 yaml 业务步骤以外 |
| **C-CM** | `codemagic.yaml` android-apk workflow：`--split-per-abi`、artifacts 多文件命名 | 不改 lib |
| **D-DOCS** | `docs/PLAYBACK_BACKEND.md`, `docs/CODEMAGIC.md`, README 安卓下载说明一小段, `docs/agent-reports/PLAN_ANDROID_MK_NOTE.md` | 不改 lib 逻辑 |

**冲突文件：** 无交叉（除 README 仅 D 可写）。

## A-FACTORY 细节

- `createPlaybackService()`：`Platform.isAndroid` → `MediaKitPlaybackService()`。
- iOS 仍 Native 或 MediaKit（media_kit 有 ios libs）——建议 Android only 改，iOS 保持 Native 以免扩大范围。
- 测试：Android 在 VM 测不到 `Platform.isAndroid` 为 true；更新注释与 factory 测试逻辑：
  - 可用 `bool Function()? platformOverride` 仅 testing，或文档说明 Linux VM 仍 media_kit。
  - 增加可测分支：`@visibleForTesting` `createPlaybackServiceForPlatform({required bool isAndroid, required bool isDesktop, ...})` 纯函数，生产 `createPlaybackService` 调它。
- **不要**删除 Media3 依赖本阶段（B 可保留 gradle media3 deps）。

## B-GRADLE 细节

```gradle
android {
  splits {
    abi {
      enable true
      reset()
      include "armeabi-v7a", "arm64-v8a", "x86_64"
      universalApk false   // 关键：不打 fat
    }
  }
}
```

- 确认与 Flutter `--split-per-abi` 不冲突；若 Flutter 已 split，gradle `universalApk false` 双保险。
- 版本号：split 时可用 `output.versionCodeOverride` 按 ABI 偏移（可选，避免商店冲突）：

```gradle
// 可选 project.ext.abiCodes = ['armeabi-v7a':1, 'arm64-v8a':2, 'x86_64':3]
// applicationVariants... versionCode * 10 + abiCode
```

- 中文注释说明为何 split。

## C-CM 细节

`android-apk` script:

```bash
flutter build apk --release --split-per-abi \
  --build-name=... --build-number=...
mkdir -p codemagic-artifacts
for abi in armeabi-v7a arm64-v8a x86_64; do
  SRC="build/app/outputs/flutter-apk/app-${abi}-release.apk"
  if [ -f "$SRC" ]; then
    cp "$SRC" "codemagic-artifacts/FocuBili-android-${abi}-b${PROJECT_BUILD_NUMBER}.apk"
    cp "$SRC" "codemagic-artifacts/FocuBili-android-${abi}-latest.apk"
    sha256sum ... 
  fi
done
# 明确不要复制 app-release.apk 作为发布物
```

artifacts 路径改为 `codemagic-artifacts/*-android-*.apk` 与 split 输出。

## D-DOCS

- PLAYBACK_BACKEND 表：Android → MediaKit（default）；Native 保留说明。
- CODEMAGIC：split ABI、产物文件名、无 fat。
- README：Android 下载说明改为多 ABI（若写死单 APK 则改为指向 release 多文件或 arm64 主推）。

## 验收

- [ ] `flutter analyze` 绿
- [ ] `flutter test` 绿
- [ ] factory：Android 逻辑测覆盖（forPlatform helper）
- [ ] 本地或 CM：`flutter build apk --split-per-abi` 产出 3 个 APK，无依赖 fat
- [ ] Codemagic android-apk 成功且 artifacts 为 split 命名
- [ ] 文档一致

## 风险

| 风险 | 缓解 |
|------|------|
| APK 体积/libmpv | split 后单 ABI 可控；说明 arm64 主推 |
| Media3 与 media_kit 双依赖体积 | 短期保留 Media3；后续可去依赖 |
| 行为差异（缓存/PiP/截帧） | 已知 desktop 限制同样适用 Android media_kit；截帧仍可能弱 |
| minSdk | media_kit_android 通常 ≥21/24，与 Flutter 3.44 对齐 |

## Merge 顺序

1. A-FACTORY（纯 dart，先合）
2. B-GRADLE
3. C-CM
4. D-DOCS  
或 A∥B∥C∥D 后 ort merge（无文件冲突预期）。
