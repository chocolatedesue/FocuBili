import 'native_playback_service.dart';

/// 按平台创建 [PlaybackService] 实现。
///
/// **Wave 0 行为（本文件当前状态）:** 全平台返回 [NativePlaybackService]，
/// 与历史 `player_page` 直接 `NativePlaybackService()` 一致，行为不变。
///
/// **Wave 3 预期:** 桌面（linux / windows / macos）切换为 media_kit 实现；
/// Android 默认仍走 native Media3，可选 media_kit 双后端。
/// 详见 [docs/PLAYBACK_BACKEND.md](../../docs/PLAYBACK_BACKEND.md)。
PlaybackService createPlaybackService() {
  // W3 将在此处按 defaultTargetPlatform / Platform.isXxx 分支。
  // 当前故意不分支，避免未接线的 MediaKitPlaybackService 影响现网。
  return NativePlaybackService();
}
