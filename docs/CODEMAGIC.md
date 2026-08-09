# FocuBili Codemagic 云编译指南

参考 [FMP](https://github.com/chocolatedesue/FMP) 的 `codemagic.yaml` 写法，为 FocuBili 提供多端云构建。

**终端用户安装包**：请优先从 [GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1) 下载。

- Android：**三个 ABI APK**（推荐 [`arm64-v8a`](https://github.com/chocolatedesue/FocuBili/releases/download/v1.2.1/FocuBili-v1.2.1-android-arm64-v8a.apk)），无 fat 包。
- Windows / macOS：对应 zip。

桌面说明见 [`DESKTOP.md`](DESKTOP.md)；播放后端见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)。  
脚本：[`scripts/download_release.sh`](../scripts/download_release.sh)、[`scripts/fetch_codemagic_android_split.sh`](../scripts/fetch_codemagic_android_split.sh)、[`scripts/publish_github_release.sh`](../scripts/publish_github_release.sh)。

项目级 Agent 技能：[`.grok/skills/focubili-build/SKILL.md`](../.grok/skills/focubili-build/SKILL.md)（`/focubili-build`）。  
一键触发云构建：

```bash
.grok/skills/focubili-build/scripts/trigger_cloud_builds.sh android macos windows
```

## 工作流一览

| Workflow ID | 名称 | 机器 | 产物 | 计划说明 |
|-------------|------|------|------|----------|
| `android-apk` | FocuBili Android APK | `mac_mini_m2` | **按 ABI 拆分的多个 APK**（见下） | **免费计划可用**（mac 上 `flutter build apk --split-per-abi`） |
| `macos-build` | FocuBili macOS Build | `mac_mini_m2` | `FocuBili-macos-bN.zip`（内含 `.app`） | **免费计划可用**；产物通常为**未签名**包 |
| `windows-build` | FocuBili Windows Build | `windows_x2` | `FocuBili-windows-bN.zip` | **常需付费** `windows_x2`；免费计划易报 instance unavailable |

> **实例说明**：Codemagic **免费计划**主要提供 `mac_mini_m2`，因此 **Android + macOS** 是默认可跑的云构建路径。`windows_x2` / `linux_x2` 往往不在免费额度内。Windows 日常发版更常见走 **GitHub Actions**（自备 Windows runner / `flutter build windows`），与 CM `windows-build` 二选一或并存。

配置文件：仓库根目录 [`codemagic.yaml`](../codemagic.yaml)。

### v1.2.1 构建来源（参考）

| 平台 | 典型来源 |
|------|----------|
| Android | Codemagic `android-apk` |
| macOS | Codemagic `macos-build` |
| Windows | GitHub Actions（CM `windows-build` 在付费实例可用时亦可） |

## Android：ABI split（无 fat 发布物）

Android 默认播放后端为 **media_kit**（见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)），原生库体积较大，因此 **release 只发布 per-ABI APK，不发布 fat / universal `app-release.apk`**。

### 构建命令

```bash
flutter build apk --release --split-per-abi \
  --build-name=1.2.${PROJECT_BUILD_NUMBER} \
  --build-number=${PROJECT_BUILD_NUMBER}
```

Gradle（`android/app/build.gradle`）侧 `splits.abi` 与 Flutter 对齐：`universalApk false`，include `armeabi-v7a` / `arm64-v8a` / `x86_64`。

### 中间产物路径

```text
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

**不要**把 `app-release.apk`（若误生成）当作发布物拷贝。

### Codemagic / Release 命名（约定）

| ABI | 带构建号 | latest 别名 |
|-----|----------|-------------|
| armeabi-v7a | `FocuBili-android-armeabi-v7a-bN.apk` | `FocuBili-android-armeabi-v7a-latest.apk` |
| arm64-v8a | `FocuBili-android-arm64-v8a-bN.apk` | `FocuBili-android-arm64-v8a-latest.apk` |
| x86_64 | `FocuBili-android-x86_64-bN.apk` | `FocuBili-android-x86_64-latest.apk` |

另可附对应 `.sha256`。Artifacts 通配示例：`codemagic-artifacts/*-android-*.apk`。

历史单文件名 `FocuBili-android-bN.apk`（fat）**不再**作为 Android 主发布形态。

**GitHub Release v1.2.1** 已挂载：

- `FocuBili-v1.2.1-android-arm64-v8a.apk`（**推荐真机**）
- `FocuBili-v1.2.1-android-armeabi-v7a.apk`
- `FocuBili-v1.2.1-android-x86_64.apk`

以及 Windows / macOS zip 与 `SHA256SUMS.txt`。本地从 Release 下载可用 [`scripts/download_release.sh`](../scripts/download_release.sh)；上传新版本可用 [`scripts/publish_github_release.sh`](../scripts/publish_github_release.sh)（需已准备好产物目录）。

### 用户应装哪个 ABI？

| ABI | 适用设备 | 建议 |
|-----|----------|------|
| **arm64-v8a** | 近些年绝大多数手机 / 平板 | **默认下载这个** |
| armeabi-v7a | 较老的 32 位 ARM 设备 | 仅当 arm64 包无法安装时 |
| x86_64 | 部分模拟器 / 罕见 x86 平板 | 模拟器或明确 x86_64 硬件 |

在系统「设置 → 关于手机」或 `adb shell getprop ro.product.cpu.abi` 可确认主 ABI。

## 在 Codemagic 接入

1. 打开 [codemagic.io](https://codemagic.io)，用 GitHub 登录。
2. **Add application** → 选择仓库（如 `chocolatedesue/FocuBili` 或你的 fork）。
3. 选择 **Flutter App**，扫描到根目录的 `codemagic.yaml` 后保存。
4. 在应用设置里确认 workflow 可见。
5. 手动 **Start new build**：免费计划优先试 `android-apk` / `macos-build`；`windows-build` 仅在实例可用时再跑。

成功后在 build 页面 **Artifacts** 下载 **对应 ABI 的 APK** / 桌面 zip。通知邮件可在 yaml 的 `publishing.email` 中修改。

## Android 签名（可选）

未配置密钥时，Release APK 会使用 **debug 签名**（与当前仓库本地分发方式一致），适合试装，不适合长期覆盖升级。

### 方式 A：Codemagic 代码签名变量

在 Codemagic → Application settings → **Code signing identities** 上传 keystore，或设置环境变量组：

- `CM_KEYSTORE`（base64）
- `CM_KEYSTORE_PASSWORD`
- `CM_KEY_PASSWORD`
- `CM_KEY_ALIAS`

### 方式 B：自定义 Secrets

在 Codemagic Environment variables 中添加：

| 变量 | 说明 |
|------|------|
| `KEYSTORE_BASE64` | `base64 -w0 android/release.keystore` |
| `KEYSTORE_PASSWORD` | store 密码 |
| `KEY_PASSWORD` | key 密码 |
| `KEY_ALIAS` | 别名，例如 `focubili` |

本地生成示例：

```bash
keytool -genkey -v \
  -keystore android/release.keystore \
  -alias focubili \
  -keyalg RSA -keysize 2048 \
  -validity 36500 \
  -dname "CN=FocuBili,OU=Personal,O=Personal,L=Unknown,ST=Unknown,C=US"

base64 -w0 android/release.keystore   # 贴到 KEYSTORE_BASE64
```

`android/key.properties` 与 `*.keystore` / `*.jks` 已在 `.gitignore` 中。

## 桌面端与 Android 播放能力说明（重要）

桌面与 **Android 默认**均为 **media_kit（libmpv）实验性真实播放**（共享栈），**不是**「仅编译通过的空壳」。**iOS 不在本阶段使用 media_kit。** 播放后端选择见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)；终端用法见 [`DESKTOP.md`](DESKTOP.md)。

| 平台 | 播放 | 说明 |
|------|------|------|
| **Android** | **media_kit（默认，实验性）** | 与桌面共享 `MediaKitPlaybackService`；Media3 `NativePlaybackService` 仍保留在树中供注入/回退 |
| **Windows / Linux / macOS** | **media_kit（libmpv）实验性** | 桌面默认后端；依赖 `media_kit_libs_video` / 系统 mpv；可播流、跟专注计时、历史续播 |
| iOS | Native 通道向 | **未**迁 media_kit |
| 登录 Cookie | 桌面 prefs 与播放**共用**同一键 | `kFocubiliBiliCookieHeaderPrefsKey` / `focubili_bili_cookie_header`；推荐 Cookie 粘贴 |
| 登录 UI | Android WebView 通道为主 | macOS 可尝试 WebView，但与 prefs 播放会话可能不同步；**Windows 不支持**官方 WebView 登录，请用 Cookie |

补充：

- 边播边缓存、系统精确闹钟 / 勿扰等 **部分能力仍以 Android 平台服务为主**；在 media_kit 默认路径上，缓存/截帧/PiP 等可能弱于旧 Media3 主路径（与桌面限制同类）；
- 登录页 `webview_flutter` 官方支持 Android / iOS / **macOS**，**不支持 Windows**（桌面优先 Cookie 粘贴）；
- macOS 已开启 sandbox 下的 `network.client`，便于 HTTPS 请求；构建产物通常 **未 Apple 签名/公证**，Gatekeeper 可能拦截；
- **Windows 构建**：Codemagic `windows-build`（常需 `windows_x2` 付费实例）之外，发版更常见在 **GitHub Actions** 上 `flutter build windows`。

media_kit 播放为实验性能力，接口与编解码行为仍可能变化；请以真机/本机验收为准。

## Cookie / 登录与云构建的关系

- 云构建**不**内置任何用户 Cookie；登录与播放会话完全在本机完成。
- 桌面把粘贴的 Cookie 写入 SharedPreferences，键名与播放 `CookieHeaderProvider` 一致（见上表），避免「已登录但播不了」。
- 部分清晰度 / 受权限控制的流仍需要有效 Cookie；公开试看是否可用取决于 CDN。
- 详情见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md) 与 [`DESKTOP.md`](DESKTOP.md)。

## 通过 CLI 触发构建

借助 Codemagic REST API 可在命令行直接触发 workflow（无需网页）：

```bash
export CM_TOKEN="<你的 API token>"
APP_ID="<app id，Codemagic 应用设置里可查>"

# 触发 Android APK（mac 实例，免费计划友好；产物为 split ABI）
curl -H "x-auth-token: $CM_TOKEN" -H "Content-Type: application/json" \
  --data '{"appId":"'$APP_ID'","workflowId":"android-apk","branch":"master"}' \
  -X POST https://api.codemagic.io/builds

# 触发 macOS 构建（mac 实例，免费计划友好）
curl -H "x-auth-token: $CM_TOKEN" -H "Content-Type: application/json" \
  --data '{"appId":"'$APP_ID'","workflowId":"macos-build","branch":"master"}' \
  -X POST https://api.codemagic.io/builds

# 触发 Windows 构建（通常需要 windows_x2 付费实例；否则改用 GitHub Actions）
curl -H "x-auth-token: $CM_TOKEN" -H "Content-Type: application/json" \
  --data '{"appId":"'$APP_ID'","workflowId":"windows-build","branch":"master"}' \
  -X POST https://api.codemagic.io/builds

# 查询构建状态（返回 build.status / build.message）
curl -H "x-auth-token: $CM_TOKEN" https://api.codemagic.io/builds/<build_id>
```

- 触发构建时使用的 `workflowId` 是 `codemagic.yaml` 里定义的名称（`android-apk` / `macos-build` / `windows-build`）。
- token 在 [codemagic.io](https://codemagic.io) → 个人账户 → **API tokens** 生成。

## 版本号

三个 workflow 默认：

- `build-name` = `1.2.$PROJECT_BUILD_NUMBER`
- `build-number` = `$PROJECT_BUILD_NUMBER`

`PROJECT_BUILD_NUMBER` 由 Codemagic 每次构建递增。若要与 Git tag / `pubspec.yaml` 或 GitHub Release **v1.2.1** 严格对齐，可在 yaml 里改成读 tag 或固定版本。

Split APK 时 Gradle 可对 `versionCode` 按 ABI 做偏移（`base * 10 + abiCode`），避免多 APK 同号冲突。

## 本地对照命令

```bash
# 国内镜像（可选）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter pub get
flutter analyze
flutter test

# Android：按 ABI 拆分，不打 fat 发布包
flutter build apk --release --split-per-abi
flutter build macos --release
flutter build windows --release
```

本地 split 输出目录同上文「中间产物路径」。大多数真机安装：

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 与 FMP 的差异

| 项目 | FMP | FocuBili |
|------|-----|----------|
| Codemagic | 仅 macOS | **免费计划主打 Android + macOS**；Windows 常 GHA / 付费 `windows_x2` |
| 代码生成 | Isar / slang | 无（不需要 build_runner） |
| 主平台 | 跨端音乐 | **Android + 桌面默认 media_kit 实验性真实播放**（非空壳）；Native Media3 保留回退；**无 fat APK** |
| 签名 | GitHub Release secrets | Android 可选 keystore；macOS 产物通常未签名 |
| 终端分发 | — | [GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)（后续 Android 多为 per-ABI） |
