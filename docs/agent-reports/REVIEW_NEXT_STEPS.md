# REVIEW_NEXT_STEPS — FocuBili 战略复盘与 1–2 周路线图

| 字段 | 值 |
|------|-----|
| **Scope** | 架构健康、CI/构建、技术债、优先级路线图（只读复盘） |
| **Repo** | `/home/cnic/work/FocuBili` |
| **HEAD** | `ac131d0`（`master`） |
| **Date** | 2026-08-08 |
| **Author** | Agent NEXT_STEPS（read-only） |
| **Sibling reviews** | `REVIEW_PLAYBACK.md` / `REVIEW_PRODUCT_DESKTOP.md` **尚未就绪**；本报告独立基于代码、`docs/PLAN*`、`docs/PLAYBACK_BACKEND.md`、`docs/CODEMAGIC.md`、Wave `REPORT_*` |

**产品北极星（约束）：** 可用的桌面专注客户端；**不**变成 PiliPlus。

---

## 1. 形势摘要（Situation）

### 1.1 已交付（shipped）

| 里程碑 | 证据 | 状态 |
|--------|------|------|
| **v1.2.0 Android 产品线** | `pubspec` `1.2.0+11`、Release notes、学习清单/专注闹钟/平板布局等 | **生产可用（Android）** |
| **media_kit 并行迁移 Wave 0–3** | commits `369c340`→`5cde2ed`；六份 `REPORT_*` | **代码层 M3 完成** |
| **桌面默认播放后端** | `createPlaybackService()` → desktop `MediaKitPlaybackService`；Android 仍 `NativePlaybackService` | **已接线** |
| **Dart UGC playurl + DASH 选轨** | `BilibiliPlayUrlService` + fixture 单测 | **已落地（无 live 网测）** |
| **Cookie 抽象** | `CookieHeaderProvider`：Android channel / desktop prefs | **抽象完成；端到端未闭合** |
| **双后端画面槽** | `PlayerVideoSurface`（Texture \| media_kit `Video`） | **已落地** |
| **EDL 双轨 open** | `edl://` video+audio；helpers 单测 | **实现有；失败无自动降级** |
| **桌面 Home 最近观看** | `HomeWatchHistorySection`，宽屏 ≥900dp | **已落地** |
| **桌面播放快捷键** | Space/Esc/方向键/F/M/C 等 | **已落地** |
| **CI：GHA Windows** | `.github/workflows/windows-build.yml`（analyze + test + `build windows`） | **已配置** |
| **CI：Codemagic** | `android-apk`、`macos-build`；产物目录有 `FocuBili-android-b4.apk`、`FocuBili-macos-b2.zip` | **Android/macOS 可跑** |
| **并行实施方法论** | worktree + 文件所有权 + Wave 报告 | **验证有效** |

### 1.2 半完成 / 实验性（half-done）

| 项 | 现状 | 缺口 |
|----|------|------|
| **桌面「能播 + focus 跟播」** | 工厂与 PlayerPage 已 wire；单测 299 绿（WIRE 报告） | **缺真机/桌面 smoke**（公开 BV、会员清晰度、断网重试） |
| **桌面登录 → 播放 Cookie** | 登录页 Cookie 粘贴走 `BilibiliAuthService` → **仅** `PlatformBilibiliCookieStore`（MethodChannel `com.focubili.app/auth`） | Desktop 上 channel **MissingPlugin**；playback 读的是 **prefs** `focubili_bili_cookie_header` — **两套存储未打通** |
| **官方 WebView 登录** | Android/macOS 有路径；Windows `webview_flutter` 官方不支持 | Windows 必须 Cookie 粘贴路径可用 |
| **EDL 稳健性** | 有双轨；注释标明无 fallback | EDL 失败时 **无 video-only 自动降级**；无 backup CDN 轮转（playurl 只暴露主 URL） |
| **桌面能力降级** | PiP false；`captureCurrentFrame` null；亮度仅内存 | 笔记截图/专注「最后一帧」在桌面可能空 |
| **进度双写** | PlayerPage → `WatchHistoryService`；media_kit 另写 `focubili_mk_playback_*` | 与 Android Media3 原生进度 **语义分裂**；恢复路径需统一文档化 |
| **文档与现实不一致** | README 一处写 media_kit 实验性；**另一处仍写「桌面依赖 Media3、仅能编译」**；`codemagic.yaml` 头注释同 stale | 用户/贡献者误判能力 |
| **Codemagic Windows** | yaml 存在，`windows_x2` | **免费计划 instance 不可用**；Windows 靠 GHA |
| **Android 双后端** | Plan 允许可选 media_kit | **未做**（正确：非本阶段目标） |
| **player_page 体量** | ~6610 行 god object | 快捷键/ surface 已外提；仍是最大合并冲突与回归面 |
| **Sibling 深度复盘** | — | `REVIEW_PLAYBACK` / `REVIEW_PRODUCT_DESKTOP` 未就绪；深度播放/产品细节以其后续为准 |

### 1.3 架构一句话

```
FocusTimerController ──listen──► PlaybackService.states
                                      │
              ┌───────────────────────┴───────────────────────┐
              ▼                                               ▼
   MediaKitPlaybackService (Win/Linux/macOS)      NativePlaybackService (Android)
        │ playurl + cookie prefs                       │ Media3 MethodChannel
        ▼                                               ▼
   PlayerVideoSurface(VideoController)            PlayerVideoSurface(Texture)
```

分层（`lib/features` / `services` / `models` / `core`）清晰；**播放契约 + 工厂**是近期最好的架构投资。主要风险不在「缺后端」，而在 **会话闭环、真机验证、文档/CI 诚实度、player_page 熵**。

---

## 2. 架构健康评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 分层与边界 | **B+** | features/services 清楚；PlaybackService 接口稳定；Wave 所有权执行得好 |
| 桌面播放可演进性 | **B** | factory + surface + contracts 可插拔；EDL/截图/重试可增量 |
| 会话/Cookie 一致性 | **D+** | **CRITICAL 分裂**：Auth channel store ≠ playback prefs store（desktop） |
| UI 可维护性 | **C** | `player_page.dart` ~6.6k 行；已开始拆 keyboard/surface，仍是债核心 |
| 测试安全网 | **B** | ~57 test 文件；media_kit 用 fake host；**无集成/golden 桌面播** |
| CI/发布 | **B-** | GHA Windows + CM Android/macOS；CM Windows 死；文档 stale；无统一 quality gate workflow |
| 产品焦点纪律 | **A-** | 无推荐流；home 历史只读本机；plan 明确非 PiliPlus — 保持 |

---

## 3. 风险与技术债表

| ID | 严重度 | 区域 | 描述 | 影响 | 缓解方向 |
|----|--------|------|------|------|----------|
| R1 | **CRITICAL** | Auth / Cookie | Desktop：`loginWithCookie` → MethodChannel store；`MediaKitPlaybackService` → `PrefsCookieHeaderProvider`。用户「登录成功」播放仍可能无 Cookie | 高清/会员/部分 CDN 失败；桌面「可用」叙事破功 | Auth 桌面默认 `Prefs`/`CookieHeaderProvider` 适配器；登录成功 **双写或单源**；退出时 clear 两边 |
| R2 | **CRITICAL** | 验证缺口 | M3 仅单测 + 编译；无桌面公开流 smoke 清单 | 静默坏在用户机器上（libmpv/EDL/headers） | 书面 smoke：Win/mac 各 3 BV；记录 EDL/cookie 空/有 cookie |
| R3 | **MAJOR** | Playback | EDL open 失败无 video-only fallback；backup URL 未暴露 | 部分平台/CDN 黑屏或 error phase | open 失败降级 `Media(videoUrl)`；可选 playurl 返回 backup 列表 |
| R4 | **MAJOR** | Docs / CI 文案 | README Codemagic 段、`codemagic.yaml` 头仍写「桌面无播放/仅壳」 | 误导分发与支持 | 与 `PLAYBACK_BACKEND.md` 对齐；标明 experimental + 登录限制 |
| R5 | **MAJOR** | 进度状态 | `WatchHistoryService` vs `focubili_mk_playback_*` vs Android native saved state | 跨后端/跨端恢复不一致 | 文档单一真相；长期收敛到 history 或统一 SavedPlayback API |
| R6 | **MAJOR** | player_page | 6610 行；focus/学习清单/历史/增强/手势耦合 | 并行 PR 冲突、回归难 | 按边界继续外提（overlay chrome、history hooks、init pipeline） |
| R7 | **MAJOR** | Windows 登录 UX | 无 WebView；Cookie 粘贴是唯一现实路径且 R1 未修则不可用 | Windows 桌面无法完成「登录后播放」 | R1 + LoginPage 桌面优先 Cookie 模式、隐藏/降级 Web 入口 |
| R8 | **MAJOR** | 桌面 focus 周边 | 通知/精确闹钟/勿扰仍 Android channel；desktop MissingPlugin 安全忽略 | 专注「提醒」在桌面弱于 Android | **接受降级**并 UI 标明；勿移植系统闹钟（非目标） |
| R9 | **MINOR** | capture/PiP | `captureCurrentFrame` null；PiP false | 笔记贴图、专注分享帧可能空 | path_provider + `player.screenshot()`；PiP 可永久不做 |
| R10 | **MINOR** | playurl 范围 | 仅 UGC DASH；无 PGC/WBI；无 durl | 番剧/课程本就不在范围 | 保持非目标；错误文案友好 |
| R11 | **MINOR** | CI 碎片 | GHA 仅 Windows；CM 无 test on every PR 统一入口；version `1.2.$BUILD` vs pubspec | 发布号混乱 | 可选 PR workflow：analyze+test；版本策略一页纸 |
| R12 | **MINOR** | CODEMAGIC Windows | free plan 无 `windows_x2` | 死配置噪音 | 文档标注「paid only」或注释 workflow；GHA 为 Windows 真源 |
| R13 | **MINOR** | Linux 打包 | 无官方 Linux CI 产物；libmpv 运行时依赖 | 贡献者 Linux 本地不齐 | 文档依赖说明即可；非 1–2 周必须 |
| R14 | **MINOR** | 许可证纪律 | 对照 PiliPlus 思路、禁止粘贴 | 已遵守 | Code review 继续守 |

**债务热点（非功能）：**

- `PlaybackQuality` 仍从 `native_playback_service.dart` re-export — 契约文件可再纯净（**MINOR**）。
- 多处重复 `_desktopUserAgent` 字符串（**MINOR**，可收敛到 `bilibili_request_policy`）。
- `artifacts/` 未跟踪 — 本地产物，注意勿误提交。

---

## 4. 优先下一步（1–2 周）

估算：人日（1 人专注）；可并行见 §5。

### P0 — 不修则桌面「可用」不成立（本周）

| ID | 项 | 估计 | 验收 |
|----|----|------|------|
| **P0-1** | **打通桌面 Cookie 单源**：`BilibiliAuthService` 在非 Android 使用 prefs（或 `CookieHeaderProvider` 适配 `BilibiliCookieStore`）；`loginWithCookie` / `logout` / `loadCurrentSession` 与 playback 同键；Android 行为不变 | 0.5–1d | Desktop 粘贴 Cookie → nav 成功 → playurl 请求带同一 Cookie；logout 后播放无会话 |
| **P0-2** | **桌面播放 smoke 清单 + 执行记录**（Win 优先，mac 次之）：公开 BV 空 cookie；需登录清晰度；pause/seek 时 focus `isPlaying`；Home 历史点击续播 | 0.5–1d | `docs/agent-reports/SMOKE_DESKTOP_PLAYBACK.md` 或复盘附录：通过/失败平台矩阵 |
| **P0-3** | **EDL 失败自动降级 video-only**（+ 可读错误） | 0.5d | 单测：open 抛错 → 重试无 audio EDL；真机至少一失败注入或日志路径 |

### P1 — 显著提升可用性与诚信（本周–下周）

| ID | 项 | 估计 | 验收 |
|----|----|------|------|
| **P1-1** | **文档对齐**：README 桌面段、`codemagic.yaml` 头注释、`CODEMAGIC.md`「桌面能力」→ media_kit experimental + Cookie 登录 + Windows 无 WebView；删除「仅壳无播放」矛盾句 | 0.25d | 三处文案一致，链到 `PLAYBACK_BACKEND.md` |
| **P1-2** | **LoginPage 桌面 UX**：非 Android 默认 Cookie 模式；WebView 入口在 Windows 隐藏或明确 disabled | 0.5d | Windows 打开登录不进死 WebView；文案指导 SESSDATA |
| **P1-3** | **playurl 稳健性小步**：backup URL 纳入 manifest 或 open 重试一次；403/412 用户可读 | 0.5–1d | 单测 backup/错误映射；smoke 记录 |
| **P1-4** | **`captureCurrentFrame` 最小实现**（media_kit screenshot → 临时 jpeg） | 0.5d | 桌面笔记/专注截帧非空（若产品仍依赖） |
| **P1-5** | **GHA：PR 级 analyze+test**（ubuntu，不 build 全桌面也可） | 0.25–0.5d | PR 必绿；与 Windows workflow 分工清晰 |
| **P1-6** | **进度语义备忘**（先文档后代码）：PlayerPage 以 `WatchHistoryService` 为准；mk prefs 仅 backend resume — 或反过来写明 | 0.25d | `PLAYBACK_BACKEND.md` 一小节；避免下一位 agent 再双写新键 |

### P2 — 结构与体验（下周 / 有余力）

| ID | 项 | 估计 | 验收 |
|----|----|------|------|
| **P2-1** | **拆分 player_page**：初始化管线 / desktop shortcuts 已部分外提 → 再拆 watch-history hooks 或 completion overlays | 1–2d | 行数明显下降；行为单测不减 |
| **P2-2** | 桌面窗口默认尺寸与横屏播放体验（非系统勿扰） | 0.5–1d | 宽屏可读，不阻断 |
| **P2-3** | macOS 签名/公证调研（分发） | 0.5d | 笔记：是否需要 Apple 账号；unsigned 仍可内测 |
| **P2-4** | Android 可选 media_kit 后端（**默认勿开**） | 1d+ | 仅 debug flag；回归 Media3 为主 |
| **P2-5** | 统一 UA/Request 策略常量 | 0.25d | 减少漂移 |
| **P2-6** | 明确 **不做** 列表再贴一次：推荐流、动态、完整 pl_player、桌面系统闹钟 1:1、PGC 破解 | 0 | 路线图页脚 |

### 明确不做（防守 PiliPlus 化）

- 搬运 PiliPlus `pl_player` / 大段 GPL 粘贴  
- 首页推荐/动态/全面社交  
- 桌面精确闹钟与系统勿扰 1:1  
- 为「全能客户端」重写导航信息架构  

---

## 5. 建议的未来 Agent 并行切分

沿用 Wave 文件所有权；**冲突文件唯一写者**。

| Agent | 所有权（建议） | 对应项 | 禁止 |
|-------|----------------|--------|------|
| **A-AUTHCOOKIE** | `bilibili_auth_service.dart`、`cookie_header_provider.dart`、`login_page.dart`（桌面模式）、相关 test | P0-1, P1-2 | 不改 `media_kit_playback_service` 逻辑（除非构造注入）；不改 Kotlin |
| **B-PLAYHARDEN** | `media_kit_playback_service.dart`、`bilibili_playurl_service.dart`、playback tests | P0-3, P1-3, P1-4 | 不改 `player_page` 大段；不改 auth |
| **C-SMOKE-DOCS** | `docs/**`、`README.md`、`codemagic.yaml` 注释、`PLAYBACK_BACKEND.md`；**只写** smoke 报告 | P0-2, P1-1, P1-6, P2-6 | **不改** `lib/**`（除被明确授权的字符串） |
| **D-CI** | `.github/workflows/*`、可选 `codemagic.yaml` 结构 | P1-5, R12 标注 | 不改业务 Dart |
| **E-PLAYER-SPLIT** | `player_page.dart` + 新建 `lib/features/player/**` 抽出文件 | P2-1 | 与 B 错开时间；先 rebase auth/playback harden |
| **F-PRODUCT-DESKTOP**（可选） | home/layout/键盘残留、窗口 | P2-2 | 不碰 playback 核心 |

**推荐并行波次：**

```
Week 1 day 1–2:  A-AUTHCOOKIE ║ D-CI ║ C-SMOKE-DOCS(文档先改)
Week 1 day 2–3:  B-PLAYHARDEN（等 A 合并后做 cookie 集成冒烟）
Week 1 day 3–4:  C 执行真机 smoke，写 SMOKE 报告
Week 2:          E-PLAYER-SPLIT 与 F 可选；P1 收尾
```

Merge 顺序：**Auth/Cookie → Play harden → Docs/CI**；`player_page` 仅 A（最小）与 E 可碰。

---

## 6. CI / 构建态势（快照）

| 管道 | 平台 | analyze | test | build | 备注 |
|------|------|---------|------|-------|------|
| GHA `windows-build.yml` | windows-2022 | ✓ | ✓ | windows release | Flutter **3.44.9** pin；master/tags/workflow_dispatch |
| CM `android-apk` | mac_mini_m2（free） | ✓ | ✓ | apk | 无 keystore 则 debug 签名 |
| CM `macos-build` | mac | ✓ | —（yaml 未跑 test） | unsigned zip | 与 Android 不对称 |
| CM `windows-build` | windows_x2 | — | — | — | **free plan 阻断** |
| 本地 artifacts | — | — | — | b4 apk / b2 mac zip | 未证明含 media_kit wire 后重建 |

**建议姿势：** Windows 真源 = GHA；CM 专注 Android+macOS；PR 用轻量 Linux analyze+test。

---

## 7. 与 Plan 成功标准对照

| Plan 里程碑 | 状态 |
|-------------|------|
| M1 契约 + playurl/cookie/surface，Android 默认 native | **达成** |
| M2 MediaKitPlaybackService open + 状态流 | **达成（单测/fake）** |
| M3 桌面 factory 默认 media_kit；focus 测绿；analyze/test 绿 | **代码达成** |
| 用户可感知：Win/mac 装包播公开视频 + focus 跟播 | **未证实**（依赖 R1–R2） |

---

## 8. Executive summary（≤15 行）

1. **HEAD `ac131d0`**：media_kit Wave 0–3 已合并，桌面默认 `MediaKitPlaybackService`；Home 宽屏本机历史 + 播放快捷键已上。  
2. **Android 主线仍健康**；桌面从「能编译的壳」变成「实验性可播架构」，但 **会话闭环未完成**。  
3. **CRITICAL**：Auth Cookie（channel）与 Playback Cookie（prefs）在桌面 **分裂** — 不修则登录后高清/稳播不可靠。  
4. **CRITICAL**：缺 Win/mac **真机 smoke**；单测 299 绿 ≠ 能播。  
5. **MAJOR**：EDL 无降级、文档/CM 注释仍写「无桌面播放」、进度双键、`player_page` 6.6k 行。  
6. **CI**：GHA Windows 可用；CM Android/macOS 可用；CM Windows 免费计划不可用 — 接受并写清。  
7. **1–2 周 P0**：Cookie 单源 → EDL fallback → 桌面 smoke 记录。  
8. **P1**：文档对齐、Login 桌面 UX、playurl 重试、截帧、PR analyze+test。  
9. **P2**：拆 player_page、窗口体验；**不做** PiliPlus 化与桌面系统闹钟。  
10. **并行**：A-AUTHCOOKIE ∥ D-CI ∥ C-DOCS → B-PLAYHARDEN → smoke → E-SPLIT。  
11. Sibling `REVIEW_PLAYBACK` / `REVIEW_PRODUCT_DESKTOP` 就绪后可修订本报告细节，**不改变 P0 排序**。  
12. 北极星不变：**专注桌面客户端，克制范围**。

---

## 9. 本轨有序 Next-step PRs（仅 NEXT_STEPS / 战略轨）

> 战略轨以 **文档与编排** 为主；实现 PR 由对应 agent 开，此处给 **推荐提交顺序与命名**。

| Order | PR 标题（建议） | Owner agent | 对应 |
|------|-----------------|-------------|------|
| 1 | `fix(auth): desktop cookie store shares prefs with playback` | A-AUTHCOOKIE | P0-1 |
| 2 | `fix(playback): fall back to video-only when EDL open fails` | B-PLAYHARDEN | P0-3 |
| 3 | `docs: align desktop media_kit status across README and Codemagic` | C-SMOKE-DOCS | P1-1 |
| 4 | `test(desktop): add smoke checklist results for win/mac playback` | C-SMOKE-DOCS | P0-2 |
| 5 | `feat(login): prefer cookie login on desktop / hide broken webview on Windows` | A-AUTHCOOKIE | P1-2 |
| 6 | `ci: add PR workflow for flutter analyze and test` | D-CI | P1-5 |
| 7 | `fix(playurl): backup URL retry and clearer CDN errors` | B-PLAYHARDEN | P1-3 |
| 8 | `feat(playback): media_kit screenshot path for captureCurrentFrame` | B-PLAYHARDEN | P1-4 |
| 9 | `refactor(player): extract watch-history and init pipeline from PlayerPage` | E-PLAYER-SPLIT | P2-1 |

**本文件职责：** `docs/agent-reports/REVIEW_NEXT_STEPS.md` 只更新战略结论；**不**改 `lib/**`。

---

## 10. 参考路径（只读）

- Plan: `docs/PLAN_MEDIA_KIT_PLAYBACK.md`  
- Backend matrix: `docs/PLAYBACK_BACKEND.md`  
- CI docs: `docs/CODEMAGIC.md`, `codemagic.yaml`, `.github/workflows/windows-build.yml`  
- Wave reports: `docs/agent-reports/REPORT_{FOUNDATION,PLAYURL,COOKIE,SURFACE,MEDIAKIT,WIRE}.md`  
- Key code: `lib/services/playback_service_factory.dart`, `media_kit_playback_service.dart`, `cookie_header_provider.dart`, `bilibili_auth_service.dart`, `features/player/player_page.dart`, `features/home/home_watch_history_section.dart`

---

*End of REVIEW_NEXT_STEPS*
