import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'media_kit_playback_service.dart';
import 'native_playback_service.dart';

/// 按平台创建 [PlaybackService] 实现。
///
/// | Platform | Backend |
/// |----------|---------|
/// | Windows / Linux / macOS | [MediaKitPlaybackService] (media_kit) |
/// | Android | [MediaKitPlaybackService] (media_kit) |
/// | iOS / Web / other | [NativePlaybackService] (platform channel) |
///
/// 详见 [docs/PLAYBACK_BACKEND.md](../../docs/PLAYBACK_BACKEND.md)。
///
/// 单元测试请用 [createPlaybackServiceForTargets] 覆盖各平台分支；
/// VM 上 [createPlaybackService] 仍走真实 [Platform]（Linux CI → media_kit）。
PlaybackService createPlaybackService() {
  return createPlaybackServiceForTargets(
    isAndroid: !kIsWeb && Platform.isAndroid,
    isIOS: !kIsWeb && Platform.isIOS,
    isWindows: !kIsWeb && Platform.isWindows,
    isLinux: !kIsWeb && Platform.isLinux,
    isMacOS: !kIsWeb && Platform.isMacOS,
    isWeb: kIsWeb,
  );
}

/// Pure platform → backend selection for unit tests (no [Platform] / [kIsWeb]).
@visibleForTesting
PlaybackService createPlaybackServiceForTargets({
  required bool isAndroid,
  required bool isIOS,
  required bool isWindows,
  required bool isLinux,
  required bool isMacOS,
  bool isWeb = false,
}) {
  if (isWeb) {
    return NativePlaybackService();
  }
  if (isWindows || isLinux || isMacOS || isAndroid) {
    return MediaKitPlaybackService();
  }
  // iOS and unknown platforms keep the native channel backend.
  if (isIOS) {
    return NativePlaybackService();
  }
  return NativePlaybackService();
}
