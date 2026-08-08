/// 保存应用在手机、平板和宽窗口中共用的响应式布局尺寸。
abstract final class AdaptiveLayout {
  /// 从 600 逻辑像素起按平板或分屏宽窗口增加页面留白。
  static const double tabletBreakpoint = 600;

  /// 从 840 逻辑像素起使用更宽松的横屏平板留白。
  static const double expandedBreakpoint = 840;

  /// 从 900 逻辑像素起在首页展示本机观看历史网格（桌面/宽分屏）。
  static const double homeWatchHistoryBreakpoint = 900;

  /// 首页专注卡片保持舒适阅读宽度，不随平板横屏无限拉长。
  static const double homeContentMaxWidth = 840;

  /// 首页挂载观看历史区时放宽内容限宽，便于多列封面。
  static const double homeWithHistoryMaxWidth = 1100;

  /// 是否在首页展示「最近观看」网格（窄屏仍走「我的 → 观看记录」）。
  static bool showHomeWatchHistory(double width) =>
      width >= homeWatchHistoryBreakpoint;

  /// 首页观看历史网格列数：宽屏 4 列，桌面 3 列。
  static int homeWatchHistoryColumnCount(double width) {
    if (width >= 1200) {
      return 4;
    }
    if (width >= homeWatchHistoryBreakpoint) {
      return 3;
    }
    return 2;
  }

  /// 搜索结果需要容纳封面和信息，因此允许比首页卡片稍宽。
  static const double searchContentMaxWidth = 960;

  /// “我的”页面的账号卡和功能入口保持紧凑的阅读行长。
  static const double profileContentMaxWidth = 720;

  /// 根据可用宽度返回手机、平板和宽屏三档基础页边距。
  static double pageHorizontalPadding(
    double width, {
    double compact = 12,
    double medium = 24,
    double expanded = 32,
  }) {
    if (width >= expandedBreakpoint) {
      return expanded;
    }
    if (width >= tabletBreakpoint) {
      return medium;
    }
    return compact;
  }

  /// 计算居中限宽所需的左右边距，同时保证各宽度档位的最小留白。
  static double centeredHorizontalPadding({
    required double width,
    required double maxContentWidth,
    double compact = 12,
    double medium = 24,
    double expanded = 32,
  }) {
    final double minimumPadding = pageHorizontalPadding(
      width,
      compact: compact,
      medium: medium,
      expanded: expanded,
    );
    final double centeredPadding = (width - maxContentWidth) / 2;
    return centeredPadding > minimumPadding ? centeredPadding : minimumPadding;
  }
}
