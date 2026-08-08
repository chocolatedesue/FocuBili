/// 本机观看记录展示用的时间与进度格式化（首页与历史页共用）。
abstract final class WatchHistoryFormat {
  /// 将本机记录时间格式化为年月日和小时分钟。
  static String formatWatchedAt(DateTime watchedAt) {
    final String year = watchedAt.year.toString().padLeft(4, '0');
    final String month = watchedAt.month.toString().padLeft(2, '0');
    final String day = watchedAt.day.toString().padLeft(2, '0');
    final String hour = watchedAt.hour.toString().padLeft(2, '0');
    final String minute = watchedAt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// 将已观看位置转换为简短时分秒文本。
  static String formatWatchedPosition(Duration position) {
    final int totalSeconds = position.inSeconds.clamp(0, 24 * 60 * 60).toInt();
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String twoDigitsMinutes = minutes.toString().padLeft(2, '0');
    final String twoDigitsSeconds = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$twoDigitsMinutes:$twoDigitsSeconds'
        : '$minutes:$twoDigitsSeconds';
  }
}
