import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'bilibili_request_policy.dart';
import 'native_playback_service.dart' show PlaybackQuality;
import 'playback_contracts.dart';

/// 可替换的 playurl JSON 请求，便于单测注入 fixture、正式环境走 HTTPS。
///
/// [headers] 已含 Accept / User-Agent / Referer，以及可选 Cookie。
typedef PlayUrlJsonRequest =
    Future<String> Function(Uri uri, {required Map<String, String> headers});

/// 表示拉取或解析 B 站 UGC playurl / DASH 失败，文案可直接展示给用户。
class BilibiliPlayUrlException implements Exception {
  /// 创建一条用户能理解的播放地址获取失败说明。
  const BilibiliPlayUrlException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 从 `api.bilibili.com/x/player/playurl` 拉取 UGC DASH，并选出视频/音轨。
///
/// 对照原生 [NativePlaybackController] 的 playurl + `selectMediaTrack` 逻辑；
/// Cookie 仅通过 [fetch] 的 [cookieHeader] 注入，不碰 WebView。
class BilibiliPlayUrlService implements BilibiliPlayUrlClient {
  /// 创建服务；测试可传入 [requestJson] 跳过真实网络。
  BilibiliPlayUrlService({PlayUrlJsonRequest? requestJson})
    : _requestJson = requestJson ?? _defaultRequestJson;

  static const String apiHost = 'api.bilibili.com';
  static const String playurlPath = '/x/player/playurl';
  static const int defaultQuality = 64;
  static const int dashFeatureFlag = 16;
  static const int networkTimeoutMs = 15_000;

  /// 与原生播放器一致的桌面 Chrome UA，避免 CDN 拒流。
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  static const int _preferredTrackScore = 1000000000000;
  static const int _heightScoreUnit = 1000000;
  static const int _avcTrackScore = 10000000000000;
  static const int _hevcTrackScore = 100000000000;

  static final RegExp _bvidPattern = RegExp(
    r'^BV[0-9A-Za-z]{10}$',
    caseSensitive: false,
  );

  final PlayUrlJsonRequest _requestJson;

  /// 请求指定分 P 的 DASH 地址，选出与 [quality] 最匹配的视频轨及最高可用音轨。
  @override
  Future<PlayUrlManifest> fetch({
    required String bvid,
    required int cid,
    int quality = defaultQuality,
    String cookieHeader = '',
  }) async {
    final String normalizedBvid = bvid.trim();
    final String? referer = buildVideoPageUrl(normalizedBvid);
    if (referer == null) {
      throw const BilibiliPlayUrlException(
        '没有找到有效的 BV 号。请使用类似 BV1GJ411x7h7 的编号。',
      );
    }
    if (cid <= 0) {
      throw const BilibiliPlayUrlException('分 P 编号无效，无法请求播放地址。');
    }

    final int requestedQuality = quality > 0 ? quality : defaultQuality;
    final Uri endpoint = buildPlayUrlEndpoint(
      bvid: normalizedBvid,
      cid: cid,
      quality: requestedQuality,
    );
    final Map<String, String> requestHeaders = buildPlayUrlRequestHeaders(
      bvid: normalizedBvid,
      cookieHeader: cookieHeader,
    );

    final String responseText = await _requestJson(
      endpoint,
      headers: requestHeaders,
    );
    return parsePlayUrlResponse(
      responseText,
      requestedQuality: requestedQuality,
      bvid: normalizedBvid,
      cookieHeader: cookieHeader,
    );
  }

  /// 构造 playurl HTTPS 查询地址（含 DASH fnval 与 fourk）。
  static Uri buildPlayUrlEndpoint({
    required String bvid,
    required int cid,
    required int quality,
  }) {
    return Uri.https(apiHost, playurlPath, <String, String>{
      'bvid': bvid,
      'cid': '$cid',
      'qn': '$quality',
      'fnval': '$dashFeatureFlag',
      'fourk': '1',
    });
  }

  /// 构造拉取 playurl JSON 时的最小请求头（可选 Cookie）。
  static Map<String, String> buildPlayUrlRequestHeaders({
    required String bvid,
    String cookieHeader = '',
  }) {
    final String referer =
        buildVideoPageUrl(bvid) ?? 'https://www.bilibili.com/';
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': desktopUserAgent,
      'Referer': referer,
    };
    final String cookie = cookieHeader.trim();
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return Map<String, String>.unmodifiable(headers);
  }

  /// 打开媒体时附带的 HTTP 头（Referer / UA / Origin 等），与原生 DataSource 对齐。
  static Map<String, String> buildMediaHttpHeaders({
    required String bvid,
    String cookieHeader = '',
  }) {
    final String referer =
        buildVideoPageUrl(bvid) ?? 'https://www.bilibili.com/';
    final Map<String, String> headers = <String, String>{
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Origin': 'https://www.bilibili.com',
      'Referer': referer,
      'User-Agent': desktopUserAgent,
    };
    final String cookie = cookieHeader.trim();
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return Map<String, String>.unmodifiable(headers);
  }

  /// 将 BV 号转为视频页 URL；格式非法时返回 null。
  static String? buildVideoPageUrl(String bvid) {
    final String normalized = bvid.trim();
    if (!_bvidPattern.hasMatch(normalized)) {
      return null;
    }
    return 'https://www.bilibili.com/video/$normalized';
  }

  /// 仅接受 B 站 CDN 的 HTTPS 媒体地址。
  static bool isSafeMediaUrl(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    final String host = uri.host.toLowerCase();
    return host.endsWith('.bilivideo.com') || host.endsWith('.bilivideo.cn');
  }

  /// 编码兼容分：AVC/H.264 最高，HEVC 次之，其余（含 AV1）最低。
  static int compatibilityScore(String codec) {
    final String normalized = codec.trim().toLowerCase();
    if (normalized.startsWith('avc1') || normalized.startsWith('avc3')) {
      return _avcTrackScore;
    }
    if (normalized.startsWith('hev1') || normalized.startsWith('hvc1')) {
      return _hevcTrackScore;
    }
    return 0;
  }

  /// 缺少接口描述时的常见清晰度中文名。
  static String qualityFallbackLabel(int quality) {
    switch (quality) {
      case 127:
        return '超高清 8K';
      case 120:
        return '超清 4K';
      case 116:
        return '高清 1080P60';
      case 112:
        return '高清 1080P+';
      case 80:
        return '高清 1080P';
      case 64:
        return '高清 720P';
      case 32:
        return '清晰 480P';
      case 16:
        return '流畅 360P';
      default:
        return '清晰度 $quality';
    }
  }

  /// 解析 playurl JSON 为 [PlayUrlManifest]（无网络，供单测直接调用）。
  static PlayUrlManifest parsePlayUrlResponse(
    String responseText, {
    required int requestedQuality,
    required String bvid,
    String cookieHeader = '',
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(responseText);
    } on FormatException {
      throw const BilibiliPlayUrlException('播放数据服务返回的内容不是合法 JSON。');
    }
    if (decoded is! Map) {
      throw const BilibiliPlayUrlException('播放数据服务返回的数据格式不正确。');
    }
    final Map<Object?, Object?> root = Map<Object?, Object?>.from(decoded);
    final int code = (root['code'] as num?)?.toInt() ?? -1;
    if (code != 0) {
      final String serverMessage = _readText(root['message'], '');
      final String readable = serverMessage.isEmpty || serverMessage == '0'
          ? '播放数据服务拒绝了本次请求（错误码：$code）。'
          : '无法取得播放数据：$serverMessage（错误码：$code）。';
      throw BilibiliPlayUrlException(readable);
    }
    final Object? dataRaw = root['data'];
    if (dataRaw is! Map) {
      throw const BilibiliPlayUrlException('播放数据服务没有返回视频信息。');
    }
    final Map<Object?, Object?> data = Map<Object?, Object?>.from(dataRaw);
    final Object? dashRaw = data['dash'];
    if (dashRaw is! Map) {
      throw const BilibiliPlayUrlException('该视频没有可用的 DASH 播放数据。');
    }
    final Map<Object?, Object?> dash = Map<Object?, Object?>.from(dashRaw);

    final int serverQuality = (data['quality'] as num?)?.toInt() ?? 0;
    final int actualQuality = serverQuality > 0
        ? serverQuality
        : (requestedQuality > 0 ? requestedQuality : defaultQuality);

    final _SelectedMediaTrack videoTrack = _selectMediaTrack(
      dash['video'],
      preferredId: actualQuality,
    );
    final _SelectedMediaTrack audioTrack = _selectMediaTrack(dash['audio']);

    if (videoTrack.urls.isEmpty) {
      throw const BilibiliPlayUrlException('播放数据没有返回安全的视频地址。');
    }

    final List<PlaybackQuality> qualities = parseQualityOptions(
      data: data,
      dash: dash,
      currentQuality: actualQuality,
    );

    return PlayUrlManifest(
      videoUrl: videoTrack.urls.first,
      audioUrl: audioTrack.urls.isEmpty ? null : audioTrack.urls.first,
      quality: actualQuality,
      qualities: qualities,
      httpHeaders: buildMediaHttpHeaders(
        bvid: bvid,
        cookieHeader: cookieHeader,
      ),
    );
  }

  /// 从 DASH 轨道数组选择目标质量，视频轨优先 AVC/H.264。
  static _SelectedMediaTrack _selectMediaTrack(
    Object? mediaItems, {
    int? preferredId,
  }) {
    if (mediaItems is! List) {
      return const _SelectedMediaTrack(urls: <String>[], codec: '');
    }

    Map<Object?, Object?>? selectedMedia;
    int bestScore = -0x7fffffffffffffff; // Long.MIN_VALUE-ish for Dart int

    for (final Object? item in mediaItems) {
      if (item is! Map) {
        continue;
      }
      final Map<Object?, Object?> media = Map<Object?, Object?>.from(item);
      final List<String> candidateUrls = readMediaUrls(media);
      if (candidateUrls.isEmpty) {
        continue;
      }
      final int trackId = (media['id'] as num?)?.toInt() ?? 0;
      final int qualityBonus =
          preferredId != null && trackId == preferredId
          ? _preferredTrackScore
          : 0;
      final String codecs = _readText(media['codecs'], '');
      final int compatibilityBonus = preferredId != null
          ? compatibilityScore(codecs)
          : 0;
      final int height = (media['height'] as num?)?.toInt() ?? 0;
      final int heightScore =
          (height < 0 ? 0 : height) * _heightScoreUnit;
      final int bandwidth = (media['bandwidth'] as num?)?.toInt() ?? 0;
      final int bandwidthScore = bandwidth < 0 ? 0 : bandwidth;
      final int score =
          qualityBonus + compatibilityBonus + heightScore + bandwidthScore;
      if (score > bestScore) {
        selectedMedia = media;
        bestScore = score;
      }
    }

    if (selectedMedia == null) {
      return const _SelectedMediaTrack(urls: <String>[], codec: '');
    }
    return _SelectedMediaTrack(
      urls: readMediaUrls(selectedMedia),
      codec: _readText(selectedMedia['codecs'], ''),
    );
  }

  /// 读取一条 DASH 轨道的主备 HTTPS 媒体地址并去重。
  static List<String> readMediaUrls(Map<Object?, Object?> media) {
    final LinkedHashSet<String> urls = LinkedHashSet<String>();
    final String primary = _readText(
      media['base_url'] ?? media['baseUrl'],
      '',
    );
    if (isSafeMediaUrl(primary)) {
      urls.add(primary);
    }
    final Object? backupRaw = media['backup_url'] ?? media['backupUrl'];
    if (backupRaw is List) {
      for (final Object? entry in backupRaw) {
        final String backup = _readText(entry, '');
        if (isSafeMediaUrl(backup)) {
          urls.add(backup);
        }
      }
    }
    return List<String>.unmodifiable(urls);
  }

  /// 把 accept_quality / dash.video 组合成去重且按 id 降序的清晰度列表。
  static List<PlaybackQuality> parseQualityOptions({
    required Map<Object?, Object?> data,
    required Map<Object?, Object?> dash,
    required int currentQuality,
  }) {
    final List<PlaybackQuality> qualities = <PlaybackQuality>[];
    final Object? idsRaw = data['accept_quality'];
    final Object? descriptionsRaw = data['accept_description'];
    final List<Object?>? descriptions = descriptionsRaw is List
        ? descriptionsRaw
        : null;

    if (idsRaw is List) {
      for (int index = 0; index < idsRaw.length; index++) {
        final int id = (idsRaw[index] as num?)?.toInt() ?? 0;
        if (id <= 0 || qualities.any((PlaybackQuality q) => q.id == id)) {
          continue;
        }
        String description = '';
        if (descriptions != null && index < descriptions.length) {
          description = _readText(descriptions[index], '');
        }
        qualities.add(
          PlaybackQuality(
            id: id,
            label: description.isEmpty
                ? qualityFallbackLabel(id)
                : description,
          ),
        );
      }
    }

    if (qualities.isEmpty) {
      final Object? videoTracks = dash['video'];
      if (videoTracks is List) {
        for (final Object? item in videoTracks) {
          if (item is! Map) {
            continue;
          }
          final int id =
              (Map<Object?, Object?>.from(item)['id'] as num?)?.toInt() ?? 0;
          if (id > 0 && qualities.every((PlaybackQuality q) => q.id != id)) {
            qualities.add(
              PlaybackQuality(id: id, label: qualityFallbackLabel(id)),
            );
          }
        }
      }
    }

    if (currentQuality > 0 &&
        qualities.every((PlaybackQuality q) => q.id != currentQuality)) {
      qualities.add(
        PlaybackQuality(
          id: currentQuality,
          label: qualityFallbackLabel(currentQuality),
        ),
      );
    }

    qualities.sort(
      (PlaybackQuality a, PlaybackQuality b) => b.id.compareTo(a.id),
    );
    return List<PlaybackQuality>.unmodifiable(qualities);
  }

  /// 默认 HTTPS GET；超时与 bilibili_service 风格一致。
  static Future<String> _defaultRequestJson(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(
      milliseconds: networkTimeoutMs,
    );
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      for (final MapEntry<String, String> header in headers.entries) {
        request.headers.set(header.key, header.value);
      }
      // 与公开 JSON 策略保持同一套 UA/Referer 习惯；playurl 额外允许 Cookie。
      if (!headers.containsKey('User-Agent')) {
        final Map<String, String> policy =
            BilibiliRequestPolicy.publicJsonHeaders(
              uri,
              userAgent: desktopUserAgent,
            );
        for (final MapEntry<String, String> header in policy.entries) {
          request.headers.set(header.key, header.value);
        }
      }
      final HttpClientResponse response = await request.close().timeout(
        const Duration(milliseconds: networkTimeoutMs),
      );
      final String responseText = await response
          .transform(utf8.decoder)
          .join();
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw BilibiliPlayUrlException(
          '播放数据服务暂时不可用（HTTP ${response.statusCode}）。',
        );
      }
      if (responseText.trim().isEmpty) {
        throw const BilibiliPlayUrlException('播放数据服务返回了空内容。');
      }
      return responseText;
    } on BilibiliPlayUrlException {
      rethrow;
    } on SocketException {
      throw const BilibiliPlayUrlException(
        '无法连接到播放数据服务，请检查网络后重试。',
      );
    } on HttpException {
      throw const BilibiliPlayUrlException(
        '播放数据服务的网络响应异常，请稍后重试。',
      );
    } on TimeoutException {
      throw const BilibiliPlayUrlException(
        '播放数据服务响应超时，请稍后重试。',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _readText(Object? value, String fallback) {
    if (value is String) {
      final String text = value.trim();
      return text.isEmpty ? fallback : text;
    }
    if (value == null) {
      return fallback;
    }
    final String text = '$value'.trim();
    return text.isEmpty ? fallback : text;
  }
}

/// 选中媒体轨的编码名与主备 URL。
class _SelectedMediaTrack {
  const _SelectedMediaTrack({required this.urls, required this.codec});

  final List<String> urls;
  final String codec;
}
