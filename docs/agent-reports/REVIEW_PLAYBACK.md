# REVIEW_PLAYBACK — media_kit / PlaybackService 迁移与桌面播放就绪性

**仓库:** `/home/cnic/work/FocuBili`  
**基线:** `master` @ `ac131d0` (`feat: desktop home watch-history grid and player shortcuts`)  
**审查范围:** 只读；对照 `docs/PLAN_MEDIA_KIT_PLAYBACK.md`、W0–W3 agent reports、核心 playback 路径  
**日期:** 2026-08-08  
**约束:** 未改应用源码；未 push / 未改历史  

---

## 1. 审查结论（一句话）

**架构与接线（factory → MediaKit → playurl/cookie → surface → focus listen）在代码层已闭合，单元测试覆盖充分；真正挡住「桌面能播 + focus 跟播」的是：桌面登录 Cookie 与播放 Cookie 存储割裂、DASH 双轨 EDL 无降级、无真机/实包校验，以及缓冲期 phase 映射会误停 focus 计时。**

---

## 2. 迁移完成度对照 Plan

| 里程碑 | Plan 目标 | 现状 | 判定 |
|--------|-----------|------|------|
| M1 W0+W1 | 契约 + playurl/cookie/surface；Android 仍默认 native | contracts / factory stub→wire / playurl / cookie / surface 均落地；Android factory → `NativePlaybackService` | **达标（代码）** |
| M2 W2 | `MediaKitPlaybackService` open + 状态流 | 实现完整 + fake host 单测；EDL 双轨 | **达标（代码）** |
| M3 W3 | 桌面 factory 默认 media_kit；focus 测绿；analyze/test 绿 | factory 分支正确；`PlayerPage` 接 controller；键盘快捷键已接；`flutter test` 据 WIRE/上下文 300+ 绿 | **代码达标；用户可感知 M3（真播）未达标** |

### 数据流（已实现）

```
PlayerPage
  → createPlaybackService()
       desktop → MediaKitPlaybackService
       Android → NativePlaybackService
  → initialize() → textureId | MediaKitSurfaceHost.videoController
  → PlayerVideoSurface(Texture | media_kit Video)
  → states → _applyPlaybackSnapshot → _syncFocusPlaybackState
                  → FocusTimerController.updatePlaybackState(isPlaying)
```

| 组件 | 路径 | 角色 |
|------|------|------|
| Factory | `lib/services/playback_service_factory.dart` | Win/Linux/macOS → MediaKit；其余 → Native |
| Contracts | `playback_contracts.dart` | `PlayUrlManifest` / `BilibiliPlayUrlClient` / `CookieHeaderProvider` |
| Playurl | `bilibili_playurl_service.dart` | UGC DASH，选轨对齐 Kotlin 思路 |
| Cookie | `cookie_header_provider.dart` | Android channel；桌面 prefs |
| MediaKit svc | `media_kit_playback_service.dart` | open / streams / transport / selectQuality |
| Surface host | `playback_service_media_kit_ext.dart` | `MediaKitSurfaceHost` |
| Surface UI | `player_video_surface.dart` | Texture 优先，否则 `VideoController` |
| Wire | `player_page.dart` | factory + controller + shortcuts |
| Native | `native_playback_service.dart` + Kotlin | Android 不变 |

**未引入 PiliPlus 依赖；EDL 为独立实现（符合许可证约束）。**

---

## 3. Findings（按严重度）

### CRITICAL

#### C1. 桌面登录 Cookie 与播放 Cookie 存储未打通

**证据:**

- 登录：`LoginPage` → `BilibiliAuthService.loginWithCookie` → 默认 `PlatformBilibiliCookieStore`（MethodChannel `com.focubili.app/auth`）。
- 桌面 channel **无插件**时：`loginWithCookie` 在验证成功后 `replaceCookies` 会抛 `MissingPluginException` → 用户看到「当前设备暂不支持保存 Cookie」。
- 播放：`MediaKitPlaybackService` 默认 `createCookieHeaderProvider()` → 桌面为 `PrefsCookieHeaderProvider`（键 `focubili_bili_cookie_header`）。
- **没有任何 UI / auth 路径** 在登录成功时调用 `PrefsCookieHeaderProvider.replaceCookies`；prefs 与 auth 两套存储互不相通。

**影响:**

- 即使用户在桌面完成「Cookie 登录」验证，播放侧仍常读到 **空 Cookie**。
- 高清 / 会员 / 多数 CDN 流依赖 Cookie → playurl 或 `edl://` 拉流失败 → `PlaybackPhase.error` → focus 永远 `isPlaying=false`。
- Plan M3「登录可后置；cookie 空也能试公开流」仅覆盖极少数公开低码流；**不能**作为桌面产品路径。

**建议（playback track）:**

1. 桌面 `BilibiliCookieStore` 实现改为 prefs（或 auth 成功后 dual-write 到 `CookieHeaderProvider`）。
2. 或 `MediaKitPlaybackService` / factory 注入与 auth **同一** store。
3. 登录页文案去掉「只写 WebView」在桌面上的误导；提供明确的「粘贴 Cookie 供播放」入口并写入 prefs。

---

#### C2. DASH 音视频分轨仅 EDL，失败无自动降级

**证据:** `MediaKitPlaybackHelpers.buildPlayableResource`：有 `audioUrl` 则必走 `edl://` 双流；`openMedia` 失败直接 error phase；注释与 REPORT_MEDIAKIT / PLAYBACK_BACKEND 均标明 **无 video-only fallback**。

**影响:**

- 桌面真实播放的主路径几乎总是 video+audio DASH → 强依赖 libmpv EDL + 双 URL + 同一套 `httpHeaders`。
- EDL 不支持、header 未落到两轨、或单轨 403 时整段 open 失败 → 黑屏/错误，focus 无法跟播。
- **单元测试用 fake host，从未验证真实 libmpv EDL。**

**建议:**

1. open 失败时自动 fallback：`Media(videoUrl only)` 并提示「无声试播」或重试 audio 附加策略。
2. 记录失败原因（脱敏）便于诊断。
3. 桌面实机冒烟：公开 UGC + 登录 UGC 各至少 1 条。

---

### MAJOR

#### M1. 缓冲时 phase→`loading` 会打断 focus 跟播计时

**证据:**

- `applyHostEvent(MediaKitBufferingEvent)`：`buffering==true` → `phase = loading`（保留 `isPlaying`）。
- `PlayerPage._syncFocusPlaybackState`：`actuallyPlaying = snapshot.isPlaying && snapshot.phase == PlaybackPhase.ready`。
- 因此短暂缓冲 → `actuallyPlaying=false` → `FocusTimerController.updatePlaybackState(isPlaying: false)` → `FocusPauseReason.playback`。

**影响:** 网络抖动下专注计时反复暂停/恢复；与「跟播」产品目标冲突。Native Media3 是否同样把缓冲映射为 `loading` 未在本审查中逐行对照，但 media_kit 路径明确会触发。

**建议:** 缓冲保持 `phase=ready`（或增加 `isBuffering` 字段且 focus 忽略）；仅在真正 pause / ended / error / 切分 P 时停表。Seek 已有 `_focusSeekTransitionActive` 保护，缓冲应对齐同一策略。

---

#### M2. `selectQuality` 成功后仍 emit `phase: loading`

**证据:** `MediaKitPlaybackService.selectQuality` 成功分支：

```dart
_emit(_snapshot.copyWith(
  phase: PlaybackPhase.loading,  // 成功后仍为 loading
  ...
));
```

依赖后续 host 的 playing/duration 事件才回到 `ready`。若事件延迟或丢失，UI 长期 loading，且 **focus `actuallyPlaying` 为 false**。

**建议:** 成功 open 后与 `openVideo` 一致：在 host 已 playing 时设 `ready`，或至少 `play: true` 后根据 `wasPlaying` 合成终态。

---

#### M3. playurl 仅主 URL、无 CDN 轮换 / 无 durl 回退

**证据:**

- `PlayUrlManifest` 只暴露单个 `videoUrl` / `audioUrl`；`readMediaUrls` 虽收集 backup，但 manifest 只取 `urls.first`。
- Native Kotlin 有过期地址刷新 playurl / backup 轮换逻辑；Dart 客户端 **无** 403/404 重试。
- 仅 DASH（`fnval=16`）；无 `durl`/FLV；无 PGC/bangumi；无 WBI。

**影响:** 桌面长会话或 CDN 掐流时比 Android 更容易一次性失败；大会员番剧等不在范围内（可接受为范围外，但应文档化）。

**建议:** manifest 带 `List` 主备 URL；media_kit error/HTTP 失败时换备线或 re-fetch playurl（对齐 native 最小集）。

---

#### M4. 无桌面端到端 / 实包播放验证

**证据:** 全套测试为 VM + fake Player / fixture JSON；`MediaKit.ensureInitialized` 仅 `main()`；CI Windows workflow 有 `flutter build windows`，但 **无** 启动后 playurl+libmpv 冒烟。Linux 运行时依赖 `media_kit_libs_video`/系统 mpv，文档称 residual risk。

**影响:** 「desktop compiles」≠「能播」；回归易在合并后静默坏掉。

**建议:** 手工 checklist + 可选 integration 测试（注入真实短 BV 或录制 HTTP）；发布说明标明实验性直至 checklist 勾完。

---

#### M5. `captureCurrentFrame` 桌面恒为 null

**证据:** `MediaKitPlaybackService.captureCurrentFrame` → `null`；`PlayerPage` focus 结束 / 笔记截帧调用该 API。

**影响:** 桌面 focus 完成卡片、笔记贴帧 **无画面**；计时跟播本身不依赖截帧，但 focus 产品体验残缺。

**建议:** `player.screenshot()` + `path_provider` 写 JPEG（MEDIAKIT report 已列 follow-up）。

---

### MINOR

#### m1. `openVideo` 在 host 事件前乐观 `isPlaying: true`

成功 open 后立即 `_emit(..., isPlaying: true, phase: ready|…)`。若随后 error 事件到达会纠正；短暂不一致一般可接受。更稳妥是信任 `MediaKitPlayingEvent`。

#### m2. 桌面亮度 / PiP 为 stub

`setScreenBrightness` 仅内存；`enterPictureInPicture` → false。符合 plan 桌面降级，需在 UI 隐藏或禁用 PiP 入口避免「点了没反应」（若尚未隐藏）。

#### m3. 进度恢复双源

`MediaKit` 用 prefs 键 `focubili_mk_playback_*`；Native 另有通道存档。跨端（手机↔桌面）不共享进度——可接受，建议文档一句。

#### m4. `PlayerVideoSurface` 优先 textureId

同时传 texture + controller 时走 Texture。当前 desktop texture 恒 null，无问题；双后端实验同页时需注意。

#### m5. iOS / Web

Factory 走 Native（Android 向 channel）；iOS 无 Media3 对等实现——非本阶段目标，避免在商店文案声称 iOS 可播。

#### m6. 键盘快捷键

`player_keyboard_intents.dart` + `PlayerPage._wrapWithDesktopShortcuts` 已接空格/方向/F/M/C 等，输入框内忽略。与 playback 后端无关，有利于桌面可用性；**不**替代真实出画与 focus 状态正确性。

#### m7. 登录页文案

「内容只写入本应用的 WebView 会话容器」在桌面不准确（见 C1）。

#### m8. 单测未覆盖「buffering → focus pause」链路

`focus_timer_controller_test` 直接调 `updatePlaybackState`；无 widget 级 media_kit buffering → focus 集成测。

---

## 4. 阻断「桌面播放 + focus 跟播」的 Gap 清单

按依赖顺序（任一未解都会让用户路径失败或体验不合格）：

| # | Gap | 严重度 | 阻断点 |
|---|-----|--------|--------|
| G1 | 桌面 Cookie：登录 store ≠ 播放 prefs；无可靠写入 UX | CRITICAL | 多数视频根本 open 失败 |
| G2 | 真实 libmpv + EDL 双轨未设备验证；无 video-only fallback | CRITICAL | 有 cookie 仍可能无声/失败/黑屏 |
| G3 | 缓冲 phase=loading → focus 停表 | MAJOR | 「能播」但跟播计时不稳 |
| G4 | selectQuality 成功后卡在 loading 的风险 | MAJOR | 切清晰度后 focus/UI 异常 |
| G5 | 无 CDN backup / re-fetch | MAJOR | 长播/弱网脆弱 |
| G6 | 无 E2E 冒烟（公开流 + 登录流 + focus 关联） | MAJOR | 无法宣布 M3 用户可感知完成 |
| G7 | 截帧 null | MAJOR（体验）/ 非硬阻断计时 | focus 结束帧、笔记 |
| G8 | Linux 打包/libmpv 运行时 | MAJOR（Linux） | 部分发行版跑不起来 |
| G9 | 亮度/PiP stub、PGC 不支持 | MINOR/范围外 | 需产品预期管理 |

**Focus 接线本身（非 gap）:**  
`states` → `_syncFocusPlaybackState` → `updatePlaybackState` / `completeForPlaybackPart` 逻辑完整；问题在 **上游 snapshot 语义（G3/G4）与能否进入 ready+playing（G1/G2）**。

---

## 5. 正确性要点（已做对的）

1. **双后端边界清晰：** Android 不强制 media_kit；桌面不走 Android channel。
2. **PlaybackService 方法表未炸裂：** surface 用 `MediaKitSurfaceHost` 扩展，避免改 interface 全家桶。
3. **Playurl 选轨** 与 Kotlin 同思路（qn、AVC 优先、accept_quality、安全 CDN host）。
4. **Cookie 仅参数注入 playurl**，服务不直接碰 WebView。
5. **HTTP 头**（Referer/UA/Origin/Accept-Encoding: identity/Cookie）挂在 `Media.httpHeaders`。
6. **PlayerPage** 最小 wire：factory、controller、`PlayerVideoSurface` 双参；focus 监听未改状态机。
7. **可测性：** `MediaKitHostFactory` / fake playurl / cookie memory；factory 与 helpers 单测扎实。
8. **许可证：** 无 PiliPlus 源码粘贴依赖。

---

## 6. 测试与 CI 观察

| 项 | 状态 |
|----|------|
| 契约/factory/playurl/cookie/surface/mediakit 单测 | 有，WIR E 报告全量绿（~299+；上下文称 307） |
| Live `Player` / libmpv | **无** |
| 真实 playurl 网络 | **无**（有意） |
| Windows `flutter build windows` | workflow 存在（编译门禁，非播放门禁） |
| Focus 与 buffering 集成 | **无** |
| 桌面 cookie 登录→播放 | **无** |

---

## 7. 有序 Next-Step PRs（仅 playback track）

> 不包含无关功能（首页网格、推荐等）。每 PR 应可独立 review + 测试。

### PR-P1 — 桌面 Cookie 统一（解锁真播）

- **目标:** 登录与 `MediaKitPlaybackService` 读同一 cookie 源。  
- **方向:** 桌面 `BilibiliCookieStore` → prefs 实现，或 auth 成功 dual-write `CookieHeaderProvider`；修正 LoginPage 桌面文案；单测 store 读写。  
- **验收:** 桌面粘贴含 SESSDATA 的 cookie 后，`createCookieHeaderProvider().readCookieHeader()` 非空；playurl 请求带 Cookie 头。  
- **关闭:** C1 / G1  

### PR-P2 — EDL 失败降级 + 错误可读

- **目标:** `openMedia` / error 流检测到失败时 fallback video-only（或 document 明确策略）；用户可见中文错误。  
- **验收:** fake host `failOpen` 后可选二次 open；单测覆盖 fallback。  
- **关闭:** C2 的代码侧；G2 部分  

### PR-P3 — Focus 友好的 phase/buffering 语义

- **目标:** 缓冲不把 `phase` 打成会停表的 `loading`；或 focus 只看 `isPlaying`（需评估 ended/error）。修复 `selectQuality` 成功终态。  
- **验收:** 单测 `applyHostEvent` + focus_controller：buffering 期间 running 会话不因 phase 误 pause；selectQuality 后能回到 ready。  
- **关闭:** M1 / M2 / G3 / G4  

### PR-P4 — playurl 主备与开播重试

- **目标:** manifest 携带 backup 列表；403/404/error 时换 URL 或 re-fetch（对齐 native 最小行为）。  
- **验收:** fixture 单测 backup 选择；失败重试计数有上限。  
- **关闭:** M3 / G5  

### PR-P5 — 桌面冒烟清单 + 可选截帧

- **目标:** `docs/` 或本目录 checklist：Windows/Linux 公开 BV、登录 BV、focus 关联起停、切 P、快捷键；实现 `captureCurrentFrame`（screenshot→文件）。  
- **验收:** 维护者按清单手工勾选；截帧返回非 null 路径。  
- **关闭:** M4 / M5 / G6 / G7  

### PR-P6 — Linux 运行时说明 / 打包（按需）

- **目标:** README/CODEMAGIC 写清 libmpv/`media_kit_libs_linux` 依赖；CI 若做 Linux 包则安装依赖。  
- **关闭:** G8  

**推荐合并顺序:** P1 → P2 → P3 → P5(最小手工冒烟) → P4 → P6。  
**P1 未合并前不要宣称桌面播放可用。**

---

## 8. 非目标 / 不在本 track 追责

- 整模块搬 PiliPlus `pl_player`
- 桌面系统勿扰 / 精确闹钟 1:1
- Android 双后端默认改 media_kit
- PGC/bangumi / WBI（除非 UGC playurl 被服务端收紧）
- 改 focus 状态机业务规则（仅消费 snapshot 语义）

---

## 9. Executive Summary（≤15 行）

1. W0–W3 代码迁移 **已闭合**：桌面 `MediaKitPlaybackService`，Android Native，surface/focus 已接线。  
2. 单测与 analyze 门禁健康；**真机 DASH+libmpv+cookie 未验证**。  
3. **CRITICAL:** 桌面登录 Cookie（channel）与播放 Cookie（prefs）**割裂**，多数流无法带会话播放。  
4. **CRITICAL:** DASH 双轨 **强制 EDL**、无降级，实盘失败面大。  
5. **MAJOR:** 缓冲→`loading` 导致 focus **误停表**；`selectQuality` 成功后可能卡 loading。  
6. **MAJOR:** 无 backup/re-fetch；截帧桌面 null；无 E2E 冒烟。  
7. Focus 监听链路本身正确；阻塞在 **snapshot 语义 + 能否 open 成功**。  
8. 键盘快捷键已就绪，不替代出画验证。  
9. 未引入 PiliPlus；双后端决策执行正确。  
10. **Next PRs:** P1 Cookie 统一 → P2 EDL fallback → P3 buffering/focus phase → P5 冒烟(+截帧) → P4 主备重试 → P6 Linux 运行时。

---

## 10. Ordered next-step PRs（playback only，速查）

1. **PR-P1** 桌面 Cookie 与 auth/播放同源 + 登录 UX  
2. **PR-P2** EDL 失败 → video-only fallback + 错误文案  
3. **PR-P3** buffering/selectQuality 的 phase 与 focus 跟播语义  
4. **PR-P5** 桌面手工冒烟清单 + `captureCurrentFrame`  
5. **PR-P4** playurl backup / re-fetch  
6. **PR-P6** Linux libmpv 打包与文档  

---

*End of REVIEW_PLAYBACK.md*
