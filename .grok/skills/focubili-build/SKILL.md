---
name: focubili-build
description: >
  FocuBili project cloud/local build, ABI-split Android APKs, Codemagic + GitHub
  Actions, and GitHub Release upload/download. Use when the user asks to build
  FocuBili, run Codemagic/GHA, split-per-abi, publish/download Release, or runs
  /focubili-build. Prefer this over generic Flutter build advice inside this repo.
---

# FocuBili Build Skill（项目级）

在 **本仓库** 内执行构建、云编译与 Release 分发。先 `cd` 到仓库根（含 `pubspec.yaml` / `codemagic.yaml`）。

## 何时使用

- 本地 / 云端编译 Android、Windows、macOS
- Android **split-per-abi**（禁止 fat APK 作为发布物）
- 触发 Codemagic / GitHub Actions
- 上传或下载 GitHub Release 资产
- 用户说：云构建、打 APK、发版、Release、Codemagic、GHA Windows

## 涉及什么

| 类别 | 路径 | 作用 |
|------|------|------|
| 云配置 | `codemagic.yaml` | CM：`android-apk` / `macos-build` / `windows-build` |
| GHA | `.github/workflows/windows-build.yml` | Windows analyze + test + `flutter build windows` |
| 签名（可选） | `android/key.properties` + keystore（gitignore） | Release 签名；无则 debug 签 |
| Gradle | `android/app/build.gradle` | `splits.abi` + `universalApk false` |
| 播放后端 | `lib/services/playback_service_factory.dart` | Android/桌面默认 **media_kit** |
| 文档 | `docs/CODEMAGIC.md`, `docs/PLAYBACK_BACKEND.md`, `docs/DESKTOP.md`, `docs/RELEASE_NOTES_*.md` | 构建与发版说明 |
| 计划 | `docs/PLAN_ANDROID_MEDIA_KIT.md` | Android media_kit + split 计划 |
| 脚本 | `scripts/download_release.sh` | 下 Release |
| | `scripts/fetch_codemagic_android_split.sh` | 从 CM build 拉 split APK |
| | `scripts/publish_github_release.sh` | 上传本地产物到 Release |
| 技能参考 | `.grok/skills/focubili-build/references/build-matrix.md` | 矩阵速查 |

**不要**把 `build/app/outputs/flutter-apk/app-release.apk`（fat）当正式发布物。

---

## 环境

```bash
export PATH="${HOME}/flutter/bin:${PATH}"
# 国内镜像（需要时）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter --version   # 建议 3.44.x stable
```

凭证（按需，勿提交）：

| 用途 | 位置 |
|------|------|
| Codemagic API | `~/.cmtoken`（`CM_API_TOKEN=...` 或纯 token）或 env `CM_API_TOKEN` |
| GitHub CLI | `gh auth status`（scopes: repo, workflow） |

Codemagic **App ID**（本项目）：`6a769232581b36b2411fd1e6`  
仓库：`chocolatedesue/FocuBili`

---

## 工作流矩阵

| 目标 | 推荐通道 | Workflow / 命令 | 产物 |
|------|----------|-----------------|------|
| Android release | Codemagic（免费 mac 可跑） | `android-apk` | `FocuBili-android-{abi}-bN.apk` ×3 |
| macOS | Codemagic | `macos-build` | macOS zip（常未签名） |
| Windows | **GitHub Actions** | `Windows Build` | `windows-build` artifact zip |
| Windows | Codemagic | `windows-build` | 常需付费 `windows_x2`，免费易失败 |
| 本地 Android | 本机 | 见下 | split APK |
| 发版 | GitHub Release | `scripts/publish_github_release.sh` | 多资产 + SHA256SUMS |

Android ABI：`armeabi-v7a` / `arm64-v8a`（**多数真机**）/ `x86_64`。

---

## 本地构建

### 通用检查

```bash
flutter pub get
flutter analyze
flutter test
```

### Android（必须 split，不发 fat）

```bash
flutter build apk --release --split-per-abi
# 输出：
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#   build/app/outputs/flutter-apk/app-x86_64-release.apk
```

重命名发版示例：

```bash
VER=1.2.1
OUT=dist/v${VER}
mkdir -p "$OUT"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  "$OUT/FocuBili-v${VER}-android-arm64-v8a.apk"
# 同样复制 v7a / x86_64
```

### 桌面

```bash
flutter config --enable-windows-desktop   # 或 macos / linux
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

---

## 云构建：Codemagic

```bash
CM_TOKEN=$(grep -oE '[^=]+$' "$HOME/.cmtoken" | head -1 | tr -d ' \n\r')
APP_ID=6a769232581b36b2411fd1e6

# 触发
curl -sS -X POST "https://api.codemagic.io/builds" \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $CM_TOKEN" \
  -d "{\"appId\":\"$APP_ID\",\"workflowId\":\"android-apk\",\"branch\":\"master\"}"

# workflowId: android-apk | macos-build | windows-build

# 查状态
curl -sS -H "x-auth-token: $CM_TOKEN" \
  "https://api.codemagic.io/builds/<buildId>"
```

从已成功 build 拉 Android split 并改名为 Release 文件名：

```bash
./scripts/fetch_codemagic_android_split.sh <buildId> ./dist/android 1.2.1
```

可选 Android 签名：Codemagic 环境变量 / `key.properties`（见 `docs/CODEMAGIC.md`）。无 keystore 时 CM 用 debug 签（与历史试装一致）。

---

## 云构建：GitHub Actions（Windows）

```bash
gh workflow run "Windows Build" -R chocolatedesue/FocuBili --ref master
gh run list -R chocolatedesue/FocuBili -L 5
gh run watch <runId> -R chocolatedesue/FocuBili --exit-status
gh run download <runId> -R chocolatedesue/FocuBili -n windows-build -D ./dist/win
```

注意：`concurrency` 可能导致 push 与 `workflow_dispatch` 互相取消；以成功的那次为准。

---

## GitHub Release

### 下载

```bash
./scripts/download_release.sh v1.2.1 ./dist
./scripts/download_release.sh v1.2.1 ./dist arm64    # 仅 arm64 APK
./scripts/download_release.sh v1.2.1 ./dist android
```

### 上传 / 更新

准备目录内资产命名（示例）：

- `FocuBili-v1.2.1-android-arm64-v8a.apk`
- `FocuBili-v1.2.1-android-armeabi-v7a.apk`
- `FocuBili-v1.2.1-android-x86_64.apk`
- `FocuBili-v1.2.1-windows-x64.zip`
- `FocuBili-v1.2.1-macos.zip`

```bash
./scripts/publish_github_release.sh v1.2.1 ./dist \
  --notes-file docs/RELEASE_NOTES_v1.2.1.md \
  --title "FocuBili v1.2.1 — Android / Windows / macOS"
```

脚本会生成并上传 `SHA256SUMS.txt`。若目录里同时有 fat `*-android.apk` 与 split，应删掉 fat 再传。

### 手工补传（已有 tag）

```bash
gh release upload v1.2.1 -R chocolatedesue/FocuBili FILE... --clobber
gh release edit v1.2.1 -R chocolatedesue/FocuBili --notes-file docs/RELEASE_NOTES_xxx.md
```

---

## Agent 操作清单（发一版）

1. `git status`；需要则 commit/push `master`。
2. 跑本地 `analyze` + `test`（或依赖 CI）。
3. 触发云构建：
   - Android：CM `android-apk`
   - macOS：CM `macos-build`
   - Windows：GHA `Windows Build`
4. 等待成功；失败则拉 log（`gh run view --log-failed` / CM build actions）。
5. 收集产物：
   - `./scripts/fetch_codemagic_android_split.sh <androidBuildId> ./dist/vX.Y.Z X.Y.Z`
   - `gh run download <winRunId> -n windows-build ...` 并重命名
   - CM 下载 mac zip 并重命名
6. 更新 `docs/RELEASE_NOTES_vX.Y.Z.md` 与 README 下载表（若版本变化）。
7. `./scripts/publish_github_release.sh vX.Y.Z ./dist/vX.Y.Z --notes-file ...`
8. 用 `./scripts/download_release.sh` 抽检 + `sha256sum -c SHA256SUMS.txt`。

---

## 常见失败

| 现象 | 处理 |
|------|------|
| CM Windows `instance type not available` | 改 GHA Windows，勿死磕免费 CM |
| 只产出 / 误传 fat APK | 确认 `--split-per-abi` 与 `universalApk false`；发布只用 `*-android-{abi}.apk` |
| GHA 测试挂在登录页 Windows | 断言需接受「改用 Cookie」分支（见 `test/widget_test.dart`） |
| CM 下载 APK 得到 JSON | 用 build API 的 artefact `url` + `x-auth-token`（`fetch_codemagic_android_split.sh`） |
| push 与 workflow_dispatch 一个 cancelled | concurrency 正常；看 success 那次 |

---

## 相关阅读（本技能不够时）

- 全文：`docs/CODEMAGIC.md`
- 播放后端：`docs/PLAYBACK_BACKEND.md`
- 桌面使用：`docs/DESKTOP.md`
- 矩阵速查：`references/build-matrix.md`（本 skill 目录）

## 约束

- 不把 token / keystore 写进仓库。
- 不 force-push 主分支。
- 发版说明保持「非官方、实验性桌面、mac 未公证」等诚实表述。
