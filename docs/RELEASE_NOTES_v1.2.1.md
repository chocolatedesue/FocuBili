# FocuBili v1.2.1 发布说明

发布日期：2026 年 8 月 8 日

Android 最低版本：Android 7.0（API 24）

应用版本：`1.2.1`

目标平台：Android（主路径）· Windows / macOS（实验性桌面）

## 本次重点

v1.2.1 首次提供 **Android APK + Windows zip + macOS zip** 多端公开构建，桌面默认接入 **media_kit（libmpv）实验性播放**，并修通历史续播、专注缓冲不停表、桌面 Cookie 与播放同源，以及播放器键盘快捷键。

### 多端发布与构建

- 正式分发仓库：[chocolatedesue/FocuBili](https://github.com/chocolatedesue/FocuBili)。
- Release 资源同时包含 Android APK、Windows 目录 zip、macOS `.app` zip（未公证、未上架应用商店）。
- Android / macOS 可通过 Codemagic 云编译；Windows 可通过 GitHub Actions（或 Codemagic Windows 实例，视套餐而定）。
- 本地与云端仍使用学习/测试向签名配置；长期覆盖安装前请自行配置独立密钥。

### 桌面播放（实验性）

- Windows / macOS / Linux 默认使用 **media_kit（libmpv）** 作为播放后端，以便桌面也能驱动专注跟播计时。
- Android 仍以 Media3 + Flutter `Texture` 为主路径。
- 后端选择与依赖说明见 [`docs/PLAYBACK_BACKEND.md`](PLAYBACK_BACKEND.md)。
- 桌面能力仍为实验性：DASH 双轨、清晰度、边播边缓存与系统级能力完整度不及 Android；请勿与已公证商业桌面客户端对等预期。

### 专注与历史

- **观看记录续播**：从首页或「我的 → 观看记录」打开时，尽量恢复上次分 P 与播放位置，并提示来自观看记录。
- **宽屏首页历史网格**：较宽窗口下首页展示本机观看历史卡片网格，便于从桌面直接续看（窄屏仍走「我的 → 观看记录」）。
- **专注计时与缓冲**：正常缓冲 / 加载中不再把专注计时误判为暂停；仅在真正停止播放等情况下中断累计。

### 登录与播放会话

- 桌面推荐 **Cookie 粘贴登录**：写入本机 prefs，与 playurl / media 请求共用同一会话键。
- Windows 官方 WebView 登录受限，界面以 Cookie 路径为主；macOS 网页登录仍可能与播放会话不同步，请优先 Cookie。
- 公开内容策略不变：不绕过会员、充电、私密或其他访问控制。

### 播放器键盘快捷键（桌面）

播放页在输入框未抢占焦点时支持常见快捷键，例如：

- `Space`：播放 / 暂停
- `←` / `→`：快退 / 快进；`Shift+←` / `Shift+→`：更大步长
- `↑` / `↓`：音量
- `F` / `F11`：全屏相关
- `M`：静音；`C`：弹幕显隐（以实际实现为准）
- `Esc`：退出一层（全屏或返回）

快捷键以本机焦点为准；文本输入聚焦时不会误触发（`Esc` 仍可退出一层）。

## 校验和（SHA-256）

以下为 v1.2.1 Release 资产校验值（小写十六进制）。下载后请自行核对：

| 平台 | 资产（命名以 Release 页为准） | SHA-256 |
|------|-------------------------------|---------|
| Android | APK（如 `FocuBili-android-*.apk`） | `5728d1f55fa9921f138e9cdb7a4090814a69d74a52d1064b3e3e238d00031361` |
| macOS | zip（如 `FocuBili-macos-*.zip`） | `4d4403e34d776b449de436a7e1e6f089b803f7199e4257ec0e7cdc43ed4e7c51` |
| Windows | zip（如 `FocuBili-windows-*.zip`） | `9767991eda8e7160789bf4560935c692def0dcd92d668d6188e9ae4fdffe9aa9` |

发布页：[GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)

## 构建来源

| 产物 | 典型来源 |
|------|----------|
| Android Release APK | Codemagic `android-apk` / 本地 `flutter build apk --release` |
| macOS `.app` zip | Codemagic `macos-build`（未签名 / 未公证） |
| Windows 目录 zip | GitHub Actions 或 Codemagic `windows-build` |

云编译说明见 [`docs/CODEMAGIC.md`](CODEMAGIC.md)。Flutter 验证基线为 3.44.x stable。

## 已知限制

- 桌面 media_kit 为**实验性**：依赖 libmpv / `media_kit_libs_video`；部分 DASH、清晰度与错误恢复路径仍在演进。
- macOS 包**未** Apple 公证，也不提供 App Store 分发；首次打开可能需在系统设置中允许未签名应用。
- 首页不提供无限推荐流；入口仍以搜索、BV、链接与本机历史为主。
- 分 P 历史目前主要按页码与标题匹配；匹配失败时可能回退默认分 P，进度 seek 语义需用户留意。
- 系统勿扰、精确闹钟、厂商自启动等仍以 **Android** 为主；桌面无对等系统能力。
- 项目依赖非官方接口，可能触发风控或失效；不绕过付费与访问控制。
- Android Release 仍可能使用调试/学习向签名，仅适合试装。

## 验证说明

- 本版本文档与多端产物对应 `chocolatedesue/FocuBili` 的 v1.2.1 发布标签。
- 桌面路径以代码与单测为主；真机矩阵（各 OS × 公开 BV × Cookie 清晰度 × 续播 × 专注）仍建议自行 smoke。
- 历史版本与上游实验记录可参考 [L1Xu4n/FocuBili](https://github.com/L1Xu4n/FocuBili) Releases（非最新下载源）。
