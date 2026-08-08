import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 播放器桌面快捷键意图：与具体页面解耦，便于映射表单测。
final class PlayerTogglePlayIntent extends Intent {
  const PlayerTogglePlayIntent();
}

/// 退出一层 UI（笔记 / 全屏 / 页面），与返回键同级。
final class PlayerBackIntent extends Intent {
  const PlayerBackIntent();
}

/// 相对当前进度快退。
final class PlayerSeekBackwardIntent extends Intent {
  const PlayerSeekBackwardIntent({this.seconds = 5});

  final int seconds;
}

/// 相对当前进度快进。
final class PlayerSeekForwardIntent extends Intent {
  const PlayerSeekForwardIntent({this.seconds = 5});

  final int seconds;
}

/// 提高媒体音量。
final class PlayerVolumeUpIntent extends Intent {
  const PlayerVolumeUpIntent();
}

/// 降低媒体音量。
final class PlayerVolumeDownIntent extends Intent {
  const PlayerVolumeDownIntent();
}

/// 静音或恢复静音前音量。
final class PlayerToggleMuteIntent extends Intent {
  const PlayerToggleMuteIntent();
}

/// 进入或退出全屏。
final class PlayerToggleFullscreenIntent extends Intent {
  const PlayerToggleFullscreenIntent();
}

/// 显示或隐藏控制层。
final class PlayerToggleControlsIntent extends Intent {
  const PlayerToggleControlsIntent();
}

/// 播放器默认桌面快捷键：空格 / Esc / 方向键 / F / M / C。
///
/// 不在此处处理「是否在输入框内」——由页面在 Action 里再过滤。
Map<ShortcutActivator, Intent> playerDesktopShortcutBindings() {
  return <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.space):
        const PlayerTogglePlayIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
        const PlayerTogglePlayIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const PlayerBackIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const PlayerSeekBackwardIntent(seconds: 5),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const PlayerSeekForwardIntent(seconds: 5),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        const PlayerSeekBackwardIntent(seconds: 10),
    const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        const PlayerSeekForwardIntent(seconds: 10),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const PlayerVolumeUpIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const PlayerVolumeDownIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF):
        const PlayerToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.f11):
        const PlayerToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM):
        const PlayerToggleMuteIntent(),
    const SingleActivator(LogicalKeyboardKey.keyC):
        const PlayerToggleControlsIntent(),
  };
}

/// 当前焦点是否在可编辑文本中；为 true 时不应劫持空格/方向键等。
bool playerShortcutShouldIgnoreForFocus([FocusNode? primaryFocus]) {
  final FocusNode? focus = primaryFocus ?? FocusManager.instance.primaryFocus;
  if (focus == null) {
    return false;
  }
  // EditableText 获得焦点时 primaryFocus 通常是其内部 focus node。
  if (focus.context?.widget is EditableText) {
    return true;
  }
  final BuildContext? context = focus.context;
  if (context == null) {
    return false;
  }
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}
