import 'native_playback_service.dart' show PlaybackQuality;

/// B 站 playurl / DASH 解析结果，供 media_kit 打开分轨或合流媒体。
///
/// Wave 1-A（PLAYURL）负责填充；Wave 2（MEDIAKIT_SVC）消费。
class PlayUrlManifest {
  /// 创建一份可交给播放器的稳定清单。
  const PlayUrlManifest({
    required this.videoUrl,
    this.audioUrl,
    required this.quality,
    this.qualities = const <PlaybackQuality>[],
    this.httpHeaders = const <String, String>{},
  });

  /// 视频轨（或合流）可播放 URL。
  final String videoUrl;

  /// DASH 分轨时的独立音轨 URL；合流或无音轨时为 null。
  final String? audioUrl;

  /// 当前选中的清晰度编号（与 [PlaybackQuality.id] 一致）。
  final int quality;

  /// 该分 P 可用的清晰度列表。
  final List<PlaybackQuality> qualities;

  /// 打开媒体时需附带的 HTTP 头（如 Referer、User-Agent）。
  final Map<String, String> httpHeaders;
}

/// 从 B 站接口拉取指定分 P 的可播放地址（W1-A 实现）。
///
/// Cookie 仅通过参数注入，实现不得直接依赖 WebView。
abstract interface class BilibiliPlayUrlClient {
  /// 请求 playurl / DASH，并选出与 [quality] 最接近的可用清晰度。
  Future<PlayUrlManifest> fetch({
    required String bvid,
    required int cid,
    int quality = 64,
    String cookieHeader = '',
  });
}

/// 提供请求 B 站接口时使用的 Cookie 头字符串（W1-B 实现）。
///
/// 桌面侧可用偏好存储粘贴登录；Android 可委托现有 auth MethodChannel。
abstract interface class CookieHeaderProvider {
  /// 读取当前可用的 `Cookie` 请求头值（不含 `Cookie:` 前缀）；无登录时返回空串。
  Future<String> readCookieHeader();

  /// 用完整 cookie 字符串替换本地存储（桌面粘贴登录等场景）。
  Future<void> replaceCookies(String cookieHeader);

  /// 清除已保存的 cookie。
  Future<void> clear();
}
