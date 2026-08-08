# FocuBili v1.2.1 发布说明

发布日期：2026 年 8 月 8 日

Android 最低版本：Android 7.0（API 24）

应用版本：`1.2.1`（构建线含 media_kit 默认 + split ABI）

目标平台：Android / Windows / macOS（桌面为实验性）

## 本次重点

v1.2.1 提供 **多端公开构建**，并完成：

- **Android 与桌面默认 media_kit**（libmpv）播放栈；
- **Android 仅按 ABI 分包发布**（无 fat APK）；
- 历史续播、专注缓冲不停表、桌面 Cookie 与播放同源、播放器键盘快捷键。

### 多端发布与构建

- 正式分发仓库：[chocolatedesue/FocuBili](https://github.com/chocolatedesue/FocuBili)。
- Release 页：[v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)。
- **Android**：`arm64-v8a` / `armeabi-v7a` / `x86_64` 三个 APK；**多数真机装 arm64-v8a**。不再提供单文件 fat APK。
- **Windows**：目录 zip（GitHub Actions）。
- **macOS**：`.app` zip（Codemagic，未公证）。
- 本地 Android：`flutter build apk --release --split-per-abi`（见 [`CODEMAGIC.md`](CODEMAGIC.md)）。

### 播放后端

- Android / Windows / macOS / Linux 默认 **media_kit**；`NativePlaybackService`（Media3）仍保留可注入回退。
- 说明见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)、桌面使用见 [`DESKTOP.md`](DESKTOP.md)。

### 专注与历史

- 观看记录续播：恢复分 P 与进度（`WatchHistoryLauncher` / `PlayerRouteArgs`）。
- 宽屏首页历史网格（≥900dp）。
- 专注计时：正常缓冲不再误停。

### 登录与会话

- 桌面 Cookie 粘贴与播放共用 prefs 键；Windows 以 Cookie 为主。
- 公开内容不绕过会员与访问控制。

### 播放器键盘快捷键（桌面）

- `Space` 播放/暂停 · `←`/`→` 快退快进 · `↑`/`↓` 音量  
- `F`/`F11` 全屏 · `M` 静音 · `C` 控制层 · `Esc` 退出一层  

## 校验和（SHA-256）

| 资产 | SHA-256 |
|------|---------|
| `FocuBili-v1.2.1-android-arm64-v8a.apk` | `b6dee1ebdf2bfdb8276027198732f49d524c11c84f1bf03c449fc52c3706f310` |
| `FocuBili-v1.2.1-android-armeabi-v7a.apk` | `5c8911961e8cb930cb3dd3e617474c97fe0f990fda4603b4f9470c33751a40b8` |
| `FocuBili-v1.2.1-android-x86_64.apk` | `5a3701860c40d2fa180257ae3fd8a88c50479fa7be1f97b0753c6b10be7815b2` |
| `FocuBili-v1.2.1-macos.zip` | `4d4403e34d776b449de436a7e1e6f089b803f7199e4257ec0e7cdc43ed4e7c51` |
| `FocuBili-v1.2.1-windows-x64.zip` | `9767991eda8e7160789bf4560935c692def0dcd92d668d6188e9ae4fdffe9aa9` |

完整列表也在 Release 附件 `SHA256SUMS.txt`。

## 构建来源

| 产物 | 来源 |
|------|------|
| Android per-ABI APK | Codemagic `android-apk`（`--split-per-abi`，构建 b11 等） |
| macOS zip | Codemagic `macos-build` |
| Windows zip | GitHub Actions `Windows Build` |

## 已知限制

- media_kit 为实验性；部分 Media3 专属能力（系统级缓存/PiP 等）在 media_kit 路径可能弱化。
- macOS 未公证；Windows 为 zip 非安装器。
- 分 P 历史按页码/标题匹配，失败时可能回退默认分 P。
- 系统闹钟 / 勿扰等仍偏 Android 系统 API。
- 非官方接口与调试/学习向签名，仅适合试装。

## 验证说明

- 分发以 [Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1) 为准。
- 建议真机 smoke：公开 BV、Cookie 清晰度、历史续播、专注缓冲、logout。
