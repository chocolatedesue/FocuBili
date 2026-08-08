import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'media_kit_playback_service.dart';
import 'native_playback_service.dart';

/// 按平台创建 [PlaybackService] 实现。
///
/// | Platform | Backend |
/// |----------|---------|
/// | Windows / Linux / macOS | [MediaKitPlaybackService] (media_kit) |
/// | Android / iOS / other | [NativePlaybackService] (Media3 channel) |
///
/// 详见 [docs/PLAYBACK_BACKEND.md](../../docs/PLAYBACK_BACKEND.md)。
///
/// 单元测试可向 [PlayerPage] 注入 fake；VM 测试在 Linux 上会得到 media_kit。
PlaybackService createPlaybackService() {
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return MediaKitPlaybackService();
  }
  return NativePlaybackService();
}
