import 'package:flutter_test/flutter_test.dart';
import 'package:focubili/services/bilibili_playurl_service.dart';
import 'package:focubili/services/native_playback_service.dart';
import 'package:focubili/services/playback_contracts.dart';

/// 最小 UGC DASH playurl 成功响应：720P AVC 视频 + 音轨 + accept_quality。
const String kFixtureDashSuccess = r'''
{
  "code": 0,
  "message": "0",
  "ttl": 1,
  "data": {
    "from": "local",
    "result": "suee",
    "quality": 64,
    "format": "dash",
    "timelength": 120000,
    "accept_format": "hdflv2,flv,flv720,flv480,mp4",
    "accept_description": ["高清 1080P", "高清 720P", "清晰 480P", "流畅 360P"],
    "accept_quality": [80, 64, 32, 16],
    "video_codecid": 7,
    "dash": {
      "duration": 120,
      "video": [
        {
          "id": 80,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/80/avc.m4s",
          "backup_url": [
            "https://upos-sz-mirrorhw.bilivideo.com/upgcxcode/80/avc.m4s"
          ],
          "bandwidth": 2000000,
          "mimeType": "video/mp4",
          "codecs": "avc1.640028",
          "width": 1920,
          "height": 1080,
          "frameRate": "30.000"
        },
        {
          "id": 80,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/80/hevc.m4s",
          "backup_url": [],
          "bandwidth": 1500000,
          "mimeType": "video/mp4",
          "codecs": "hev1.1.6.L120.90",
          "width": 1920,
          "height": 1080,
          "frameRate": "30.000"
        },
        {
          "id": 64,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/64/avc.m4s",
          "backup_url": [
            "https://upos-sz-mirrorhw.bilivideo.com/upgcxcode/64/avc-bak.m4s"
          ],
          "bandwidth": 1000000,
          "mimeType": "video/mp4",
          "codecs": "avc1.64001F",
          "width": 1280,
          "height": 720,
          "frameRate": "30.000"
        },
        {
          "id": 64,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/64/hevc.m4s",
          "backup_url": [],
          "bandwidth": 800000,
          "mimeType": "video/mp4",
          "codecs": "hev1.1.6.L120.90",
          "width": 1280,
          "height": 720,
          "frameRate": "30.000"
        },
        {
          "id": 32,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/32/avc.m4s",
          "backup_url": [],
          "bandwidth": 500000,
          "mimeType": "video/mp4",
          "codecs": "avc1.4D401E",
          "width": 852,
          "height": 480,
          "frameRate": "30.000"
        }
      ],
      "audio": [
        {
          "id": 30280,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/audio/30280.m4s",
          "backup_url": [
            "https://upos-sz-mirrorhw.bilivideo.com/upgcxcode/audio/30280-bak.m4s"
          ],
          "bandwidth": 192000,
          "mimeType": "audio/mp4",
          "codecs": "mp4a.40.2"
        },
        {
          "id": 30216,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/audio/30216.m4s",
          "backup_url": [],
          "bandwidth": 64000,
          "mimeType": "audio/mp4",
          "codecs": "mp4a.40.2"
        }
      ]
    }
  }
}
''';

/// 仅 dash.video 有 id、无 accept_quality 时走 fallback 清晰度列表。
const String kFixtureDashNoAcceptQuality = r'''
{
  "code": 0,
  "message": "0",
  "data": {
    "quality": 64,
    "dash": {
      "video": [
        {
          "id": 64,
          "baseUrl": "https://upos-sz-mirrorcos.bilivideo.com/v64.m4s",
          "backupUrl": ["https://upos-sz-mirrorhw.bilivideo.com/v64-bak.m4s"],
          "bandwidth": 900000,
          "codecs": "avc1.64001F",
          "height": 720
        },
        {
          "id": 32,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/v32.m4s",
          "bandwidth": 400000,
          "codecs": "avc1.4D401E",
          "height": 480
        }
      ],
      "audio": [
        {
          "id": 30216,
          "base_url": "https://upos-sz-mirrorcos.bilivideo.com/a.m4s",
          "bandwidth": 64000,
          "codecs": "mp4a.40.2"
        }
      ]
    }
  }
}
''';

/// 接口业务错误。
const String kFixtureApiError = r'''
{
  "code": -404,
  "message": "啥都木有",
  "ttl": 1,
  "data": null
}
''';

/// 有 data 但无 dash（例如仅 flv 老格式）。
const String kFixtureNoDash = r'''
{
  "code": 0,
  "message": "0",
  "data": {
    "quality": 64,
    "durl": [{"url": "https://example.com/not-used.flv"}]
  }
}
''';

/// 视频轨 URL 全部非 bilivideo 域名，应判定为无安全地址。
const String kFixtureUnsafeUrls = r'''
{
  "code": 0,
  "message": "0",
  "data": {
    "quality": 64,
    "accept_quality": [64],
    "accept_description": ["高清 720P"],
    "dash": {
      "video": [
        {
          "id": 64,
          "base_url": "https://evil.example.com/video.m4s",
          "bandwidth": 1000000,
          "codecs": "avc1.64001F",
          "height": 720
        }
      ],
      "audio": []
    }
  }
}
''';

void main() {
  const String sampleBvid = 'BV1GJ411x7h7';
  const int sampleCid = 171776208;

  group('BilibiliPlayUrlService.fetch (fixture, no network)', () {
    test('解析 DASH 成功：选中 quality 64 的 AVC 视频与最高带宽音轨', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async {
          expect(uri.host, 'api.bilibili.com');
          expect(uri.path, '/x/player/playurl');
          expect(uri.queryParameters['bvid'], sampleBvid);
          expect(uri.queryParameters['cid'], '$sampleCid');
          expect(uri.queryParameters['qn'], '64');
          expect(uri.queryParameters['fnval'], '16');
          expect(uri.queryParameters['fourk'], '1');
          expect(headers['Accept'], 'application/json');
          expect(headers['User-Agent'], contains('Chrome/126'));
          expect(headers['Referer'], 'https://www.bilibili.com/video/$sampleBvid');
          expect(headers.containsKey('Cookie'), isFalse);
          return kFixtureDashSuccess;
        },
      );

      final PlayUrlManifest manifest = await service.fetch(
        bvid: sampleBvid,
        cid: sampleCid,
        quality: 64,
      );

      expect(
        manifest.videoUrl,
        'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/64/avc.m4s',
      );
      expect(
        manifest.audioUrl,
        'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/audio/30280.m4s',
      );
      expect(manifest.quality, 64);
      expect(
        manifest.qualities.map((PlaybackQuality q) => q.id).toList(),
        <int>[80, 64, 32, 16],
      );
      expect(
        manifest.qualities.firstWhere((PlaybackQuality q) => q.id == 80).label,
        '高清 1080P',
      );
      expect(manifest.httpHeaders['Referer'], contains(sampleBvid));
      expect(manifest.httpHeaders['User-Agent'], contains('Chrome/126'));
      expect(manifest.httpHeaders['Origin'], 'https://www.bilibili.com');
      expect(manifest.httpHeaders['Accept-Encoding'], 'identity');
    });

    test('Cookie 仅经参数注入到请求头与媒体头', () async {
      const String cookie = 'SESSDATA=abc; bili_jct=xyz';
      Map<String, String>? seenHeaders;
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async {
          seenHeaders = headers;
          return kFixtureDashSuccess;
        },
      );

      final PlayUrlManifest manifest = await service.fetch(
        bvid: sampleBvid,
        cid: sampleCid,
        cookieHeader: cookie,
      );

      expect(seenHeaders?['Cookie'], cookie);
      expect(manifest.httpHeaders['Cookie'], cookie);
    });

    test('请求 80 时选中 1080P AVC 而非同 id 的 HEVC', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async {
          // 模拟服务端回写 quality=80
          return kFixtureDashSuccess.replaceFirst(
            '"quality": 64',
            '"quality": 80',
          );
        },
      );

      final PlayUrlManifest manifest = await service.fetch(
        bvid: sampleBvid,
        cid: sampleCid,
        quality: 80,
      );

      expect(manifest.quality, 80);
      expect(manifest.videoUrl, contains('/80/avc.m4s'));
      expect(manifest.videoUrl, isNot(contains('hevc')));
    });

    test('无 accept_quality 时从 dash.video 推导清晰度列表', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async =>
            kFixtureDashNoAcceptQuality,
      );

      final PlayUrlManifest manifest = await service.fetch(
        bvid: sampleBvid,
        cid: sampleCid,
      );

      expect(manifest.videoUrl, contains('v64.m4s'));
      expect(manifest.audioUrl, contains('a.m4s'));
      expect(
        manifest.qualities.map((PlaybackQuality q) => q.id).toList(),
        <int>[64, 32],
      );
      expect(
        manifest.qualities.firstWhere((PlaybackQuality q) => q.id == 64).label,
        '高清 720P',
      );
    });

    test('非法 BV 号直接失败且不发起请求', () async {
      var called = false;
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async {
          called = true;
          return kFixtureDashSuccess;
        },
      );

      await expectLater(
        service.fetch(bvid: 'not-a-bvid', cid: sampleCid),
        throwsA(isA<BilibiliPlayUrlException>()),
      );
      expect(called, isFalse);
    });

    test('cid <= 0 直接失败', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async =>
            kFixtureDashSuccess,
      );

      await expectLater(
        service.fetch(bvid: sampleBvid, cid: 0),
        throwsA(isA<BilibiliPlayUrlException>()),
      );
    });

    test('接口 code != 0 抛出可读错误', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async =>
            kFixtureApiError,
      );

      await expectLater(
        service.fetch(bvid: sampleBvid, cid: sampleCid),
        throwsA(
          isA<BilibiliPlayUrlException>().having(
            (BilibiliPlayUrlException e) => e.message,
            'message',
            contains('啥都木有'),
          ),
        ),
      );
    });

    test('无 dash 时失败', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async =>
            kFixtureNoDash,
      );

      await expectLater(
        service.fetch(bvid: sampleBvid, cid: sampleCid),
        throwsA(
          isA<BilibiliPlayUrlException>().having(
            (BilibiliPlayUrlException e) => e.message,
            'message',
            contains('DASH'),
          ),
        ),
      );
    });

    test('非 bilivideo 媒体地址被拒绝', () async {
      final BilibiliPlayUrlService service = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async =>
            kFixtureUnsafeUrls,
      );

      await expectLater(
        service.fetch(bvid: sampleBvid, cid: sampleCid),
        throwsA(
          isA<BilibiliPlayUrlException>().having(
            (BilibiliPlayUrlException e) => e.message,
            'message',
            contains('安全'),
          ),
        ),
      );
    });
  });

  group('static helpers', () {
    test('isSafeMediaUrl 只接受 bilivideo HTTPS', () {
      expect(
        BilibiliPlayUrlService.isSafeMediaUrl(
          'https://upos-sz-mirrorcos.bilivideo.com/a.m4s',
        ),
        isTrue,
      );
      expect(
        BilibiliPlayUrlService.isSafeMediaUrl(
          'https://xy.bilivideo.cn/path/file.m4s',
        ),
        isTrue,
      );
      expect(
        BilibiliPlayUrlService.isSafeMediaUrl('http://upos.bilivideo.com/a.m4s'),
        isFalse,
      );
      expect(
        BilibiliPlayUrlService.isSafeMediaUrl('https://example.com/a.m4s'),
        isFalse,
      );
    });

    test('compatibilityScore 优先 AVC', () {
      expect(
        BilibiliPlayUrlService.compatibilityScore('avc1.640028'),
        greaterThan(
          BilibiliPlayUrlService.compatibilityScore('hev1.1.6.L120.90'),
        ),
      );
      expect(BilibiliPlayUrlService.compatibilityScore('av01.0.08M.08'), 0);
    });

    test('parsePlayUrlResponse 可直接从 JSON 构建 manifest', () {
      final PlayUrlManifest manifest =
          BilibiliPlayUrlService.parsePlayUrlResponse(
            kFixtureDashSuccess,
            requestedQuality: 64,
            bvid: sampleBvid,
          );
      expect(manifest.videoUrl, contains('/64/avc.m4s'));
      expect(manifest.audioUrl, isNotNull);
      expect(manifest.qualities, isNotEmpty);
    });

    test('implements BilibiliPlayUrlClient', () {
      final BilibiliPlayUrlClient client = BilibiliPlayUrlService(
        requestJson: (Uri uri, {required Map<String, String> headers}) async =>
            kFixtureDashSuccess,
      );
      expect(client, isA<BilibiliPlayUrlService>());
    });
  });
}
