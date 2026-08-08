# Plan: FocuBili 采用 PiliPlus 式 media_kit 播放（并行实施）

## 目标

保留 FocuBili 产品与 focus，**不整仓迁 PiliPlus**。  
播放层改为 **media_kit**（对照 PiliPlus 的 open/DASH 思路），使 **桌面 focus 跟播计时** 可用；Android 可双后端过渡。

**非目标（本阶段不做）**

- 搬 `pl_player` 整模块 / 依赖 PiliPlus git 工程
- 完整迁 focus 到别的 App
- 桌面系统勿扰 / 精确闹钟 1:1
- 推荐流、动态等 PiliPlus 功能

---

## 架构（目标态）

```
FocusTimerController
        │  listen isPlaying / phase
        ▼
PlaybackService  (既有接口，尽量不动方法表)
   ├── NativePlaybackService     // Android Media3（保留）
   └── MediaKitPlaybackService   // media_kit（新，桌面默认；Android 可选）
            │
            ▼
   BilibiliPlayUrlService (Dart)  // 从 Kotlin playurl/DASH 逻辑抽出
            │
            ▼
   CookieHeaderProvider           // 桌面 jar / Android WebView 适配
        │
        ▼
PlayerVideoSurface                // Texture | media_kit Video 控件
```

对照代码：

- 接口：`lib/services/native_playback_service.dart` → `PlaybackService`
- 现状 playurl：`NativePlaybackController.kt`（~playurl / dash / selectMediaTrack）
- 对照：`/tmp/PiliPlus` → `media_kit` + `VideoHttp` playurl（**只学思路，不 copy 大段 GPL 文件粘贴进仓；自行实现**）

---

## 并行化总原则

1. **按文件所有权切分**：每个 agent 只改自己的 path glob，禁止改他人文件。  
2. **先契约后实现**：Wave 0 定接口/工厂桩，Wave 1 才能真并行。  
3. **新文件优先**：能 `lib/services/foo.dart` 新建就不要改 6000 行 `player_page.dart` 中段。  
4. **worktree 隔离**：每个 agent `isolation=worktree`，完成后由编排者顺序 merge。  
5. **合并顺序**：契约 → playurl/cookie/surface → mediakit 实现 → wire 工厂与 CI。  
6. **冲突文件唯一写者**：
   - `pubspec.yaml` / `pubspec.lock` → **仅 Agent-FOUNDATION 与 Agent-WIRE**
   - `lib/main.dart` → **仅 FOUNDATION / WIRE**
   - `lib/features/player/player_page.dart` → **仅 Agent-SURFACE（最小 diff）与 Agent-WIRE**
   - `lib/services/native_playback_service.dart` → **仅 FOUNDATION（若拆文件）**；默认 **不改**，新实现另文件

---

## 并行 DAG

```
                    [W0 FOUNDATION] 契约+依赖桩
                     /     |      \
                    /      |       \
         [W1-A PLAYURL] [W1-B COOKIE] [W1-C SURFACE]
                    \      |       /
                     \     |      /
                    [W2-D MEDIAKIT_SVC]   // 依赖 A+B 契约；C 的 surface API
                           |
                    [W3-E WIRE+FOCUS+CI]
```

| Wave | Agent ID | 可并行？ | 依赖 |
|------|----------|----------|------|
| W0 | `FOUNDATION` | 单独先跑 | — |
| W1 | `PLAYURL` `COOKIE` `SURFACE` | **三者并行** | W0 |
| W2 | `MEDIAKIT_SVC` | 单独（或与文档并行） | W1-A + W1-B，SURFACE API |
| W3 | `WIRE` | 单独 | W2 + W1-C |

---

## Wave 0 — FOUNDATION（串行闸门）

**Agent:** `FOUNDATION`  
**所有权:**

- `pubspec.yaml`（只加 media_kit 相关依赖，版本钉死注释）
- `lib/main.dart`（仅 `MediaKit.ensureInitialized()`，桌面/全平台安全调用）
- **新建** `lib/services/playback_backend.dart`（或 `playback_service_factory.dart`）
- **新建** `lib/services/playback_contracts.dart`（若需扩展 initialize 返回值；优先不改 `PlaybackService` 方法表）
- **新建** `docs/PLAYBACK_BACKEND.md`（后端选择：desktop→media_kit，android→native 默认）

**契约（下游必须遵守）:**

```dart
// 工厂
PlaybackService createPlaybackService(); // 平台分支

// PlayUrl（W1-A 实现）
abstract interface class BilibiliPlayUrlClient {
  Future<PlayUrlManifest> fetch({
    required String bvid,
    required int cid,
    int quality = 64,
    String cookieHeader = '',
  });
}

class PlayUrlManifest {
  final String videoUrl;
  final String? audioUrl; // DASH 分轨
  final int quality;
  final List<PlaybackQuality> qualities;
  final Map<String, String> httpHeaders; // Referer / User-Agent
}

// Cookie（W1-B 实现）
abstract interface class CookieHeaderProvider {
  Future<String> readCookieHeader();
}

// Surface（W1-C）
// PlayerPage 不再写死 Texture；通过:
//   - initialize() 仍可返回 textureId（native）
//   - 或 MediaKit 路径使用 embed Widget（见 SURFACE）
```

**Media_kit 依赖（建议，实施时以 pub 可解析为准）:**

- `media_kit`
- `media_kit_video`
- `media_kit_libs_video`（或按平台 libs）

**完成标准:** `flutter pub get` 通过；`flutter analyze` 无新增 error；工厂仍返回 `NativePlaybackService`（行为不变）。

---

## Wave 1 — 三路并行

### W1-A `PLAYURL`

**所有权（仅这些）:**

- `lib/services/bilibili_playurl_service.dart`
- `lib/models/play_url_manifest.dart`（若未放进 contracts）
- `test/bilibili_playurl_service_test.dart`

**禁止改:** `player_page.dart`、`pubspec.yaml`、`NativePlaybackController.kt`、focus、cookie 实现文件

**任务:**

1. 对照 Kotlin `playurl` + dash 选轨（`NativePlaybackController`），用 Dart `HttpClient` 实现 UGC playurl。
2. 复用现有 `bilibili_request_policy.dart` 的 UA/Referer 风格，**不要**新造一套违和对端策略。
3. Cookie 仅通过参数 / `CookieHeaderProvider` 注入，不直接碰 WebView。
4. 解析 `dash.video` / `dash.audio`，选出 quality；返回 `PlayUrlManifest`。
5. 单测：fixture JSON → manifest（无真实网络）。

**完成标准:** 单测绿；analyze 干净；无 UI 依赖。

**参考路径（只读）:**

- `/home/cnic/work/FocuBili/android/app/src/main/kotlin/com/focubili/app/NativePlaybackController.kt`
- `/tmp/PiliPlus/lib/http/api.dart`（路径常量级对照）
- 既有 `lib/services/bilibili_service.dart` / `bilibili_request_policy.dart`

---

### W1-B `COOKIE`

**所有权:**

- `lib/services/cookie_header_provider.dart`
- `lib/services/memory_cookie_header_provider.dart`（或 shared_preferences 简单实现）
- `lib/services/webview_cookie_header_provider.dart`（包装现有 auth MethodChannel，可选）
- `test/cookie_header_provider_test.dart`

**禁止改:** playurl 文件、player_page、pubspec、Kotlin

**任务:**

1. 定义 `CookieHeaderProvider` + `replaceCookies` / `clear`（桌面粘贴登录最小集）。
2. `PrefsCookieHeaderProvider`：用 `shared_preferences` 存 cookie 字符串（桌面可用）。
3. `ChannelCookieHeaderProvider`：委托现有 `BilibiliAuthService` / auth channel（Android 兼容）。
4. 工厂：`createCookieHeaderProvider()` — desktop→prefs，android→channel（若 channel 文件不便改，android 暂 prefs + 注释 TODO wire auth）。

**完成标准:** 单测绿；桌面可 set/get/clear。

---

### W1-C `SURFACE`

**所有权:**

- **新建** `lib/features/player/player_video_surface.dart`
- `lib/features/player/player_page.dart` — **仅**替换 `_buildVideoTexture` / `Texture(textureId:)` 为 `PlayerVideoSurface`（最小 diff，禁止大重构 focus 逻辑）

**禁止改:** services/、pubspec、focus/、android/

**任务:**

1. `PlayerVideoSurface`：  
   - `textureId != null` → 现有 `Texture`  
   - `videoController != null`（media_kit `VideoController` 类型用 dynamic/Object? 或条件 import 避免强耦）→ 占位 `ColoredBox` **或** 正式 `Video` 控件（若 foundation 已加依赖）  
2. 保持宽高比/BoxFit 行为与现网一致（调用方可传 child 外层）。  
3. 无 texture 且无 controller 时显示原有加载/错误由父组件处理，surface 只负责「画面槽位」。

**完成标准:** Android 原路径 UI 无回归（texture 分支）；analyze 通过。

---

## Wave 2 — `MEDIAKIT_SVC`（等 W1-A/B）

**Agent:** `MEDIAKIT_SVC`  
**所有权:**

- `lib/services/media_kit_playback_service.dart`
- `test/media_kit_playback_service_test.dart`（尽量 mock Player；不能 mock 则测状态机映射纯函数）

**禁止改:** player_page 大段、focus、Kotlin、pubspec（依赖已由 W0 加好）

**任务:**

1. `class MediaKitPlaybackService implements PlaybackService`。
2. `initialize`：创建 `Player` + `VideoController`；textureId 返回 `null`（桌面走 Widget）。
3. `openVideo`：调 `BilibiliPlayUrlClient` + cookie → `player.open(Media(video, extras: headers))`；音视频分轨对照 PiliPlus edl/双轨方案的**最小可用**（可先 video-only 若 audio 合并复杂，但必须在注释标明限制；优先 video+audio）。
4. 将 media_kit stream 映射为 `PlaybackSnapshot`（phase/isPlaying/position/duration/speed）。
5. `play/pause/seek/setPlaybackSpeed` 接 Player API。
6. `selectQuality`：重新 fetch playurl + open，保留 position。
7. 桌面降级：  
   - `getSystemPlaybackLevels` / brightness → 安全默认  
   - `enterPictureInPicture` → false  
   - `captureCurrentFrame` → null 或 media_kit 截图若易做  
   - `loadSavedPlaybackState` → `shared_preferences` 简单实现（bvid→cid/pos）
8. **不**复制 PiliPlus 大文件；独立实现。

**完成标准:** 单元级映射测试；analyze 通过；不要求本 agent 真机播。

---

## Wave 3 — `WIRE`（集成）

**Agent:** `WIRE`  
**所有权:**

- `lib/services/playback_service_factory.dart`（写实分支）
- `lib/main.dart`（若需）
- `lib/features/player/player_page.dart`（接 surface 的 controller 来源：若 PlaybackService 需暴露 `VideoController?`，**最小扩展**：在 factory/media_kit 侧用可选回调或 `PlaybackService` 扩展 interface 在 **新文件** `playback_service_media_kit_ext.dart`）
- `.github/workflows/windows-build.yml`（确认仍能 build）
- `docs/CODEMAGIC.md` / README 一句「桌面播放实验性」
- 回归：`test/focus_timer_controller_test.dart` 等（只改必要 mock）

**任务:**

1. `createPlaybackService()`：  
   - `Platform.isWindows || isMacOS || isLinux` → `MediaKitPlaybackService`  
   - `Android` → `NativePlaybackService`  
2. `PlayerPage` 默认 `widget.playbackService ?? createPlaybackService()`。  
3. Focus：确认仍 listen `states`；补一测「snapshot isPlaying 驱动 focus」若缺失。  
4. `flutter analyze` + `flutter test`。  
5. 不碰 Kotlin Media3（Android 保持可用）。

**完成标准:** 全量 test 通过；Windows workflow 不因 API 误用失败（逻辑层）。

---

## 并行时间线（编排者）

| 时刻 | 动作 |
|------|------|
| T0 | 写本 plan；启动 W0 FOUNDATION（worktree） |
| T1 W0 完成 merge 主工作区 | **同时**启动 W1-A/B/C 三个 worktree agent |
| T2 W1 三个完成 | merge 顺序：PLAYURL → COOKIE → SURFACE（冲突少） |
| T3 | 启动 W2 MEDIAKIT_SVC |
| T4 W2 merge | 启动 W3 WIRE |
| T5 | 编排者跑全量 test / 必要时修合并冲突 |

**Merge 冲突策略:**  
后合并方 rebase；`player_page` 只允许 SURFACE 与 WIRE 碰，WIRE rebase 在 SURFACE 之后。

---

## 每个 Subagent 的 Prompt 必带

1. 仓库路径与 **本 plan 路径** `docs/PLAN_MEDIA_KIT_PLAYBACK.md`  
2. **所有权 glob + 禁止列表**  
3. 完成标准与测试命令  
4. `git`：在 worktree 内分支 `feat/playback-<id>`，commit 清晰  
5. 结束时写 `## Agent Report` 到 `docs/agent-reports/REPORT_<ID>.md`：改了什么、怎么测的、阻塞项  
6. 国内镜像：`PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` 若需要  
7. **禁止** `git push --force`；**禁止**改无关 CI 密钥  

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| playurl/WBI 签名复杂 | 先实现与现 Kotlin 同等的最小参数集；失败信息可读 |
| media_kit 分轨音频 | 先做最小双轨；单轨降级要文档化 |
| player_page 合并冲突 | surface 最小 diff + 所有权 |
| 许可证 | 不粘贴 PiliPlus 源文件；独立实现 |
| Focus 回归 | W3 跑 focus 相关 test；不改 timer 状态机 |

---

## 成功标准（里程碑）

- **M1** W0+W1：契约 + playurl/cookie/surface 落地，Android 原播放仍默认  
- **M2** W2：MediaKitPlaybackService 能在代码层 open+状态流  
- **M3** W3：桌面 factory 默认 media_kit；focus 单测绿；analyze/test 绿  

**用户可感知 M3：** Windows/macOS 安装包能播公开视频并进行 focus 跟播（登录可后置；cookie 空也能试公开流时标明）。

---

## PR 切分（对外提交时可再拆）

1. `feat(playback): foundation media_kit deps + factory stub`  
2. `feat(playback): dart playurl client`  
3. `feat(auth): cookie header provider`  
4. `feat(player): video surface abstraction`  
5. `feat(playback): MediaKitPlaybackService`  
6. `feat(playback): wire desktop backend + tests`  

1–4 对应 W0+W1（4 可并行开发，merge 有序）；5=W2；6=W3。
