# REVIEW_POST_FIX — 并行修复质量与残余风险

| 字段 | 值 |
|------|-----|
| **Scope** | 仅 `ac131d0..HEAD` 三条并行修复 + 测试对齐（非整栈 media_kit 复盘） |
| **Repo** | `/home/cnic/work/FocuBili` |
| **HEAD** | `60e4bf6`（`master`） |
| **Date** | 2026-08-08 |
| **Mode** | 只读代码审查；**未**改应用源码 |
| **Prior (部分过期)** | `REVIEW_PLAYBACK.md`、`REVIEW_NEXT_STEPS.md`、`FIX_*.md` |

## 审查范围（commits）

| Commit | 主题 |
|--------|------|
| `8df0895` | focus buffer：`isFocusPlaybackActuallyPlaying` |
| `db3d2cc` (+ merge `4c08f29`) | history resume：`PlayerRouteArgs` / `WatchHistoryLauncher` / router |
| `832107f` (+ merge `c1a75e7`) | desktop cookie prefs + docs honesty + login UX |
| `47e6828` | history/login 测试对齐 |
| `60e4bf6` | Windows login 测试平台分支 |

云构建（上下文）：Windows GHA + Codemagic android/macos 在测试修复后报绿。

---

## 1. 各修复是否真正关掉目标 bug？

### 1.1 Focus buffer — **是（代码层闭环）**

**原 bug：** `_syncFocusPlaybackState` 仅在 `isPlaying && phase == ready` 时算「在播」。media_kit rebuffer 经 `MediaKitBufferingEvent` 把 `phase` 打成 `loading`，且 `isPlaying` 可仍为 true → `FocusTimerController.updatePlaybackState(isPlaying: false)` + `FocusPauseReason.playback`。

**证据（修复）：**

```83:89:lib/features/player/player_page.dart
bool isFocusPlaybackActuallyPlaying(PlaybackSnapshot snapshot) {
  if (!snapshot.isPlaying) {
    return false;
  }
  return snapshot.phase == PlaybackPhase.ready ||
      snapshot.phase == PlaybackPhase.loading;
}
```

`_syncFocusPlaybackState` 改为调用该 helper（`1382`）。Seek 的 `_focusSeekTransitionActive` 窗口未改。

**宿主侧仍会发 buffering→loading（未改服务层，有意）：**

```609:618:lib/services/media_kit_playback_service.dart
      case MediaKitBufferingEvent(:final bool buffering):
        if (buffering &&
            current.phase != PlaybackPhase.error &&
            current.phase != PlaybackPhase.ended) {
          return current.copyWith(phase: PlaybackPhase.loading);
        }
        // ...
```

Focus 层现在在 `isPlaying==true` 时容忍 `loading`，与 FIX 意图一致。

**单测：** `test/focus_playback_actually_playing_test.dart` 覆盖 ready/loading × isPlaying、ended/error/idle。**无** widget 级「buffering 事件 → FocusTimer 仍 running」集成测。

**结论：** 目标 bug（rebuffer 误停专注）在 **PlayerPage 同步语义**上已关。残余见 §2.1 / §3。

---

### 1.2 History resume — **是（入口与路由闭环；进度双源仍在）**

**原 bug：** Home / 全量观看记录 `pushNamed(player, arguments: VideoPreview)`，无分 P CID、无 `lastPosition`。

**证据（修复）：**

- `WatchHistoryLauncher.resolvePart`：先 `lastPartPageNumber`，再 `lastPartTitle`；失败则 `initialPartCid=null`（玩家默认/原生 saved）。
- `buildRouteArgs`：非零 `lastPosition` → `initialPosition`；`initialPositionSource: history`。
- `HomeWatchHistorySection._openEntry` / `WatchHistoryPage._openEntry` → `WatchHistoryLauncher.open`。
- `AppRouter._buildPlayerPage`：`PlayerRouteArgs` | 旧 `VideoPreview` | Map 三形态。
- `PlayerPage._findInitialPart`：优先 `widget.initialPartCid`，再 `loadSavedPlaybackState`。
- `_applyPlaybackSnapshot`：`ready` 时若 `_pendingInitialPosition != null` → `_seekToRequestedInitialPosition`（snackbar「观看记录位置」）。

**单测：** `watch_history_launcher_test.dart`（resolve / route args / open push / router 兼容）；`watch_history_page_test` 断言 `PlayerRouteArgs` + history source。`home_watch_history_section_test` **未**断言 resume 参数（仅 UI 网格）。

**结论：** 「从历史打开丢分 P/进度」主路径已关。残余：无 CID 字段、双进度源冲突、seek 与 media_kit open start 竞态（§2.2）。

---

### 1.3 Desktop cookie + docs + login UX — **主目标是（Auth↔Playback）；Public content 仍裂**

**原 bug（REVIEW_PLAYBACK C1 / NEXT_STEPS R1）：** 桌面 `BilibiliAuthService` 默认 `PlatformBilibiliCookieStore`（MissingPlugin）；播放读 prefs `focubili_bili_cookie_header`。

**证据（修复）：**

- `PrefsBilibiliCookieStore` → 委托 `PrefsCookieHeaderProvider(prefsKey: kFocubiliBiliCookieHeaderPrefsKey)`。
- `createDefaultBilibiliCookieStore()`：Android → Platform；else → Prefs。
- `BilibiliAuthService` 默认 `cookieStore ?? createDefaultBilibiliCookieStore()`。
- `createCookieHeaderProvider()`：Android Channel；desktop Prefs — **同键**。
- Login：桌面默认 Cookie 模式；Windows 隐藏底部官方 WebView、phone/password 分栏引导「改用 Cookie」。
- README / CODEMAGIC / `codemagic.yaml` 头与实验性 media_kit + Cookie 同源叙述对齐。

**单测：** prefs store ↔ provider 互通；`loginWithCookie` 后 playback prefs 可读（desktop 宿主）；工厂类型不硬编码平台（Android 设备会 early-return 跳过互通断言）。

**Android 回归面：** Auth 与 playback **仍都走 channel**（Platform store / Channel provider），未引入 prefs 双写。Cookie 粘贴在 Android 仍写 WebView 容器 — 与修复前一致。

**未修消费者：** `BilibiliHttpPublicContentService` 默认仍 `const PlatformBilibiliCookieStore()`（§2.3）— 桌面投稿/WBI 会话路径可仍 MissingPlugin。

**结论：** 「登录成功但播放无 Cookie」桌面主路径已关。文档诚实度达标。Public content 与账号数据若依赖独立 store 实例，仍可能分裂。

---

### 1.4 CI / 测试对齐 — **是（门禁绿，断言偏松）**

- `47e6828`：history 错误 SnackBar 3s；page test 接受 `PlayerRouteArgs`；login 桌面 Cookie 默认。
- `60e4bf6`：Windows 上「进入官方手机号登录」**或**「改用 Cookie 登录」二选一 `expect(... || ...)`。

避免了 Windows GHA 因 UI 分支红。但 login 测试不再强制「非 Windows 桌面必须有官方手机号入口」（Linux CI 走 cookieDefault→tap 手机号→官方入口；Windows 走 guide）。平台矩阵靠运行时 `Platform`，无 `@TestOn` 分文件。

---

## 2. 新 bug / 边界情况

### 2.1 Focus — 未引入「永远不暂停」，但有相位语义债

| ID | 严重度 | 描述 |
|----|--------|------|
| F1 | **MINOR** | `loading + isPlaying` 一律算在播。正常 rebuffer **正确**。若未来某路径在「用户已 pause」却短暂留下 `isPlaying=true` + `loading`（异常宿主），会短暂误跑表。当前 media_kit `pause`/`error`/`completed` 会清 `isPlaying`；`selectQuality` 在 wasPlaying 时保持 playing+loading — **有意**（切清晰度应继续计时）。 |
| F2 | **MINOR** | 初开：`openVideo` 先 `loading + isPlaying:false` → 不计时；成功后 `isPlaying:true`。与 helper 一致。 |
| F3 | **MINOR** | 无集成测：纯 helper 矩阵 ≠ buffering 事件流 + `FocusTimerController` 会话状态。 |
| F4 | **MINOR**（预存，REVIEW_PLAYBACK M 相关） | `selectQuality` 成功后 emit 仍 `phase: loading`，依赖后续 playing/duration 事件回 `ready`。Focus 在 isPlaying 时已不误停；**UI** 若只认 ready 仍可能卡住。不在本次 helper 范围内。 |

**未出现：** 「focus never pauses」— `!isPlaying`、`ended`、`error`、`idle` 仍为 false。

---

### 2.2 History resume

| ID | 严重度 | 描述 |
|----|--------|------|
| H1 | **MAJOR** | **双进度源。** `WatchHistoryEntry.lastPosition`（launcher → seek）vs `MediaKitPlaybackService` prefs `focubili_mk_playback_*`（`openVideo` 按 **同 cid** 设 `Media` start）vs Android Media3 saved state。`initialPartCid` 优先于 saved part；**position** 上：若 history 带 `initialPosition`，PlayerPage 在 ready 时 **再 seek**，一般覆盖 open start。若 history 分 P 解析失败（`initialPartCid=null`）但 `lastPosition` 仍有值，会把 **A 分 P 的进度 seek 到默认/saved 分 P** → **错集进度**。 |
| H2 | **MAJOR**（边缘） | History **不存 CID**，只存 pageNumber + title。UP 重传改分 P 结构：page 撞号 → 错集；page 失效靠 title，title 重名取 **第一个** 匹配。 |
| H3 | **MINOR** | `lastPosition == 0` 时不传 `initialPosition`；若 media_kit saved 同 cid 有进度，会走 `restoredPosition` 提示 — 合理。若用户期望「历史显示 0 强制从头」而 mk saved 非 0，会恢复 mk 进度（产品歧义）。 |
| H4 | **MINOR** | `resolvePart` 失败时静默 null，无「无法定位分 P，已打开默认」提示；仅有后续 seek 成功/失败 snackbar。 |
| H5 | **MINOR** | Home section 打开成功后 `_reload()`；history page 不 reload（原行为）。并发 `_openingBvid` 门闩保留。 |
| H6 | **MINOR** | `PlayerInitialPositionSource.history` 在 focus 修复 commit 中提前加入 enum（并行 merge 时双方都加）— 当前 HEAD 一致，无冲突残留。 |

**未出现：** 裸 `VideoPreview` 路由破坏（router 仍兼容；搜索等入口未误伤）。

---

### 2.3 Cookie / login / docs

| ID | 严重度 | 描述 |
|----|--------|------|
| C1 | **MAJOR** | **`BilibiliHttpPublicContentService` 默认仍硬编码 `PlatformBilibiliCookieStore`**（`bilibili_public_content_service.dart:70`）。桌面登录写入 prefs 后，投稿风控/WBI 等走 public content 的读 Cookie 仍可能 **MissingPlugin 或空会话**。播放链路已通，**账号空间/部分需会话的公开接口**未统一。 |
| C2 | **MINOR** | Android Cookie 粘贴仍只写 WebView channel；playback 也读 channel — **无双写 prefs**。未发现 Android 被改成 prefs 导致登录/播放分裂的回归。 |
| C3 | **MINOR** | Web（`kIsWeb`）走 Prefs store；若未来上 Web 播放需再验。 |
| C4 | **MINOR** | Windows 隐藏官方 WebView；macOS/Linux 仍可开 WebView。WebView 登录成功写 **Prefs store**（桌面默认），与粘贴路径一致 — 好。若 WebView 插件在 Linux 不稳，用户仍可 Cookie。 |
| C5 | **MINOR** | Login 文案 Android 仍写「只写入 WebView」；桌面写 prefs+播放同源 — 正确分支。 |
| C6 | **MINOR** | Cookie 明文存 SharedPreferences — 桌面既有威胁模型；非本次引入，但登录打通后 **暴露面变大**（可播高清 = cookie 更「有用」）。 |
| C7 | **—** | Docs：README/CODEMAGIC 与 `PLAYBACK_BACKEND` 对齐；「compile-only shell」矛盾已移除。 |

**Android dual-write 回归：** **未观察到。** Auth/Playback 在 Android 仍单源 channel。

---

## 3. 测试缺口（Windows / Linux / Android）

| 区域 | 现有 | 缺口 |
|------|------|------|
| Focus helper | 相位矩阵单测 | 无 `applyHostEvent(buffering)` → `_syncFocusPlaybackState` → controller 集成；无 Android Media3 buffering 相位对照 |
| Focus 真机 | 无 | Win/mac：播放中断网/拖进度条，确认专注不因 rebuffer 停 |
| History launcher | resolve + push args 单测 | Home section **无** resume 参数断言；无「page 失效 + title 命中/双 title」；无「cid null + 非零 position」错集用例 |
| History E2E | 无 | 多 P 视频看 P2 中段 → 杀进程 → 历史打开 → 确认 P2+位置（Win media_kit + Android Media3 各一条） |
| Cookie bridge | Desktop prefs 互通（宿主非 Android 时） | **无** 编译期/条件导入的 Android 工厂断言（设备 CI 才走 Platform）；无 logout 后 playurl 无 Cookie 的自动化 |
| Public content store | 无针对默认 store 平台矩阵 | 桌面 `loadProfile`/投稿是否读到 prefs 会话 — **未测且代码仍 Platform** |
| Login widget | `hasOfficialPhone \|\| hasWindowsCookieGuide` | 弱断言：理论上两按钮皆无也…不会，但未 `Platform.isWindows` 显式分支期望；Linux/mac 与 Win 行为差依赖运行时 |
| CI 矩阵 | GHA Windows test 绿；CM android/macos 报绿 | Linux 本地/CI 测的是 Prefs 路径；**不能**代替 Android channel 仪测；无 mac 专用 login WebView 测 |

---

## 4. Findings 汇总（CRITICAL / MAJOR / MINOR）

### CRITICAL

*（本批并行修复引入或仍阻断「桌面登录可播」主路径的 CRITICAL：**无**。）*

先前 CRITICAL「桌面 Auth≠Playback Cookie」在 **Auth + MediaKit 播放** 路径上已关闭。整栈仍有的 CRITICAL（EDL 无降级、无真机 smoke）属 **media_kit 栈**，不在本 post-fix 范围重判，仅作依赖上下文。

### MAJOR

| ID | 区域 | 发现 |
|----|------|------|
| **M-H1** | History | 分 P 解析失败时仍应用 `lastPosition` → 可能 seek 到错误分 P |
| **M-H2** | History | 无 CID、仅 page/title；内容变更时错集风险 |
| **M-C1** | Cookie | `BilibiliHttpPublicContentService` 仍默认 Platform channel，桌面会话读与 Auth/Playback prefs **未对齐** |
| **M-P1** | Progress（预存，因 resume 更显眼） | `WatchHistory` / `focubili_mk_playback_*` / Media3 saved 三源；resume 后用户可见行为依赖顺序，缺单一真相文档与测试 |

### MINOR

| ID | 区域 | 发现 |
|----|------|------|
| m-F1 | Focus | 仅 helper 单测，无 buffering→timer 集成 |
| m-F2 | Focus | phase 仍复用 `loading` 表达 buffer（语义过载）；长期可加 `isBuffering` |
| m-F3 | Playback UX | `selectQuality` 成功终态 loading 依赖后续事件（预存） |
| m-H3 | History | 解析失败无用户提示；Home 缺 resume 单测 |
| m-H4 | History | `lastPosition==0` vs mk saved 非零的产品歧义 |
| m-C2 | Login test | Windows 断言过宽；无显式平台 expect 表 |
| m-C3 | Security | prefs 存完整 Cookie，打通后价值上升 |
| m-D1 | Docs | 诚实度 OK；仍须标明 public API 会话在桌面未完全统一（若暴露投稿） |

---

## 5. 逐项验收对照（Acceptance）

| 标准 | 结果 |
|------|------|
| 各 fix 是否关掉目标 bug（代码证据） | **Focus：是** / **History 入口：是** / **Desktop auth↔playback cookie：是** / **Docs：是** / **Login Win UX：是** |
| 新 bug / 边界 | 见 §2；最重为 **错分 P 进度**、**public content store**、**进度三源** |
| 测试缺口 Win/Linux/Android | 见 §3；CI 绿 ≠ 真机 resume/cookie/public |
| CRITICAL/MAJOR/MINOR | §4 |
| 本报告路径 | `docs/agent-reports/REVIEW_POST_FIX.md` |

---

## 6. 与过期复盘的映射

| 旧 ID（REVIEW_*） | 本批后状态 |
|-------------------|------------|
| REVIEW_PLAYBACK C1 / NEXT R1 Cookie 分裂 | **Auth+Playback 已修**；Public content **仍 MAJOR** |
| REVIEW_PLAYBACK M1 buffer→focus 停表 | **已修**（PlayerPage helper） |
| NEXT R4 文档 stale | **已修** |
| NEXT R7 Windows 登录 UX | **已修**（Cookie 优先 + 隐藏 WebView） |
| NEXT R5 进度双写 | **未修**；history resume 后更需治理 |
| EDL / 真机 smoke / capture null | **未修**（非本批 scope） |

---

## 7. Executive summary（≤15 行）

1. **Focus buffer（`8df0895`）**：代码层关掉 rebuffer 误停专注；helper 单测扎实；缺事件→timer 集成与真机确认。  
2. **History resume（`db3d2cc`）**：Home/全历史经 `WatchHistoryLauncher`+`PlayerRouteArgs` 恢复分 P/进度；router 向后兼容。  
3. **残余 resume：** 无 CID、解析失败仍 seek `lastPosition`（**MAJOR**）；与 mk/Media3 saved 进度三源并存（**MAJOR** 债）。  
4. **Desktop cookie（`832107f`）**：Auth prefs 与 playback 同键，关掉「登录成功播放无 Cookie」主 CRITICAL。  
5. **Android：** Auth/Playback 仍 channel 单源，**未见** prefs 双写回归。  
6. **未修：** `BilibiliHttpPublicContentService` 默认 Platform store → 桌面投稿/WBI 会话可能仍裂（**MAJOR**）。  
7. **Docs/Login UX/CI 测试分支：** 诚实度与 Windows 门禁绿达标；login 断言偏松（**MINOR**）。  
8. **本批无新 CRITICAL**；桌面「可播」仍依赖 EDL/真机等栈外项。  

### Ordered next PRs（本 track：post-fix 残余 only）

1. **PR-A — History resume 安全：** 仅当 `resolvePart != null`（或 cid 明确）时应用 `lastPosition`；失败 snackbar；单测错 page+非零 position。  
2. **PR-B — Public content cookie 工厂：** 默认 store 与 `createDefaultBilibiliCookieStore()` 对齐；桌面读写 prefs 单测。  
3. **PR-C — Focus 集成测：** `applyHostEvent(buffering)` + fake controller/`isFocusPlaybackActuallyPlaying` 管道，防回归。  
4. **PR-D — 进度源说明/收敛（可后置）：** 文档写清 history vs `focubili_mk_playback_*` vs Media3；可选 open 时 history 优先禁用同 bvid mk start。  
5. **PR-E — 平台 login 测试表（可后置）：** Win/非 Win 显式 expect，避免 `||` 掩盖回归。  

*非本 track（勿排进本序列）：* EDL fallback、桌面 smoke 清单、`captureCurrentFrame`、player_page 拆分。
