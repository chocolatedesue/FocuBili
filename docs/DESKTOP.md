# FocuBili 桌面端使用说明

面向 Windows / macOS（及可本地构建的 Linux）用户的简短指南。桌面播放基于 **media_kit（libmpv）实验性** 后端，是真实播放能力，不是空壳。

- 安装包：[GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)
- 播放后端与 Cookie 键：[`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)
- 云构建：[`CODEMAGIC.md`](CODEMAGIC.md)

## 安装

| 平台 | 文件（Release） | 用法 |
|------|-----------------|------|
| **Windows x64** | `FocuBili-v1.2.1-windows-x64.zip` | 解压后运行其中的 `.exe`（便携包，非安装器） |
| **macOS** | `FocuBili-v1.2.1-macos.zip` | 解压得到 `.app`。**未 Apple 签名/公证**，首次可能被 Gatekeeper 拦截：可对 app **右键 → 打开**，或去掉隔离属性后再启动 |
| **Android** | `FocuBili-v1.2.1-android.apk` | 主路径仍为手机/平板；见主 README |

校验和见 Release 内 `SHA256SUMS.txt`。

### macOS 去隔离（可选）

```bash
xattr -dr com.apple.quarantine /path/to/FocuBili.app
```

## Cookie 登录（推荐）

桌面推荐在「登录」页使用 **Cookie 粘贴**：

1. 在浏览器登录 bilibili.com，从开发者工具或扩展复制 Cookie 字符串（至少含有效 `SESSDATA` 等会话字段）。
2. 粘贴到 FocuBili 登录页的 Cookie 模式并保存。
3. 同一 prefs 键同时用于**账号会话检测**与**播放/playurl 请求**：  
   `focubili_bili_cookie_header`（代码常量 `kFocubiliBiliCookieHeaderPrefsKey`）。

说明：

- **Windows**：官方 WebView 登录不可用，请只用 Cookie 粘贴。
- **macOS**：界面可能仍提供网页登录入口，但与播放会话同步不可靠；**请以 Cookie 粘贴为准**。
- 部分清晰度或受权限控制的流需要有效 Cookie；公开试看是否可用取决于 CDN。
- 云构建产物不包含任何 Cookie；会话只存在本机。

## 播放器快捷键

焦点在播放页时大致可用（以当前版本绑定为准）：

| 按键 | 作用 |
|------|------|
| **Space** | 播放 / 暂停 |
| **Esc** | 返回（退出全屏或离开播放页，视状态而定） |
| **← / →** | 快退 / 快进 |
| **Shift + ← / →** | 更大步长快退 / 快进 |
| **↑ / ↓** | 音量增减 |
| **F** 或 **F11** | 全屏切换 |
| **M** | 静音切换 |
| **C** | 相关控制（如弹幕/章节类入口，以界面为准） |

另有媒体键 Play/Pause 等系统键映射时也会生效。

## 观看历史（宽屏首页）

- 窗口足够宽时（约 **≥900dp**），首页可展示**最近观看**网格。
- 从首页或完整观看历史打开条目时，会尽量**恢复分 P 与进度**（`WatchHistoryLauncher` → `PlayerRouteArgs`）。
- 若分 P 信息无法匹配，可能落到默认分 P 仍尝试 seek；多 P 合集请留意标题/页码是否一致。

## 专注跟播

- 专注计时会跟随真实播放状态；**缓冲中**（`isPlaying` 且 phase 为 loading）仍视为在播，避免正常卡顿误停专注。
- **系统级**精确闹钟、勿扰等仍以 **Android** 为主；桌面不要期望与手机 1:1 的系统提醒/勿扰行为。

## 限制与诚实说明

| 项目 | 说明 |
|------|------|
| 实验性播放 | media_kit / libmpv；编解码与双音轨 EDL 等行为仍可能变化 |
| 无系统闹钟 1:1 | 桌面不提供与 Android 相同的精确闹钟 / 勿扰闭环 |
| macOS 未签名 | Gatekeeper 可能拦截；需手动允许 |
| Windows 无 WebView 登录 | 仅 Cookie 粘贴 |
| 非官方客户端 | 个人学习项目；遵守平台规则与当地法律；接口可能随时变化 |

更多技术细节见 [`PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)。
