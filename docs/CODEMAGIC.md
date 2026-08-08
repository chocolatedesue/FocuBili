# FocuBili Codemagic 云编译指南

参考 [FMP](https://github.com/chocolatedesue/FMP) 的 `codemagic.yaml` 写法，为 FocuBili 提供 Android / macOS / Windows 三端云构建。

## 工作流一览

| Workflow ID | 名称 | 机器 | 产物 |
|-------------|------|------|------|
| `android-apk` | FocuBili Android APK | `mac_mini_m2`（免费计划） | `FocuBili-android-bN.apk` |
| `macos-build` | FocuBili macOS Build | `mac_mini_m2`（默认） | `FocuBili-macos-bN.zip`（内含 `.app`） |
| `windows-build` | FocuBili Windows Build | `windows_x2`（需付费计划） | `FocuBili-windows-bN.zip` |

> **实例说明**：免费计划仅提供 `mac_mini_m2`。Android APK 可在 mac 实例上构建（`flutter build apk` 跨平台）。`windows_x2` / `linux_x2` 需要付费计划，否则对应 workflow 会因 "instance type not available" 失败。

配置文件：仓库根目录 [`codemagic.yaml`](../codemagic.yaml)。

## 在 Codemagic 接入

1. 打开 [codemagic.io](https://codemagic.io)，用 GitHub 登录。
2. **Add application** → 选择 `chocolatedesue/FocuBili`（或你的 fork）。
3. 选择 **Flutter App**，扫描到根目录的 `codemagic.yaml` 后保存。
4. 在应用设置里确认三个 workflow 都可见。
5. 手动 **Start new build**，分别选 `android-apk` / `macos-build` / `windows-build` 试跑。

成功后在 build 页面 **Artifacts** 下载 APK / zip。通知邮件默认发到 `chocolatedesue@outlook.com`（可在 yaml 里改）。

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

## 桌面端能力说明（重要）

播放后端选择见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)：

| 平台 | 播放 | 说明 |
|------|------|------|
| **Android** | Media3 + MethodChannel（主路径） | 纹理、边播边缓存、系统闹钟等能力最完整 |
| **Windows / Linux / macOS** | **media_kit（libmpv）实验性** | 桌面默认后端；依赖 `media_kit_libs_video` / 系统 mpv |
| 登录 Cookie | 桌面 prefs 与播放共用；Android WebView 通道 | 部分流仍需有效 Cookie；Windows 官方 WebView 登录受限 |

补充：

- 边播边缓存、系统闹钟提醒等 **Android 专用能力在桌面端尚未移植**；
- 登录页 `webview_flutter` 官方支持 Android / iOS / **macOS**，**不支持 Windows**（桌面优先 Cookie 粘贴）；
- macOS 已开启 sandbox 下的 `network.client`，便于 HTTPS 请求；
- **Windows 构建**：Codemagic `windows-build`（需 `windows_x2` 付费实例）之外，也可在 **GitHub Actions** 等自备 Windows runner 上 `flutter build windows`。

桌面播放为实验性能力，接口与编解码行为仍可能变化；请以真机/本机验收为准。

## 通过 CLI 触发构建

借助 Codemagic REST API 可在命令行直接触发 workflow（无需网页）：

```bash
export CM_TOKEN="<你的 API token>"
APP_ID="<app id，Codemagic 应用设置里可查>"

# 触发 Android APK（mac 实例）
curl -H "x-auth-token: $CM_TOKEN" -H "Content-Type: application/json" \
  --data '{"appId":"'$APP_ID'","workflowId":"android-apk","branch":"master"}' \
  -X POST https://api.codemagic.io/builds

# 触发 macOS 构建
curl -H "x-auth-token: $CM_TOKEN" -H "Content-Type: application/json" \
  --data '{"appId":"'$APP_ID'","workflowId":"macos-build","branch":"master"}' \
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

`PROJECT_BUILD_NUMBER` 由 Codemagic 每次构建递增。若要与 Git tag / `pubspec.yaml` 的 `1.2.0+11` 严格对齐，可在 yaml 里改成读 tag 或固定版本。

## 本地对照命令

```bash
# 国内镜像（可选）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter pub get
flutter analyze
flutter test

flutter build apk --release
flutter build macos --release
flutter build windows --release
```

## 与 FMP 的差异

| 项目 | FMP | FocuBili |
|------|-----|----------|
| Codemagic | 仅 macOS | Android + macOS + Windows |
| 代码生成 | Isar / slang | 无（不需要 build_runner） |
| 主平台 | 跨端音乐 | Android Media3 为主；桌面 media_kit 实验性播放 |
| 签名 | GitHub Release secrets | Codemagic 可选 keystore |
