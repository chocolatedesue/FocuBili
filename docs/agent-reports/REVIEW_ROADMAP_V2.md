# REVIEW_ROADMAP_V2 — 修复合并后的战略复盘与 1–2 周路线图

| 字段 | 值 |
|------|-----|
| **Scope** | 后修复态：shipped vs half-done、风险表刷新、P0/P1/P2、并行 agent 切分 |
| **Repo** | `/home/cnic/work/FocuBili` |
| **HEAD** | `60e4bf6`（`master`）— full: `60e4bf6e571350dd7980382ab31b77d79211cb2e` |
| **Baseline（旧报告）** | `REVIEW_NEXT_STEPS.md` / `REVIEW_PLAYBACK.md` @ `ac131d0`（pre-fix） |
| **Date** | 2026-08-08 |
| **Author** | Agent ROADMAP_V2（read-only code review；仅写本报告） |
| **北极星** | 可用的**桌面专注客户端**；**不**变成 PiliPlus |
| **用户信号** | **播放引擎已可用** → 除非残差风险仍高，**不**优先 EDL/playurl 重写；偏向 **产品打磨 + 桌面残留缺口** |

---

## 0. `git log ac131d0..HEAD`（本波修复）

| SHA | 摘要 | 关闭的旧项 |
|-----|------|------------|
| `8df0895` | focus：正常缓冲期间计时不因 `phase=loading` 误停 | REVIEW_PLAYBACK **M1/G3**；旧 P0 相关 focus 语义 |
| `832107f` | 桌面 Auth Cookie → prefs 与播放同键；文档对齐 media_kit；Windows 登录偏 Cookie | 旧 **R1/C1 CRITICAL**；旧 **P0-1 / P1-1 / P1-2** |
| `c1a75e7` | merge: desktop cookie prefs + docs honesty | — |
| `db3d2cc` | 观看历史续播：`PlayerRouteArgs` + part/position | 历史从「只开 BV」→ 可恢复分 P/进度 |
| `4c08f29` | merge: history resume × focus buffer（保留双方） | — |
| `47e6828` | 并行修复合并后 history/login 测试对齐 | CI 测试债 |
| `60e4bf6` | login widget 断言适配 Windows Cookie 引导 | GHA Windows 测试绿 |

**Diff 规模（`ac131d0..HEAD`）：** 23 files, +1596 / −93。业务面集中在 auth/cookie、login UX、history launcher、player focus helper、docs；**未**改 EDL open / playurl 选轨核心。

---

## 1. 形势摘要（Situation）— AFTER fixes

### 1.1 已交付 / 已闭合（shipped）

| 里程碑 | 证据 | 状态 |
|--------|------|------|
| **media_kit Wave 0–3** | factory → `MediaKitPlaybackService`；surface；playurl；wire | **代码层完成**（与 V1 同） |
| **桌面默认播放后端** | `createPlaybackService()` 桌面 → media_kit；Android → Media3 | **已接线** |
| **桌面 Cookie 单源** | `PrefsBilibiliCookieStore` + `kFocubiliBiliCookieHeaderPrefsKey`；auth 与 `CookieHeaderProvider` 同键 | **DONE（原 CRITICAL）** |
| **Windows / 桌面登录 UX** | 默认 Cookie 段；Windows 隐藏官方 WebView 主路径；文案说明 prefs 共享 | **DONE** |
| **文档诚实度** | README / `CODEMAGIC.md` / `codemagic.yaml` 头与 `PLAYBACK_BACKEND.md` 对齐 experimental media_kit | **DONE（原 MAJOR 文案）** |
| **Focus 缓冲不停表** | `isFocusPlaybackActuallyPlaying`：`isPlaying && (ready\|\|loading)` | **DONE（原 MAJOR）** |
| **历史续播** | `WatchHistoryLauncher` + `PlayerRouteArgs`；Home / 历史页走 launcher | **DONE** |
| **桌面 Home 历史 + 快捷键** | `ac131d0` 起已有；本波未回退 | **shipped** |
| **CI：GHA Windows @ HEAD** | `workflow_dispatch` run **31240730750** → **success**，`headSha=60e4bf6…`（analyze + test + `build windows`） | **绿** |
| **CI：中间失败已修** | `47e6828` 上 dispatch 曾 **failure**；`60e4bf6` 测试断言修复后绿 | **闭环** |
| **本地 CM 产物** | `artifacts/FocuBili-android-b4.apk`、`FocuBili-macos-b2.zip`（mtime 2026-08-08） | **存在**；与用户「60e4bf6 后 CM android/macos 绿」一致（本 agent **未**调 CM API 二次核验 build number↔SHA） |
| **Android 主线 v1.2.0** | `pubspec` `1.2.0+11` | **生产可用** |
| **用户确认** | 播放引擎 **works** | **提高「能播」置信度**；仍缺书面 smoke 矩阵 |

### 1.2 半完成 / 仍实验性（half-done）

| 项 | 现状 | 缺口 |
|----|------|------|
| **桌面「产品可用」叙事** | 架构 + Cookie + 用户能播 | 无 `SMOKE_DESKTOP_PLAYBACK.md`；无公开/登录/续播/focus 勾选矩阵 |
| **EDL 双轨** | 仍强制 `edl://` when audio；**无** video-only 自动降级（`PLAYBACK_BACKEND.md` Residual 仍写明） | 代码残差 **在**；用户称引擎可用 → **降为 P2 保险**，非本周主路径 |
| **playurl 主备** | fixture 收集 backup，manifest 仍主 URL | 长会话/CDN 掐流弱于 Android；**不**优先重写 |
| **`selectQuality` 终态** | 成功 open 后仍 `_emit(phase: loading)`，等 host 事件回 ready | 切清晰度窗口内 UI/focus 可能短暂异常；focus helper 已容忍 `loading+isPlaying`，**风险降级** |
| **`captureCurrentFrame`** | media_kit 仍 `return null`（注释 deferred path_provider） | 专注结束帧 / 笔记贴图桌面空 |
| **进度双写** | `WatchHistoryService`（UI）+ `focubili_mk_playback_*`（backend） | 语义未在 `PLAYBACK_BACKEND.md` 写清；跨后端不共享可接受 |
| **player_page 熵** | **~6624 行** god object | 快捷键/surface/focus helper 已外提一点；仍是合并冲突与回归面 |
| **桌面系统能力** | 通知/精确闹钟/勿扰 Android channel；PiP false；亮度内存 stub | **接受降级**；UI 是否处处隐藏未全面审计 |
| **CI 碎片** | GHA 仅 Windows 全量；**无** PR 级 Linux `analyze+test`；CM Windows free 不可用 | 发布门禁不对称 |
| **macOS 分发** | unsigned zip 内测级 | 签名/公证未做 |
| **Linux 打包** | 无官方 CI 产物；libmpv 运行时 | 文档级即可 |
| **PLAYBACK_BACKEND 微 stale** | Cookie 条仍偏「仍需路径」；路径已 prefs 打通 | 应用户向补一句「桌面 prefs 与 auth 同键」 |

### 1.3 相对 V1 的一句话变位

```
V1 (ac131d0):  能编译的实验架构 + CRITICAL 会话分裂 + focus 缓冲误停 + 文档说谎
V2 (60e4bf6):  会话闭合 + focus 跟播语义修好 + 历史续播 + 文档诚实 + 云构建绿
               + 用户确认能播
               → 主矛盾从「根本播不了」转为「产品打磨、残留桌面缺口、可维护性」
```

架构图不变：

```
FocusTimerController ──listen──► PlaybackService.states
                                      │
              ┌───────────────────────┴───────────────────────┐
              ▼                                               ▼
   MediaKitPlaybackService (desktop)              NativePlaybackService (Android)
        │ playurl + prefs cookie（与 Auth 同键）         │ Media3 channel
        ▼                                               ▼
   PlayerVideoSurface(VideoController)            PlayerVideoSurface(Texture)
```

---

## 2. 架构健康（复评）

| 维度 | V1 | V2 | 说明 |
|------|----|----|------|
| 分层与边界 | B+ | **B+** | 不变；Wave 所有权仍有效 |
| 桌面播放可演进性 | B | **B+** | Cookie/UX 闭合后可增量 polish；EDL 保险阀仍可后置 |
| 会话/Cookie 一致性 | **D+** | **B** | 桌面单源 prefs；logout/clear 路径应在 smoke 再确认一次 |
| UI 可维护性 | C | **C** | `player_page` 仍 ~6.6k |
| 测试安全网 | B | **B+** | + focus helper / history launcher / cookie prefs / login Windows 断言 |
| CI/发布 | B- | **B** | HEAD Windows GHA 绿；CM 产物在；仍缺 PR 轻量 gate |
| 产品焦点纪律 | A- | **A-** | 未 PiliPlus 化；续播增强专注路径 |

---

## 3. 风险表（更新：标注 FIXED）

| ID | 严重度 | 状态 | 区域 | 描述 | 影响 / 备注 |
|----|--------|------|------|------|-------------|
| R1 | ~~CRITICAL~~ → **FIXED** | **CLOSED** | Auth/Cookie | 桌面 channel store ≠ playback prefs | `PrefsBilibiliCookieStore` + 同键；见 `832107f` / `FIX_DOCS_COOKIE.md` |
| R2 | CRITICAL → **MAJOR** | **OPEN（降级）** | 验证 | 无书面桌面 smoke 矩阵 | 用户称能播 → 置信度↑；仍缺可复现清单与回归基线 |
| R3 | CRITICAL/MAJOR → **MINOR\*** | **OPEN（降级）** | Playback EDL | 无 video-only fallback | \*用户确认引擎可用；保留为保险阀，**非 P0** |
| R4 | MAJOR | **FIXED** | Docs/CI 文案 | 「仅壳无播放」矛盾 | README/CODEMAGIC/yaml 已对齐 experimental |
| R5 | MAJOR | **OPEN** | 进度双写 | history vs `focubili_mk_playback_*` | 先文档单一真相；代码收敛非紧急 |
| R6 | MAJOR | **OPEN** | player_page | ~6624 行耦合 | 并行冲突与回归成本 |
| R7 | MAJOR | **FIXED** | Windows 登录 UX | WebView 死路径 | Cookie 优先 + Windows 隐藏官方 Web |
| R8 | MAJOR → **MINOR** | **ACCEPT** | 桌面 focus 周边 | 系统闹钟/勿扰不移植 | UI 标明即可；非目标 |
| R9 | MINOR/体验 MAJOR | **OPEN** | capture/PiP | `captureCurrentFrame` null；PiP false | 截帧影响专注完成/笔记；PiP 可永久不做 |
| R10 | MINOR | **ACCEPT** | playurl 范围 | 仅 UGC DASH；无 PGC/WBI | 范围外；错误文案友好即可 |
| R11 | MINOR | **OPEN** | CI 碎片 | 无 PR Linux analyze+test；版本策略 | 低成本高收益 |
| R12 | MINOR | **OPEN（文档可）** | CM Windows | free 无 `windows_x2` | GHA 为 Windows 真源（已实践） |
| R13 | MINOR | **OPEN** | Linux 打包 | 无 CI 产物 | 文档依赖即可 |
| R14 | MINOR | **OK** | 许可证 | 无 PiliPlus 粘贴 | 继续守 |
| R15 | MAJOR | **FIXED** | Focus 缓冲 | `loading` 误停表 | `isFocusPlaybackActuallyPlaying`；`FIX_FOCUS_BUFFER.md` |
| R16 | MAJOR | **FIXED** | 历史续播 | 只带 `VideoPreview` | `WatchHistoryLauncher` + route args |
| R17 | MINOR | **OPEN** | selectQuality phase | 成功后仍 emit `loading` | focus 已容忍 loading+playing；UI spinner 可能偏长 |
| R18 | MINOR | **OPEN** | PLAYBACK_BACKEND | Cookie/EDL 表述略旧 | 半页文档刷新 |
| R19 | MINOR | **OPEN** | 桌面窗口/壳 | 默认尺寸/沉浸播放未产品化 | polish 项 |
| R20 | MINOR | **OPEN** | GHA push 取消 | push 与 dispatch 并发时 push run **cancelled** | 以 dispatch success 为准；可调 concurrency |

**债务热点（非功能，未变）：** `PlaybackQuality` re-export 纯度、重复 UA 字符串、`artifacts/` 勿误提交。

---

## 4. 旧 P0/P1 对照（DONE vs OPEN）

| 旧 ID | 项 | V2 判定 |
|-------|-----|---------|
| **P0-1** | 桌面 Cookie 单源 | **DONE** |
| **P0-2** | 桌面 smoke 清单 + 执行记录 | **仍 OPEN** → 新 **P0-A**（流程/文档，非引擎重写） |
| **P0-3** | EDL video-only 降级 | **仍 OPEN** → **降为 P2-A**（用户能播；残差保险） |
| **P1-1** | 文档对齐 | **DONE** |
| **P1-2** | Login 桌面 UX | **DONE** |
| **P1-3** | playurl backup/重试 | **OPEN** → **P2-B**（不优先） |
| **P1-4** | captureCurrentFrame | **OPEN** → **P1-B**（产品体验） |
| **P1-5** | PR analyze+test | **OPEN** → **P1-C** |
| **P1-6** | 进度语义备忘 | **OPEN** → **P1-D**（文档） |
| **P2-1** | 拆 player_page | **OPEN** → **P1-E / P2** 视带宽 |
| Focus 缓冲（旧 PLAYBACK M1） | — | **DONE** |
| 历史续播 | — | **DONE**（V1 未单列 P0，实为桌面产品缺口） |

---

## 5. 优先下一步（1–2 周）— V2

估算：人日；并行见 §6。  
**原则：** 产品 polish + 桌面残留；**压制** EDL/playurl 大改，除非 smoke 发现高失败率。

### P0 — 本周必须（否则「可用」不可复现 / 不可回归）

| ID | 项 | 估计 | 验收 | 严重度若不做 |
|----|----|------|------|----------------|
| **P0-A** | **桌面 smoke 清单并勾选一次**（Win 优先，mac 次之）：空 cookie 公开 BV；Cookie 登录后 UGC；pause/seek 时 focus 不停表；Home/历史续播 part+position；快捷键 Space/Esc；logout 后播放无会话 | 0.5–1d | `docs/agent-reports/SMOKE_DESKTOP_PLAYBACK.md` 平台矩阵（通过/失败/备注） | **MAJOR**（R2） |
| **P0-B** | **Cookie 会话闭环抽检**（可并入 P0-A）：粘贴 → playurl/media 带 Cookie；logout/`clear` 后 header 空 | 0.25d | smoke 两行勾选 + 可选单测已有 prefs 路径 | **MAJOR** 若回归 |

> 无新的代码向 CRITICAL。P0 以**验证与防回归**为主。

### P1 — 显著提升桌面产品完整度（本周–下周）

| ID | 项 | 估计 | 验收 |
|----|----|------|------|
| **P1-A** | **桌面能力预期 UI**：PiP / 系统闹钟 / 勿扰等入口在桌面隐藏或 disabled + 短文案（避免「点了没反应」） | 0.5d | 桌面点不到死按钮；Android 不变 |
| **P1-B** | **`captureCurrentFrame` 最小实现**（media_kit `screenshot` → 临时 JPEG 路径） | 0.5d | 专注结束/笔记贴帧非空路径 |
| **P1-C** | **GHA PR 级** `flutter analyze` + `flutter test`（ubuntu；不强制 build 全桌面） | 0.25–0.5d | PR 必绿；与 Windows build workflow 分工清晰 |
| **P1-D** | **进度语义一小节**写入 `PLAYBACK_BACKEND.md`：PlayerPage/`WatchHistoryService` 为产品进度；mk prefs 为 backend resume；并刷新 Cookie「已同键」句 | 0.25d | 下一位 agent 不新开第三套键 |
| **P1-E** | **`selectQuality` 成功终态**：host 已 playing 时 emit `ready`（或与 openVideo 对齐），避免长时间 loading 壳 | 0.25–0.5d | 单测 + 手动切清晰度 UI/focus 正常 |
| **P1-F** | **player_page 小拆一轮**：优先 watch-history hooks / init pipeline / overlay chrome 之一外提（**不做**大爆炸重写） | 1–1.5d | 行数明显下降；行为测不减；与 playback 文件错峰 |
| **P1-G** | **桌面窗口默认尺寸 / 横屏播放可读性**（非系统勿扰） | 0.5–1d | 宽屏 Home+Player 不别扭 |

### P2 — 保险阀与结构（有余力 / smoke 失败再升级）

| ID | 项 | 估计 | 触发升级条件 |
|----|----|------|----------------|
| **P2-A** | EDL open 失败 → video-only fallback + 可读错误 | 0.5d | smoke 出现系统性 EDL/黑屏/无声失败 |
| **P2-B** | playurl backup 列表 / 单次重试 / 403 文案 | 0.5–1d | 长播 CDN 失败频发 |
| **P2-C** | macOS 签名/公证调研笔记 | 0.5d | 要对外分发 |
| **P2-D** | Linux 依赖/打包说明或可选 CI | 0.5d | 有 Linux 用户诉求 |
| **P2-E** | Android 可选 media_kit（debug flag only） | 1d+ | **默认勿开** |
| **P2-F** | UA/Request 策略常量收敛 | 0.25d | 有漂移 bug 时 |
| **P2-G** | 继续拆 `player_page` 第二刀 | 1–2d | P1-F 后仍痛 |

### 明确不做（防守 PiliPlus 化）— 不变

- 搬运 PiliPlus `pl_player` / 大段 GPL 粘贴  
- 首页推荐 / 动态 / 全面社交  
- 桌面精确闹钟与系统勿扰 1:1  
- 为「全能客户端」重写导航 IA  
- **无证据时**重写 EDL/playurl 管线  

---

## 6. 建议并行 Agent 切分（V2）

沿用文件所有权；**冲突文件唯一写者**。

| Agent | 所有权 | 对应 | 禁止 |
|-------|--------|------|------|
| **A-SMOKE** | 只写 `docs/agent-reports/SMOKE_*.md`；可只读跑本地/已装包 | P0-A, P0-B | **不改** `lib/**` |
| **B-PRODUCT-DESKTOP** | `login_page` 残留、PiP/闹钟入口可见性、home/window 尺寸、短文案 | P1-A, P1-G | 不改 media_kit open/EDL；不改 Kotlin |
| **C-CAPTURE-PHASE** | `media_kit_playback_service.dart` 截帧 + `selectQuality` 终态；相关 test | P1-B, P1-E | 大改 EDL 语法前先升级 P2-A 并获准 |
| **D-CI** | `.github/workflows/*` | P1-C, R12/R20 注释 | 不改业务 Dart |
| **E-DOCS** | `docs/PLAYBACK_BACKEND.md`、必要时 README 一句 | P1-D, R18 | 不改 `lib/**` |
| **F-PLAYER-SPLIT** | `player_page.dart` + `lib/features/player/**` 抽出 | P1-F, P2-G | 与 C 错开；先 rebase master |
| **G-PLAY-INSURANCE**（按需） | EDL fallback / playurl backup | P2-A, P2-B | **仅** smoke 失败或明确升级后启动 |

**推荐波次：**

```
Week 1 day 1:     A-SMOKE ║ D-CI ║ E-DOCS
Week 1 day 1–2:   B-PRODUCT-DESKTOP（UI 降级/窗口）
Week 1 day 2–3:   C-CAPTURE-PHASE（截帧 + selectQuality）
Week 1 day 3–5:   F-PLAYER-SPLIT（小拆一刀）
Week 2:           据 smoke：G-PLAY-INSURANCE 或 继续 F / mac 分发调研
```

**Merge 顺序：** Docs/CI（无业务风险）→ Product UI → Capture/phase → Player split。  
**Insurance（EDL/playurl）默认不上车**，除非 A-SMOKE 打回 MAJOR+。

---

## 7. CI / 构建态势（V2 快照）

| 管道 | 平台 | @ HEAD `60e4bf6` | 备注 |
|------|------|------------------|------|
| GHA `windows-build.yml` | windows-2022 | **success**（dispatch **31240730750**） | push 同源 run **cancelled**（并发）；以 dispatch 绿为准 |
| GHA @ `47e6828` | windows | failure → 由 `60e4bf6` 修复 | login 断言与 Windows Cookie UI |
| CM `android-apk` | mac_mini_m2 | 用户：**绿**；本地 `FocuBili-android-b4.apk` | 本报告未 API 核验 SHA |
| CM `macos-build` | mac | 用户：**绿**；本地 `FocuBili-macos-b2.zip` | 同上；yaml 侧 mac 未必跑 full test |
| CM `windows-build` | windows_x2 | free plan **不可用** | Windows 真源 = GHA |
| PR Linux gate | — | **无** | → P1-C |

**建议姿势（不变）：** Windows = GHA；CM = Android + macOS；PR = 轻量 Linux analyze+test。

---

## 8. 与 Plan / 用户可感知 M3 对照

| 标准 | V1 | V2 |
|------|----|----|
| M1–M3 代码 | 达成 | 达成 |
| 登录后桌面可带会话播 | 阻断（R1） | **路径已修**；待 smoke 书面化 |
| Focus 跟播不因 rebuffer 抖停 | 阻断（缓冲 phase） | **已修** |
| 历史续播 | 弱 | **已修** |
| 用户可感知「能播」 | 未证实 | **用户确认 works** + 构建绿；缺矩阵文档 |
| 截帧/桌面壳 polish | 未做 | 仍 half-done → P1 |

---

## 9. Executive summary（≤15 行）

1. **HEAD `60e4bf6`**：在 `ac131d0` 播放 Wave 之上合并 Cookie 单源、文档诚实、focus 缓冲、历史续播与测试修复。  
2. **原 CRITICAL（桌面 Cookie 分裂）与 MAJOR（缓冲停表、文档说谎、Windows 登录死路）已 FIXED。**  
3. **GHA Windows @ 60e4bf6 绿**；CM Android/macOS 据用户与本地 b4/b2 产物视为绿。  
4. **用户确认播放引擎可用** → EDL/playurl 重写 **降为 P2 保险**，非本周主路径。  
5. **主矛盾切换为：** 可复现 smoke、产品降级 UI、截帧、PR CI、player_page 可维护性、窗口体验。  
6. **仍 OPEN 的代码残差：** EDL 无 fallback、`selectQuality`→loading、`captureCurrentFrame` null、进度双写未文档化。  
7. **新 P0：** 书面桌面 smoke + Cookie 闭环抽检（验证轨，非引擎重写）。  
8. **新 P1：** 桌面死按钮治理、截帧、PR analyze+test、进度文档、selectQuality 终态、player 小拆、窗口尺寸。  
9. **并行：** A-SMOKE ∥ D-CI ∥ E-DOCS → B-PRODUCT → C-CAPTURE → F-SPLIT；G-INSURANCE 仅 smoke 打回时启动。  
10. **北极星不变：** 专注桌面客户端；克制范围；不 PiliPlus 化。

---

## 10. 本轨有序 Next-step PRs（仅 ROADMAP / 战略轨）

> 战略轨以 **文档、编排、优先级** 为主；实现 PR 由对应 agent 开。

| Order | PR 标题（建议） | Owner | 对应 |
|------|-----------------|-------|------|
| 1 | `docs: desktop playback smoke matrix (win/mac)` | A-SMOKE | P0-A/B |
| 2 | `ci: PR workflow for flutter analyze and test` | D-CI | P1-C |
| 3 | `docs(playback): cookie single-source + progress dual-write notes` | E-DOCS | P1-D |
| 4 | `fix(desktop): hide unsupported PiP/alarm affordances` | B-PRODUCT | P1-A |
| 5 | `feat(playback): media_kit captureCurrentFrame via screenshot` | C-CAPTURE | P1-B |
| 6 | `fix(playback): selectQuality emits ready when host playing` | C-CAPTURE | P1-E |
| 7 | `feat(desktop): default window size / player layout polish` | B-PRODUCT | P1-G |
| 8 | `refactor(player): extract init or history hooks from PlayerPage` | F-SPLIT | P1-F |
| 9 | *(optional)* `fix(playback): EDL open fallback to video-only` | G-INSURANCE | P2-A **仅 smoke 失败** |
| 10 | *(optional)* `fix(playurl): backup URL retry` | G-INSURANCE | P2-B **仅必要** |

**本文件职责：** `docs/agent-reports/REVIEW_ROADMAP_V2.md` 只更新战略结论；**不**改 `lib/**`。  
**取代关系：** 日常排期以 **V2** 为准；`REVIEW_NEXT_STEPS.md`（@ ac131d0）作历史对照，其中 P0-1/P1-1/P1-2 与 focus/历史相关结论已过时。

---

## 11. 参考路径（只读）

- 本波修复说明: `FIX_DOCS_COOKIE.md`, `FIX_FOCUS_BUFFER.md`, `FIX_HISTORY_RESUME.md`  
- 旧复盘: `REVIEW_NEXT_STEPS.md`, `REVIEW_PLAYBACK.md`  
- Plan / 后端: `docs/PLAN_MEDIA_KIT_PLAYBACK.md`, `docs/PLAYBACK_BACKEND.md`  
- CI: `docs/CODEMAGIC.md`, `codemagic.yaml`, `.github/workflows/windows-build.yml`  
- Wave: `REPORT_{FOUNDATION,PLAYURL,COOKIE,SURFACE,MEDIAKIT,WIRE}.md`  
- 关键代码: `bilibili_auth_service.dart`（`PrefsBilibiliCookieStore`）, `cookie_header_provider.dart`, `media_kit_playback_service.dart`, `watch_history_launcher.dart`, `player_route_args.dart`, `player_page.dart`（`isFocusPlaybackActuallyPlaying`）

---

*End of REVIEW_ROADMAP_V2*
