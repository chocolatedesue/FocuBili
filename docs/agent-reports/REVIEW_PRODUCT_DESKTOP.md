# REVIEW_PRODUCT_DESKTOP — 桌面产品 / UX 复盘（post-fix）

| 字段 | 值 |
|------|-----|
| **Scope** | 产品与桌面 UX（Home 历史续播、Focus 跟播、Login Cookie、快捷键、能力矩阵） |
| **Repo** | `/home/cnic/work/FocuBili` |
| **HEAD** | `60e4bf6`（`master`：`fix(test): login page assertions for Windows Cookie guide`） |
| **含合并** | history resume (`db3d2cc`)、focus buffer (`8df0895`)、desktop cookie/docs (`832107f`)、login test 对齐 |
| **Date** | 2026-08-08 |
| **Author** | Agent PRODUCT-DESKTOP（read-only；仅写本报告） |
| **约束** | 不改 `lib/**`；不 push；severity tags CRITICAL / MAJOR / MINOR |
| **先验（可能部分过时）** | `REVIEW_PLAYBACK.md`、`REVIEW_NEXT_STEPS.md`、`FIX_HISTORY_RESUME.md`、`FIX_FOCUS_BUFFER.md`、`FIX_DOCS_COOKIE.md` |

**产品北极星：** 可用的**桌面专注客户端**（能播 + 跟播计时 + 本机续看 + 可登录会话）；**不**做成 PiliPlus。

**本报告边界：** 产品 / 交互 / 桌面能力诚实度。深度 media_kit / EDL / playurl 细节以 `REVIEW_PLAYBACK.md` 为准，此处只写「用户能否完成路径」。

---

## 1. 一句话结论

**相对 `ac131d0` 前：三条产品阻塞线（历史续播、缓冲误停专注、桌面 Cookie 与播放同源）在代码层已闭合，单测与文案同步跟上；桌面「可用专注客户端」从产品视角仍是 Partial——真机 smoke 未闭环、macOS WebView 登录与 prefs 播放会话可能再次割裂、分 P 解析失败静默、Android 勿扰/闹钟设置在桌面仍完整露出且无效。**

---

## 2. 本轮 Fix 对照（产品验收）

| Fix | 产品意图 | 代码证据 | 产品判定 |
|-----|----------|----------|----------|
| **History resume** | 首页/全量历史点开 → 正确分 P + 进度 + 来源提示 | `WatchHistoryLauncher` → `PlayerRouteArgs`（cid/position/`history`）；Home + `watch_history_page` 均走 launcher；就绪后 `_seekToRequestedInitialPosition` + snackbar「观看记录位置」 | **Works（代码路径）**；part 解析失败见 P2 |
| **Focus buffer** | 正常 rebuffer 不杀专注计时 | `isFocusPlaybackActuallyPlaying`：`isPlaying && (ready‖loading)`；`test/focus_playback_actually_playing_test.dart` 矩阵 | **Works（逻辑+单测）**；缺桌面真缓冲 smoke |
| **Cookie / docs / login** | 桌面粘贴 Cookie = 播放会话；Windows 不进死 WebView；文档不再说「仅壳」 | `PrefsBilibiliCookieStore` + `kFocubiliBiliCookieHeaderPrefsKey`；`createDefaultBilibiliCookieStore` 非 Android → prefs；Login 桌面默认 Cookie，Windows 藏 Web 入口 | **Works（Cookie-first 主路径）**；macOS WebView 旁路见 M2 |

`REVIEW_PLAYBACK` / `REVIEW_NEXT_STEPS` 中的 **C1 Cookie 分裂**、**M1 缓冲停表** 在 HEAD 上应视为 **已修（代码）**；**C2 EDL 无降级**、**无真机 smoke** 仍属 playback/验证轨，产品上仍挡「敢说可用」。

---

## 3. Findings（按严重度）

### CRITICAL

#### C1. 桌面「能播 + 登录后高清」仍无产品级真机验收闭环

**现状：** 工厂已默认 media_kit；Cookie 键已统一；历史续播与 focus buffer 已接线。但仓库内 **无** `SMOKE_DESKTOP_PLAYBACK.md` 或等价平台矩阵记录（Win/mac 公开 BV、有 Cookie 清晰度、Home 续播、focus 起停）。

**产品影响：** 对外/对内仍只能说「experimental + 单测绿」，不能宣称「桌面可用专注客户端」。任一路径静默失败（EDL、CDN、Cookie 过期、libmpv 缺依赖）用户只会看到播放错误，专注永远等播。

**建议（产品轨配合）：** 固定 1 页 smoke 清单 + 执行记录（平台 × 场景 × 通过/失败）；不通过则不升「可用」叙事。实现细节归 playback 轨。

---

### MAJOR

#### M1. 分 P 解析失败时静默回退默认 P，仍可能 seek 到「错误分 P 上的正确秒数」

**证据：**

- 历史 **不存 CID**，只存 `lastPartPageNumber` + `lastPartTitle`（`WatchHistoryLauncher.resolvePart`）。
- 页码与标题都对不上 → `initialPartCid == null`，`buildRouteArgs` **仍会**带上 `lastPosition`（非 zero 时）。
- Player：`_findInitialPart` 无 requested cid → 走 `_findSavedPart` / 默认 `initialPart`；`initialPosition` 仍会在 ready 时 seek。
- **无**「未能匹配上次分 P」snackbar；用户可能只看到「已跳转到观看记录位置：mm:ss」，以为分 P 也对了。

**产品影响：** 多 P 合集 / UP 改标题 / 页码漂移时，续播**语义错误**且难自查。网格卡虽展示 `P{n} · title`，打开后无 mismatch 反馈。

**建议：**

1. `resolvePart == null` 且 entry 标明多 P 意图时：snackbar「未能匹配上次分 P，已打开默认分 P；进度仍按记录尝试恢复」或询问是否仍 seek。
2. 中期：历史写入 **cid**（与 page/title 并存），解析优先 cid。

#### M2. macOS/Linux「官方 WebView 登录」与 prefs 播放 Cookie 可能再次分叉

**证据：**

- 桌面 auth 默认 store = **prefs**（`PrefsBilibiliCookieStore`）。
- `_OfficialWebLoginPage` 轮询 `_authService.loadCurrentSession()` → 读的是 **prefs**，不是 WebView Cookie 罐。
- Windows：UI **隐藏**官方 Web 入口 + 不自动打开 → 主路径安全（Cookie 粘贴）。
- macOS/Linux：仍展示「打开 B 站网页登录」；用户在 WebView 登录成功后，**除非**另有原生把 WebView cookie 写入 prefs（当前 Dart 页未见 `WebViewCookieManager` → prefs 桥），`loadCurrentSession` 很难变 active → 登录卡住或「成功」与播放 Cookie 不一致。

**产品影响：** mac 上「看起来能网页登录」是 **假希望路径**；唯一可靠仍是 Cookie 粘贴。文案写「可尝试官方网页」偏乐观。

**建议（产品）：** 非 Windows 桌面也默认强调 Cookie；WebView 入口标注「实验 / 可能无法同步到播放会话」或桌面统一隐藏直至桥接完成。桥接属 auth 实现轨。

#### M3. 个性化设置中 Android 勿扰 / 权限管理在桌面完整露出且无效

**证据：**

- `personalization_settings_page`：`专注状态将手机设为勿扰模式`、`权限管理`（`AppRoutes.androidPermissions`）无 `Platform.isAndroid` 门闩。
- `FocusNotificationService`：全方法 `MissingPluginException` → 安全 false/no-op。
- 文案全程「手机 / Android 特殊访问」。

**产品影响：** 桌面用户打开开关 → 以为已勿扰；实际无系统效果。打断流程里「设置继续专注提醒 / 精确闹钟」同样 no-op，却可能 snackbar「已设置…」（取决于 `scheduleReminder` 返回值路径——channel 失败返回 false 时有「未获得…」类提示，但仍有 Android 专用对话框文案）。

**建议：** 桌面隐藏或 disable 勿扰开关与「权限管理」入口；副标题一句「桌面不提供系统勿扰与精确闹钟」。打断提醒在桌面改为「仅记录原因，不设系统闹钟」或隐藏时间选择。

#### M4. 播放失败 / 会话失效时产品恢复路径弱

**现状（产品层）：** Cookie 登录成功后无「会话健康」轻量指示（播放页是否带 Cookie、403 是否引导重新登录）。logout 会 `clear` 同键 prefs（路径正确），但过期 Cookie 残留时 playurl 失败文案未必指向「重新粘贴 Cookie」。

**建议：** 播放错误映射：会话类 → Snackbar/对话框 CTA「去登录（Cookie）」；设置或「我的」显示桌面会话：已登录 / 未登录（不展示 Cookie 原文）。

#### M5. 双进度语义仍可能让「续播」产品故事分叉（跨入口）

**证据：**

- 本机历史：`WatchHistoryService`（Home / 历史页 launcher 的真相源）。
- 后端：`loadSavedPlaybackState` / media_kit `focubili_mk_playback_*`（`initialPartCid == null` 时参与分 P 恢复；有 history cid 时优先 route）。
- 历史入口带 `initialPosition` 时走 route seek +「观看记录位置」；无 position 时可能走 native `restoredPosition` +「已跳转到上次进度」另一套文案。

**产品影响：** 从搜索打开 vs 从历史打开，提示文案与优先级不一致；用户难以建立单一心智模型。非立即炸裂，但续播故事要写进帮助/文案时需统一。

**建议：** 产品文案约定：**历史入口 = WatchHistory 为准**；其它入口 = backend saved state。长期再收敛存储（playback 轨）。

---

### MINOR

#### m1. Home 历史网格固定 `mainAxisExtent: 210`，宽列/长标题可能挤

**证据：** `HomeWatchHistorySection` 非滚动网格、行高常量 210；卡内 title 2 行 + owner + `P·title`。≥1200 四列时封面区仍靠 flex 分配，一般可用；极端字体缩放或超长标题可能裁切。

**建议：** 真机看 900 / 1100 / 1400 三档；必要时略增 extent 或 title `maxLines` 策略。

#### m2. 窄于 900 无首页历史，依赖「我的 → 观看记录」——合理但未提示

断点 `homeWatchHistoryBreakpoint = 900` 有单测。缩小桌面窗到 &lt;900 时历史区消失，无「去观看记录」引导。可接受；可选在首页专注卡附近一条 hint。

#### m3. 历史打开中全局 `_openingBvid` 互斥，无超时解锁

并发点击被挡（正确）；若 `lookupVideo` 挂起，卡片长期 spinner。建议超时 + 错误态（launcher 已有失败 snackbar，需保证 finally 清 `_openingBvid`——Home 已在 `open` 后清理；lookup 抛错也走 false 后清理，OK。仅极端 unmount 边界）。

#### m4. 键盘快捷键未在 UI 暴露速查

Space / Esc / ←→ / Shift+←→ / ↑↓ 音量 / F·F11 / M / C 已接，输入框内忽略（Esc 仍退出一层）。产品完整，但播放页无「? 快捷键」面板；桌面新用户发现成本高。

#### m5. 双击快进设置在桌面意义有限

个性化「双击快进快退」偏触控；桌面可保留默认关或副标题注明「主要影响触控」。

#### m6. 续播成功 snackbar 与控制条 resume notice 两套提示体系

History 强制 seek 用 `_showTransientSnackBar('已跳转到观看记录位置…')`；backend restore 用页内 `_resumeNotice`。不冲突但视觉不统一（MINOR）。

#### m7. `player_page` ~6624 行仍是产品迭代摩擦

非用户可见缺陷；任何历史/focus/快捷键小改都高回归成本。结构债，影响交付速度。

---

## 4. 分主题深潜

### 4.1 Home 观看历史网格（宽 ≥900）+ 续播 UX

| 项 | 行为 | 判定 |
|----|------|------|
| 断点 | `≥900` 显示；`900–1199` 3 列，`≥1200` 4 列；内容 maxWidth 1100 | **Works** |
| 数据 | 本机 `WatchHistoryService`，最多 12 条；文案「不与 B 站账号同步」 | **Works**（产品纪律正确） |
| 空/错/载 | empty / error+重试 / loading keys 齐全 | **Works** |
| 打开 | `WatchHistoryLauncher.open`；opening overlay；成功后 reload | **Works** |
| 续播参数 | cid（解析）+ position + `PlayerInitialPositionSource.history` | **Works** |
| 成功反馈 | 「已跳转到观看记录位置：…」；失败 seek：「…暂时无法跳转」 | **Works** |
| 分 P 失败 | 静默默认 P + 可能仍 seek | **Partial**（M1） |
| 全量历史页 | 同一 launcher | **Works** |
| 缩略图 backfill | 缺 URL 时 lookup 回填 | **Works**（网络失败则占位） |

**交互路径（期望）：** 宽屏 Home → 最近观看 → 点卡片 → lookup → Player（目标 P + 进度）→ snackbar。  
**正确性依赖：** 历史写入时的 page/title 与当前 `lookupVideo` parts 一致；CID 未持久化是结构缺口。

### 4.2 Focus 桌面：buffer 与 Android-only 诚实度

| 能力 | 桌面 | 说明 |
|------|------|------|
| 跟播计时（play/pause） | **Works（逻辑）** | `updatePlaybackState` ← snapshot；buffer 计为 playing |
| Seek 过渡不抖停 | **Works** | 既有 `_focusSeekTransitionActive` |
| 关联视频 / 完成对话框 | **Works** | UI 层跨平台 |
| 统计 / 分享文案 | **Partial** | 分享帧依赖 `captureCurrentFrame`（media_kit 仍空/未实现 → 无最后一帧） |
| 系统勿扰 | **Missing（有意）** | channel no-op；设置项却可见（M3） |
| 精确闹钟 / 打断提醒 | **Missing（有意）** | 同上；产品应标明 |
| 后台保活文案 | **Android-only** | 桌面勿展示厂商自启指南 |

**Buffer fix 产品验收标准：** 弱网播放中专注倒计时连续走，不因短暂 loading 进入「等待视频播放」。单测已锁矩阵；**真机未证**。

**诚实表述建议（设置/帮助）：**

> 桌面专注：计时与视频播放状态同步。系统勿扰、精确闹钟提醒仅 Android 提供；桌面请用本机勿扰或日历。

### 4.3 Login 桌面 / Windows Cookie-first + 与播放 prefs 一致性

| 项 | 状态 |
|----|------|
| 键名单源 | `kFocubiliBiliCookieHeaderPrefsKey = 'focubili_bili_cookie_header'` — Auth prefs store 与 `PrefsCookieHeaderProvider` **同一常量** |
| 默认 store | Android → Platform channel；else → Prefs |
| 桌面默认模式 | Cookie 分段 |
| Windows | 不自动 WebView；手机号/密码段引导回 Cookie；底栏隐藏「打开 B 站网页登录」+ 说明文案 |
| macOS/Linux | 仍可开 WebView（**风险 M2**）；文案推荐 Cookie |
| 登录成功 | `replaceCookies` → prefs → 播放可读 |
| 退出 | `logout` → `clear` 同键 |
| 与「播放偏好」键 | `PlaybackPreferencesService` 是另一套 UX 偏好（双击 seek 等），**不应**与 Cookie 键混淆；Cookie 一致性问题已在 auth/playback cookie 层对齐 |

**残留文案：** 非桌面 Cookie hint 仍写「只写入 WebView 会话容器」——Android 准确；桌面已分支。旧 `REVIEW_PLAYBACK` C1 过时。

### 4.4 键盘快捷键与新路径

| 快捷键 | 动作 | 与历史/focus/登录关系 |
|--------|------|------------------------|
| Space / MediaPlayPause | 播停 | 不经过历史；focus 跟 `isPlaying` |
| Esc | 笔记→全屏→返回 | 输入框内仍允许 |
| ← / → | ±5s；Shift ±10s | seek grace 保护 focus |
| ↑ / ↓ | 音量 | OK |
| F / F11 | 全屏 | OK |
| M | 静音 | OK |
| C | 显隐控制条 | OK |
| 输入框 | 忽略劫持（除 Esc） | 笔记/Cookie 粘贴页不误触 |

Bindings 在 `player_keyboard_intents.dart`，页面 `_wrapWithDesktopShortcuts`；**未**因 history resume / buffer / cookie 改动而损坏。登录页不在 Player Shortcuts 树下，Cookie 输入不受播放快捷键影响。

**缺口：** 无应用内速查（m4）；无「专注中禁用某键」需求——当前合理。

### 4.5 仍阻挡「可用桌面专注客户端」的产品清单

按用户故事，而非 media_kit 内核：

1. **未证实能稳定出画 + 有声**（真机/实包；EDL 等归 playback，但产品门禁依赖它）。  
2. **登录后会员/高清路径**依赖 Cookie 粘贴习惯 + 过期可感知恢复（M4）。  
3. **mac WebView 旁路**可能浪费支持成本（M2）。  
4. **多 P 续播错误且静默**（M1）伤害「继续看」信任。  
5. **桌面设置里的伪 Android 能力**（M3）伤害「专注环境」信任。  
6. **截帧/分享/笔记贴图**在桌面可能空（capture）——若营销强调「专注分享图」需降级文案。  
7. **无桌面窗口默认尺寸/最小尺寸产品规格**（可选体验，非阻断）。

**已不再阻断（相对上轮 CRITICAL 产品叙事）：**  
「登录成功但播放无 Cookie」「一点历史只开默认 P 零进度」「缓冲必停专注表」。

---

## 5. Works / Partial / Missing 矩阵（桌面）

| 能力 | 状态 | 备注 |
|------|------|------|
| 编译 / 单测门禁（据既有 CI 叙事） | **Works** | GHA Windows 等；本报告未重跑 |
| 桌面播放后端接线 | **Works** | factory → media_kit |
| 公开流真播 | **Partial** | 代码有；缺 smoke |
| Cookie 粘贴登录 → 同键供播放 | **Works** | prefs 单源 |
| Windows 避免死 WebView | **Works** | UI 门闩 |
| macOS WebView 登录 → 播放会话 | **Missing / 高风险** | 见 M2 |
| Home ≥900 历史网格 | **Works** | |
| 历史 → 分 P + 进度续播 | **Partial** | 匹配成功 Works；失败静默 |
| 续播来源 snackbar | **Works** | `history` 文案 |
| 全量历史页续播 | **Works** | 同 launcher |
| 播放快捷键 | **Works** | |
| Focus 跟播计时 | **Works（逻辑）** | 真机 Partial |
| Focus 缓冲不停表 | **Works（逻辑+单测）** | |
| Focus 关联 / 完成 UI | **Works** | |
| 系统勿扰 | **Missing** | 应隐藏设置 |
| 精确闹钟提醒 | **Missing** | 应降级文案 |
| 桌面截帧 / 分享封面 | **Missing / Partial** | capture 空 |
| PiP | **Missing** | 有意 |
| 系统亮度 | **Partial** | 仅内存/注释 |
| 推荐流 / 动态 | **Missing（有意）** | 非目标 |
| 文档与能力一致 | **Works** | FIX_DOCS_COOKIE 后 |

**图例：** Works = 产品路径代码闭合且预期可演示；Partial = 主路径有但边角/未验证/静默失败；Missing = 无能力或不应宣称有。

---

## 6. 与先验报告差异（防双重记账）

| 先验 ID | 旧结论 | HEAD `60e4bf6` |
|---------|--------|----------------|
| PLAYBACK C1 Cookie 分裂 | CRITICAL | **已修（代码）** — 改记为回归防守 + smoke |
| PLAYBACK M1 buffer 停表 | MAJOR | **已修（代码）** |
| NEXT P0-1 Cookie 单源 | P0 | **已做** |
| NEXT P1-2 Login 桌面 UX | P1 | **大部分已做**（Windows 完整；mac WebView 仍虚） |
| NEXT R8 桌面 focus 周边 | 接受降级 | **仍成立**；UI 未标明 → 本报告 M3 |
| 历史无 resume | 隐含缺口 | **已修**；剩 part mismatch |

---

## 7. 有序 Next PRs（**本产品轨 only**）

不排 EDL/playurl/media_kit 内核（playback 轨）；不排 CI 基建。

| 序 | PR 主题 | 严重度 | 验收 | 估点 |
|----|---------|--------|------|------|
| **1** | **分 P mismatch 诚实 UX**：`resolvePart==null` 时 snackbar；可选不 seek 或二次确认；历史写入 cid（若碰 model/service 需与 history owner 协调） | MAJOR M1 | 改标题 fixture：打开默认 P + 明确提示；匹配成功路径回归绿 | 0.5–1d |
| **2** | **桌面设置降级**：隐藏/disable 勿扰开关与 Android 权限管理入口；打断流桌面文案「不设系统闹钟」 | MAJOR M3 | 桌面个性化无「手机勿扰」；Android 不变 | 0.5d |
| **3** | **桌面登录旁路收口**：mac/Linux WebView 入口降级标注或隐藏；帮助三步 SESSDATA | MAJOR M2 | 桌面主路径只推 Cookie；无「登了播不了」支持单 | 0.25–0.5d |
| **4** | **会话失效 CTA**：播放/导航错误 →「重新 Cookie 登录」；「我的」会话状态一句 | MAJOR M4 | 过期 Cookie 用户能自助 | 0.5d |
| **5** | **产品 smoke 清单（只写 docs + 手工）**：《桌面专注客户端》5 条路径勾选表，挂 `docs/agent-reports/SMOKE_DESKTOP_PRODUCT.md` | CRITICAL C1 的产品半边 | 有执行记录才改 README「可用」措辞 | 0.5d |
| **6** | **播放页快捷键速查**（`?` 或首次提示） | MINOR m4 | 桌面可发现 | 0.25d |
| **7** | **续播文案统一**（历史 vs backend restore 一种视觉） | MINOR m6 / M5 文案 | 不双提示打架 | 0.25d |

**明确不做（本轨）：** 桌面系统勿扰 1:1、桌面精确闹钟、推荐流、PGC、PiliPlus 播放器搬运。

**并行建议：** PR1 ∥ PR2 ∥ PR3；PR5 与 playback smoke 可同一天不同文件。PR1 若写 cid 避免与 playback 大改 `player_page` 同刻抢锁。

---

## 8. 测试与证据索引（只读）

| 区域 | 测试 / 文件 |
|------|-------------|
| 历史 launcher | `test/watch_history_launcher_test.dart` |
| Home 网格 / 断点 | `test/home_watch_history_section_test.dart` |
| Focus buffer | `test/focus_playback_actually_playing_test.dart` |
| 快捷键 | `test/player_keyboard_shortcuts_test.dart` + `player_keyboard_intents.dart` |
| Cookie 键 | `lib/services/cookie_header_provider.dart`、`bilibili_auth_service.dart`（`PrefsBilibiliCookieStore`） |
| Login UX | `lib/features/profile/login_page.dart` |
| Fix 说明 | `FIX_HISTORY_RESUME.md`、`FIX_FOCUS_BUFFER.md`、`FIX_DOCS_COOKIE.md` |

---

## 9. Executive summary（≤15 行）

1. HEAD `60e4bf6`：历史续播、focus 缓冲不停表、桌面 Cookie↔播放同键、Windows Cookie-first —— **产品主路径代码已齐**。  
2. **CRITICAL 仅余：** 无桌面真机/实包产品 smoke，不能升格「可用客户端」叙事。  
3. **MAJOR：** 分 P 匹配失败静默（M1）；mac WebView 登录与 prefs 可能假路径（M2）；Android 勿扰/权限在桌面裸露（M3）；会话失效恢复弱（M4）；双进度心智（M5）。  
4. Home ≥900 网格 + launcher 续播 + history snackbar：**Works**；part miss：**Partial**。  
5. Focus 跟播/buffer：**Works（逻辑）**；DND/闹钟：**Missing（应标明）**；截帧分享：**Partial/Missing**。  
6. 快捷键与新路径：**兼容良好**；缺速查面板。  
7. 先验 Cookie/buffer CRITICAL/MAJOR 在 HEAD **勿再当未修债**重复开票。  

### Ordered next PRs（产品轨）

1. 分 P mismatch 提示（+ 可选 cid 持久化）  
2. 桌面隐藏勿扰/Android 权限伪设置 + 打断提醒文案降级  
3. 桌面 WebView 登录降级/隐藏，Cookie 三步说明  
4. 会话失效 → 重新登录 CTA  
5. 产品 smoke 清单与执行记录（与 playback 真机配合）  
6. 快捷键速查（可选）  
7. 续播提示视觉统一（可选）
