<p align="center">
  <img src="assets/icon/focubili_icon.png" width="128" alt="FocuBili 图标">
</p>

<h1 align="center">FocuBili · 焦点哔哩</h1>

<p align="center">
  一个强调主动搜索与专注观看的第三方 B 站客户端（Android 为主；Windows / macOS 桌面实验性）。
</p>

<p align="center">
  <a href="https://github.com/chocolatedesue/FocuBili/releases"><img src="https://img.shields.io/github/v/release/chocolatedesue/FocuBili?display_name=tag&sort=semver" alt="GitHub Release"></a>
  <img src="https://img.shields.io/badge/version-v1.2.1-2EA44F" alt="Current version v1.2.1">
  <img src="https://img.shields.io/badge/Flutter-3.44.6-02569B?logo=flutter" alt="Flutter 3.44.6">
  <img src="https://img.shields.io/badge/Android-7.0+-3DDC84?logo=android" alt="Android 7.0+">
  <img src="https://img.shields.io/badge/Windows-experimental-0078D6?logo=windows" alt="Windows experimental">
  <img src="https://img.shields.io/badge/macOS-experimental-000000?logo=apple" alt="macOS experimental">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0"></a>
</p>

> [!IMPORTANT]
> FocuBili 是个人学习和技术研究项目，不是哔哩哔哩官方客户端，与哔哩哔哩无隶属或合作关系。项目依赖的非官方接口可能随时变化，请遵守平台规则、版权要求与所在地法律，不要用于绕过付费、隐私或其他访问控制。

## 项目目标

FocuBili 希望保留“主动找到一支视频并认真看完”这件事本身：

- 首页不提供无限推荐流；
- 搜索、BV 号和视频链接是主要入口；
- 播放页优先保留视频、选集、简介和必要控制；
- 账号数据功能以只读为主，不伪装点赞、投币、收藏或关注写操作。

## v1.2.1 更新内容

- **多端发布**：Android **per-ABI APK**（arm64 / armeabi-v7a / x86_64，**无 fat**）、Windows zip、macOS zip（未公证）。下载 [GitHub Release v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)（**多数手机装 arm64-v8a**）。
- **media_kit 播放（实验性共享栈）**：Android / Windows / macOS / Linux **默认** media_kit（libmpv）；Media3 `NativePlaybackService` 仍保留可注入回退。**iOS 未迁 media_kit。** 见 [`docs/PLAYBACK_BACKEND.md`](docs/PLAYBACK_BACKEND.md)、[`docs/PLAN_ANDROID_MEDIA_KIT.md`](docs/PLAN_ANDROID_MEDIA_KIT.md)。
- **宽屏首页观看历史**：较宽布局下首页展示本机观看历史网格，便于桌面续看。
- **历史续播**：从首页或观看记录进入时，尽量恢复上次分 P 与播放位置。
- **专注计时与缓冲**：正常视频缓冲不再误暂停专注累计。
- **桌面 Cookie 登录**：粘贴 Cookie 写入本机 prefs，与播放 / playurl 请求共用会话；Windows 以 Cookie 路径为主。
- **播放器键盘快捷键**：桌面支持空格播放暂停、方向键进度/音量、全屏与弹幕等常用快捷键（输入框聚焦时不误触）。

完整说明与产物 SHA-256 见 [v1.2.1 发布说明](docs/RELEASE_NOTES_v1.2.1.md) · [Release 下载页](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)。

## v1.2.0 更新内容

- 首页、搜索页和“我的”页增加统一的平板响应式边距与内容限宽；矮横屏和分屏中的首页欢迎区会按可用高度缩短。
- 平板网页登录改用 B 站官方 H5 入口，并在保留设备真实 WebView 版本的同时补充移动端 UA 标记。
- 修复视频详情请求来源与目标视频不一致时触发的 HTTP 412；公开详情仍不携带账号 Cookie。
- 修复“我的 → 设置 → 返回”后隐藏搜索框重新取得焦点、输入法自动弹出以及文字写入搜索框的问题。
- 搜索页和“我的”页按系统返回时先回首页，只有首页继续把返回交给 Android 退出应用。

历史 APK 可见 [上游 L1Xu4n Release v1.2.0](https://github.com/L1Xu4n/FocuBili/releases/tag/v1.2.0)。完整变更见 [v1.2.0 发布说明](docs/RELEASE_NOTES_v1.2.0.md)。

## v1.1.1 更新内容

- 首页改为无底部导航的专注入口：通过首屏搜索按钮进入搜索页，通过右上角主题色个人图标进入“我的”。
- 首页下方内容拆分为可扩展卡片；首屏上滑一次吸附展开全部卡片，并带有原位下坠、模糊和透明过渡效果。
- 搜索页与“我的”页新增返回首页入口，页面切换使用直接滑入动画，不会短暂经过搜索页。
- 深色模式下首页按钮、背景和文字保持可读；已登录账号在首页个人入口显示头像，头像不可用时回退为主题色图标。
- 修复大幅上滑后的卡片吸附位置和轻微下滑误触发整页回弹问题。
- `flutter analyze` 通过，完整 `flutter test` 共 245 项通过。

[下载 FocuBili v1.1.1 APK](https://github.com/L1Xu4n/FocuBili/releases/download/v1.1.1/FocuBili-v1.1.1-release.apk) · [查看完整发布说明](docs/RELEASE_NOTES_v1.1.1.md)

APK SHA-256：`1EB849A3795CEC0E749C424FD4836184622A7A30B4975C5CEE0EEAB9AA84A31D`

## v1.1.0 更新内容

- 学习清单改为按视频分P独立管理：同一视频的不同分P可分别加入、排序、搜索和完成。
- 已完成任务自动移动到清单末尾并与未完成任务分隔；“继续学习”只按清单顺序播放未完成分P。
- 只有学习清单中的分P完播后才显示“标记已完成 / 继续学习”，最后一项完成后明确显示学习结束。
- 首页在每次返回时刷新学习清单，加入或取消后的状态会立即同步；所有加入、取消操作统一使用底部提示。
- 专注提醒升级为 Android 系统闹钟：应用进程退出后仍可触发，设备重启、应用升级或重新取得精确闹钟权限后会恢复待提醒任务。
- 设置新增统一“权限管理”，集中检查通知、精确闹钟、勿扰、电量限制和小米/Redmi/POCO 后台自启动入口。
- 勿扰模式会在专注视频播放时开启、暂停时恢复；快进快退产生的短暂缓冲不会反复切换系统勿扰。
- 问题诊断新增闹钟安排、恢复、触发、权限和后台限制记录，并保持 Cookie、笔记正文、专注目标等隐私字段脱敏。
- 重写时间点截图查看器，截图初始完整居中，支持双击、双指缩放、平移和一键回正。
- 修复全屏笔记布局、截图缩放位置、继续学习卡住、已完成任务回到学习中、分P加入状态串联及启动图标/启动背景问题。
- `flutter analyze` 无问题，完整 `flutter test` 共 240 项全部通过，并完成 Android 15 模拟器安装与权限页验证。

[下载 FocuBili v1.1.0 APK](https://github.com/L1Xu4n/FocuBili/releases/download/v1.1.0/FocuBili-v1.1.0-release.apk) · [查看完整发布说明](docs/RELEASE_NOTES_v1.1.0.md)

APK SHA-256：`4998C8EB9EF7F69C336F2A0BA50EF1772D6F154899506B4D2C10FFF5F91CFE95`

## v1.0.1 更新内容

- 新增仅保存在当前设备的学习清单：可从搜索、视频详情和合集条目加入，保存并恢复分P与观看进度。
- 首页只突出一条“继续学习”任务；完整清单可按未开始、学习中和已完成管理。
- 重构搜索顶部、候选词、可换行历史和视频结果卡片，同时保留视频 / 用户搜索、排序与筛选。
- 视频播放结束时显示紧凑的“标记完成 / 播放下一节”，不再自动连播或遮挡播放控制栏。
- 支持互动视频剧情分支；选项使用居中的无色半透明卡片，播放栏出现时自动上浮，只有用户点击后才切换剧情。
- 支持视频分段进度条、分段预览和点击跳转；横竖屏都显示在播放器画面内。
- 修复 Android 原生层拒绝 3 倍速的问题；简介中的 `@UP` 以可点击的蓝色文字打开对应主页。
- 时间点笔记改为明确点击“跳转到时间点”才移动视频位置，输入停止后会自动保存到本机。
- 完整 `flutter test` 共 212 项全部通过，并完成 Android 15 模拟器实播验证。

[下载 FocuBili v1.0.1 APK](https://github.com/L1Xu4n/FocuBili/releases/download/v1.0.1/FocuBili-v1.0.1-release.apk) · [查看完整发布说明](docs/RELEASE_NOTES_v1.0.1.md)

## v1.0.0 更新内容

### 播放器

- 重新整理播放器上下控制栏，缩小高度并统一播放、时间、选集、画质、倍速和全屏按钮的对齐方式。
- 普通竖屏在详情页显示横向分P列表；只有全屏多P视频在播放栏显示“选集”，单P视频不显示无意义按钮。
- 修复反复进入和退出全屏后弹幕生成位置逐渐向左偏移的问题。
- 弹幕时间轴跟随 0.75x～2x 播放倍速，并根据完整播放器宽度重新计算移动轨迹。
- 左右滑动快捷跳转时显示目标时间对应的视频画面预览；预览接口不可用时仍保留时间提示和跳转能力。
- 视频详情显示发布时间、标签、BV/AV、简介和只读互动统计；长按 BV 可复制，过长简介可展开和收起，结构化 @UP 与网页链接会显示为蓝色可点击文字，外链访问前需确认风险。
- 修复合集内切换其他视频后持续缓冲的问题；合集切换复用同一个原生播放器，返回键会回到切换前的视频。
- 修复合集条目在不同接口字段下无法显示封面的问题。
- 合集视频继续使用横向卡片浏览，并补充发布日期；超过卡片宽度的标题会自动上下滚动。
- 合集展开面板支持按标题或 BV 号搜索、按合集顺序/发布时间/播放量排序，并可一键定位当前视频。
- 详情页横向合集不再限制前六条；长合集按需创建卡片，切换视频后会自动滚动到新视频。
- 看过的投稿和合集视频会在封面显示“上次看过”及最近播放位置。

### 时间点笔记

- 竖屏播放页提供“记笔记”入口，编辑期间播放器固定显示，不再随内容滚动收起。
- 笔记会保存标题、正文、记录时间和视频时间点，也可以选择保存当前视频画面。
- 全屏播放器右侧提供半透明笔记入口；展开后左侧按时间点列出本视频笔记，右侧可编辑，点击旧笔记会跳回对应进度。
- “我的 → 时间点笔记”可以统一查看、编辑和删除所有本机笔记。
- 笔记列表支持搜索，并以视频封面作为卡片封面；点击笔记进入独立详情页，不再使用临时弹窗。
- 笔记详情可点击视频来源跳转到对应视频、分P和时间点；退出未保存编辑前会提醒确认。
- 笔记管理页支持多选后导出或分享 Markdown、JSON/ZIP；详情页可生成包含标题、正文、BV、时间点和可选截图的自适应分享长图。
- 可选视频截图按原始宽高比自适应显示，支持全屏查看；所有删除操作均需二次确认。
- 全屏笔记本采用紧凑无边框编辑布局，支持收起笔记列表和从屏幕右侧平滑进入、退出。
- 插入画面始终截取笔记创建时锁定的时间点，不会因视频继续播放而保存错误画面。
- 笔记文字保存在本机偏好设置中，视频画面保存在应用私有目录，不会上传到开发者服务器。

### UP 主主页

- 投稿支持关键词搜索，以及“最新发布、最多播放、最多收藏”三种服务端排序。
- 资料头会随投稿列表上滑逐步收起，并固定投稿、专栏和合集标签，为视频列表释放更多空间。
- 资料头显示官方认证说明；超长签名支持展开和收起，不再静默隐藏后半段。
- 投稿改为移动端横向列表：左侧 16:9 封面，右侧显示标题、日期、播放量和弹幕数。
- 多P投稿优先读取接口集数；字段缺失时识别明确标题，并对可见卡片限并发补查真实视频详情。
- 本机看过的投稿会在封面显示“上次看过”，返回 UP 主页后自动刷新观看状态。
- 修复投稿时长为字符串时被错误显示成 `0:00` 的问题，兼容秒数、`分:秒` 和 `时:分:秒`。
- 投稿直接使用 WBI 签名接口，补齐空间页参数并临时复用现有 B 站会话；受风控时只单次回退旧接口，避免快速重试加重 `-799/412`。
- 修复部分 UP 主资料显示 404 或残缺的问题；旧名片失败时使用完整 WBI 环境参数、空间请求头和关系统计接口补齐资料，并兼容 16 位大 UID。
- 视频详情会完整保留超过 32 位的 UID、AID 和 CID，修复大 UID 被截断为 `2147483648` 后跳转到错误主页的问题。
- 不绕过充电专属、私密、会员或其他受限内容；没有公开权限的视频仍不会展示。

### 我的页面

- 修复收藏夹 `attr` 位标志被误判为“收藏夹已失效”的问题。
- 收藏夹缺少封面时，尝试使用其中首个公开视频的封面补齐。
- 收藏夹、收藏内容、我的订阅、我的关注和本机观看记录均支持搜索。
- 新增时间点笔记管理入口，集中显示笔记标题、视频标题、时间点、记录时间和可选画面。
- 设置页新增“关于”，展示安装版本、项目地址和负责人；可配置每次启动从 GitHub Release 检查正式更新，发现新版本时显示红点与 Release 入口。
- 重新设计“我的关注”卡片，分层显示头像、昵称、UID、认证和签名。
- 重新设计本机观看记录卡片，让标题、分P标题、观看进度和具体时间在窄屏上也能完整阅读。

### 工程质量

- 所有新增或修改的 Dart 函数均包含中文作用注释。
- `flutter analyze` 无问题。
- 完整 `flutter test` 共 191 项全部通过。
- Windows 中文目录下可通过英文临时目录构建 Release APK。

## 已实现功能

### 专注计时

- 首页提供专注目标、25/45/60 分钟快捷时长和 1～180 分钟自定义时长。
- 支持开始、暂停、继续、提前结束和到时自动完成；切后台、锁屏或重启应用后恢复任务，并把无法确认仍在播放的时段记为打断。
- 首页创建的专注会先等待用户关联视频；只有关联分P由播放器实际播放时才累计专注时间，视频暂停和后台时间不会继续消耗；正常缓冲加载不再误停专注计时。
- 专注目标、计划时长、实际时长、状态和最近记录只保存在当前设备。
- 首页显示今日专注分钟、按时完成次数和最近五条记录，不设置排行榜或强制连续打卡。
- 视频全屏左上角显示当前目标与剩余时间，并与本地时间、电量保持同一排；目标超过 12 个字符后限宽循环滚动。
- 播放器可以直接按 25/45 分钟、当前分P剩余时长或自定义 1～180 分钟开始专注，并自动记录来源视频、分P、最后位置和“上次看到”画面。
- 多P视频在播放键旁提供上一集和下一集；首页 Pin 与统计记录均可点击返回关联视频和分P。
- 活动专注支持增加 5 分钟；自然完成或提前结束时，播放器会自动暂停当前视频。
- 正常完成会显示覆盖屏幕顶部到下方的礼花雨并允许再专注 5 分钟；手动暂停或退出播放器会先鼓励继续，坚持退出时可记录原因和可选继续提醒。
- 首页和“我的”页面均可进入专注数据看板，查看 7 天、30 天或全部指标与每日趋势。
- 统计趋势使用自适应折线图；记录管理显示打断次数、打断原因和终止原因，并支持搜索、筛选、排序、单条删除和清空。
- 统计页和统计分享图均显示自适应日期与完整时长坐标；分享图按范围自动抽样日期，避免 30 天数据挤在一起。
- Android 提醒由系统闹钟管理，并在每次安排前检查通知与精确闹钟权限；小米系设备会额外引导后台自启动和无限制电量设置。
- 设置页提供统一权限管理；设备重启、应用升级或重新取得精确闹钟权限后，会恢复仍待触发的提醒（主要为 Android）。

### 搜索与视频详情

- 支持关键词、BV 号和 B 站视频链接。
- 支持候选词、搜索历史、自动分页、排序、发布日期、时长和内容分区筛选。
- 搜索结果显示标题、UP 主、发布时间、播放量、弹幕数、时长和多P提示。
- 视频详情包含标题、简介、标签、公开统计、分P、UP 主入口和 UGC 合集。

### 原生与桌面播放器

- 竖屏播放器按视频真实比例居中显示，默认不再用裁切方式放大竖屏视频。
- 竖屏右上角提供画中画、弹幕和更多设置；字幕与画面比例设置均可直接使用。
- 播放器和详情共用一条滚动链路，向上浏览时播放器会连续缩小并完全收起。
- **Android 与桌面（Windows / Linux / macOS）默认均使用 media_kit（libmpv）实验性播放**（共享栈；见 [`docs/PLAYBACK_BACKEND.md`](docs/PLAYBACK_BACKEND.md)），以便专注跟播计时。
- Media3 + MethodChannel + Flutter `Texture` 的 `NativePlaybackService` **仍保留在工程中**，可供注入或调试回退；**iOS 未使用 media_kit**。
- 支持播放/暂停、进度拖动、双击快进/快退、长按临时三倍速、清晰度与倍速切换。
- 支持横向滑动进度预览、竖向亮度/音量调节、沉浸全屏、画面比例、字幕、弹幕和画中画（部分系统能力仍以 Android 平台服务为主）。
- 桌面播放页支持常用键盘快捷键（空格、方向键、全屏、静音、弹幕等）。
- 支持 MediaSession、耳机和系统媒体按钮（主要为 Android）。
- 支持播放进度、最后分P、本机观看记录；边播边缓存等在 media_kit 路径上可能弱于旧 Media3 主路径。
- 本机观看记录可从首页宽屏网格或「我的」进入，并尽量恢复分P与进度。
- 支持按视频时间点创建本机笔记、保存当前画面，并在竖屏、全屏和“我的”页面继续管理（截帧在 media_kit 上可能受限）。
- 网络波动时会尝试重试、备用 CDN 和有限次数播放数据刷新。

### 登录与只读账号数据

- 手机号、密码和人机验证均在 B 站官方网页中完成，FocuBili 不接触用户密码（Android / 部分桌面）。
- 支持应用 WebView 会话检测（Android；macOS 可尝试）和用户主动导入 Cookie。
- **桌面推荐 Cookie 粘贴登录**：写入本机 prefs，与播放请求共用同一会话键；Windows 官方 WebView 登录受限。
- 部分受权限控制的流仍需要有效 Cookie；公开试看是否可用取决于 CDN。
- 支持只读查看收藏夹、收藏内容、已关注 UP 主和已订阅 UGC 合集。
- 不提供收藏、取关、私信或其他账号写操作。

## 当前限制

- 项目依赖非官方公开接口，接口可能随平台策略调整而失效或触发风控。
- 充电专属、会员、课程、番剧、私密或其他受访问控制保护的内容不会被绕过。
- **Android 与桌面** media_kit 播放均为**实验性**：依赖 libmpv / `media_kit_libs_video`；DASH 双轨等仍在演进。iOS 不在 media_kit 路径上。
- Android Release 为 **per-ABI 多 APK**（无 fat）；多数手机安装 **arm64-v8a**。见 [`docs/CODEMAGIC.md`](docs/CODEMAGIC.md)。
- macOS 构建为未签名 / **未公证** zip，不提供 App Store 分发。
- 弹幕屏蔽词、透明度、字号、轨道记忆和解码策略仍待完善。
- 时间点笔记目前只保存在当前设备，已支持手动导出和系统分享，但尚未提供自动同步或云备份。
- 不同 Android 厂商的全屏安全区、画中画和后台恢复仍需要更多真机验证。
- Android 提醒已支持重启恢复和厂商后台保护引导，但不同品牌的自启动、电量限制和待机调度仍需在更多真机持续验收；桌面无对等系统闹钟 / 勿扰。
- Release 产物目前多为学习测试签名配置，仅适合试装；正式长期分发前应配置并妥善保存独立签名密钥。

## 下载

最新多端构建：**[v1.2.1 Release](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1)** · 校验和 [RELEASE_NOTES_v1.2.1](docs/RELEASE_NOTES_v1.2.1.md) / 附件 `SHA256SUMS.txt`。

| 平台 | 资产 | 备注 |
|------|------|------|
| Android **arm64-v8a** | [FocuBili-v1.2.1-android-arm64-v8a.apk](https://github.com/chocolatedesue/FocuBili/releases/download/v1.2.1/FocuBili-v1.2.1-android-arm64-v8a.apk) | **多数真机** |
| Android armeabi-v7a | [FocuBili-v1.2.1-android-armeabi-v7a.apk](https://github.com/chocolatedesue/FocuBili/releases/download/v1.2.1/FocuBili-v1.2.1-android-armeabi-v7a.apk) | 32 位 ARM |
| Android x86_64 | [FocuBili-v1.2.1-android-x86_64.apk](https://github.com/chocolatedesue/FocuBili/releases/download/v1.2.1/FocuBili-v1.2.1-android-x86_64.apk) | 模拟器 / x86 |
| Windows x64 | [FocuBili-v1.2.1-windows-x64.zip](https://github.com/chocolatedesue/FocuBili/releases/download/v1.2.1/FocuBili-v1.2.1-windows-x64.zip) | 解压运行 |
| macOS | [FocuBili-v1.2.1-macos.zip](https://github.com/chocolatedesue/FocuBili/releases/download/v1.2.1/FocuBili-v1.2.1-macos.zip) | 未公证 |

**不提供** fat / universal 单 APK（media_kit 原生库体积）。云构建命名见 [`docs/CODEMAGIC.md`](docs/CODEMAGIC.md)。拉取 Release 可用 [`scripts/download_release.sh`](scripts/download_release.sh)。

较早 Android 版本可能仍在 [L1Xu4n/FocuBili Releases](https://github.com/L1Xu4n/FocuBili/releases)（历史存档）。

## 本地构建

### 环境

- Flutter 3.44.6+ stable（README 徽章对应验证版本；Codemagic 使用 `stable` channel）
- Dart 3.12.2（随 Flutter SDK 提供，无需单独安装）
- JDK 21（本地）/ JDK 17（Codemagic Android workflow）
- Android SDK 36
- Android NDK 28.2.13676358

Android 构建链固定为 Gradle 8.14.3、Android Gradle Plugin 8.11.1 和 Kotlin 2.2.20；最低支持 Android 7.0（API 24）。项目当前使用 Flutter 3.44.6，构建命令见上方说明。

专注计时的视频关联、打断和通知规则已经内置在应用流程中，并会继续通过自动化测试回归。

```bash
git clone https://github.com/chocolatedesue/FocuBili.git
cd FocuBili
flutter pub get
dart analyze
flutter test
# 按 ABI 拆分；不要依赖 fat app-release.apk 作为发布物
flutter build apk --release --split-per-abi
```

Split Release APK 默认生成在：

```text
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

多数真机安装 `app-arm64-v8a-release.apk`。Gradle `splits.abi.universalApk = false` 与 Flutter `--split-per-abi` 对齐，见 [`docs/CODEMAGIC.md`](docs/CODEMAGIC.md)。

Windows / macOS 桌面可参考 Flutter 官方桌面构建命令（需本机启用对应 desktop platform）；产物形态与云编译 zip 一致时便于对照 Release 资产。

Windows 用户建议把仓库放在不含中文和空格的目录。若必须使用中文目录，可以先映射英文盘符再构建：

```powershell
subst X: "C:\path\to\FocuBili"
Set-Location X:\
flutter build apk --release --split-per-abi
```

### 云编译（Codemagic · GitHub Actions）

仓库根目录提供 [`codemagic.yaml`](codemagic.yaml)，并与 GitHub Actions 互补：

| 来源 | Workflow / 说明 | 产物 |
|------|-----------------|------|
| Codemagic | `android-apk` | **per-ABI** Release APK（`armeabi-v7a` / `arm64-v8a` / `x86_64`，无 fat） |
| Codemagic | `macos-build` | macOS `.app` zip（未签名 / 未公证） |
| Codemagic | `windows-build` | Windows Release 目录 zip（需可用 Windows 实例） |
| GitHub Actions | Windows 桌面构建 | Windows zip（见仓库 Actions / Release 资产） |
| GitHub Release | [v1.2.1](https://github.com/chocolatedesue/FocuBili/releases/tag/v1.2.1) | 已打包 APK + Win/mac zip 与校验说明（后续 Android 多为多 ABI） |

接入步骤、可选 Android 签名、ABI 选择与桌面能力说明见 [docs/CODEMAGIC.md](docs/CODEMAGIC.md)。

> **播放后端**：Win/Linux/macOS **与 Android 默认**均走 **media_kit（实验性）** 共享栈；Media3 Native 仍可注入回退；**iOS 未迁 media_kit**。Windows 构建也可走 GitHub Actions；桌面 Cookie 粘贴与播放共用 prefs 会话。详见 [`docs/PLAYBACK_BACKEND.md`](docs/PLAYBACK_BACKEND.md)、[`docs/PLAN_ANDROID_MEDIA_KIT.md`](docs/PLAN_ANDROID_MEDIA_KIT.md)。

## 项目结构

```text
lib/
├─ core/                 # 主题与路由
├─ features/             # 首页、搜索、播放器、时间点笔记、登录与个人页
├─ models/               # 视频、分P、合集、笔记、账号与预览模型
└─ services/             # B 站数据、账号、字幕弹幕与播放桥

android/app/src/main/kotlin/com/focubili/app/
├─ MainActivity.kt               # Flutter 宿主、系统栏与画中画生命周期
├─ NativePlaybackController.kt   # Media3、播放数据、缓存与进度记忆
└─ BilibiliCookieController.kt   # WebView Cookie 会话桥
```

播放器已经按 Flutter 页面、控制栏、弹幕、合集以及 **media_kit（Android 默认 + 桌面）** / Native Media3 回退路径拆分。首次安装时展示的完整声明见 [用户须知与使用协议](docs/USER_AGREEMENT.md)。

## 隐私与安全

- 项目没有自建服务器。
- 不在 Flutter 表单中收集 B 站密码。
- 不把 Cookie、播放记录或搜索记录上传到开发者服务器。
- 只有投稿风控请求会把现有 B 站 Cookie 临时发送回 `api.bilibili.com`；Cookie 不写日志、不写文件，也不会发送给第三方域名。
- 播放进度、最后分P、搜索记录、本机观看记录和时间点笔记均保存在本机。
- 笔记中可选的视频画面写入应用私有目录，卸载应用时会随应用数据一并删除。
- 视频缓存位于应用缓存目录，可由用户或系统清理（Android 路径更完整）。
- WBI 签名只用于读取公开接口，不用于绕过访问控制。

## 致谢

- [PiliPala](https://github.com/guozhigq/pilipala)：优秀的 Flutter 第三方 B 站客户端。FocuBili 在技术路线、模块划分和移动端产品思路上受到了它的启发。
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)：空间公开接口、WBI 参数和请求上下文的实现为本项目提供了重要参考。
- [JKVideo](https://github.com/tiajinsha/JKVideo)：优秀的 React Native 第三方 B 站客户端。FocuBili 在研究原生 DASH 播放链路与单一播放器所有权时参考了它的公开实现思路。

详细说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。感谢所有上游作者和贡献者。

## 许可证

本项目以 [GNU General Public License v3.0](LICENSE) 发布。

使用、修改或分发本项目时，请同时遵守第三方项目许可证、平台条款和内容版权要求。

项目主要在 Codex 协助下开发。

友情链接：
[Linux.do](https://linux.do/)——新的理想型社区
