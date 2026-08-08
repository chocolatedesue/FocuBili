import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focubili/models/video_preview.dart';
import 'package:focubili/services/cookie_header_provider.dart';
import 'package:focubili/services/media_kit_playback_service.dart';
import 'package:focubili/services/native_playback_service.dart';
import 'package:focubili/services/playback_contracts.dart';
import 'package:focubili/services/playback_service_media_kit_ext.dart';

/// Fake playurl client that records fetch args and returns a fixture manifest.
class _FakePlayUrlClient implements BilibiliPlayUrlClient {
  _FakePlayUrlClient();

  PlayUrlManifest? manifest;
  Object? error;
  final List<Map<String, Object?>> fetches = <Map<String, Object?>>[];

  @override
  Future<PlayUrlManifest> fetch({
    required String bvid,
    required int cid,
    int quality = 64,
    String cookieHeader = '',
  }) async {
    fetches.add(<String, Object?>{
      'bvid': bvid,
      'cid': cid,
      'quality': quality,
      'cookieHeader': cookieHeader,
    });
    if (error != null) {
      throw error!;
    }
    return manifest ??
        PlayUrlManifest(
          videoUrl: 'https://upos-sz-mirror.bilivideo.com/video.m4s',
          audioUrl: 'https://upos-sz-mirror.bilivideo.com/audio.m4s',
          quality: quality,
          qualities: const <PlaybackQuality>[
            PlaybackQuality(id: 80, label: '高清 1080P'),
            PlaybackQuality(id: 64, label: '高清 720P'),
          ],
          httpHeaders: const <String, String>{
            'Referer': 'https://www.bilibili.com',
            'User-Agent': 'test-ua',
          },
        );
  }
}

VideoPreview _sampleVideo() {
  return const VideoPreview(
    bvid: 'BV1GJ411x7h7',
    cid: 137649199,
    title: '测试视频',
    ownerName: '焦点哔哩',
    parts: <VideoPart>[
      VideoPart(
        pageNumber: 1,
        cid: 137649199,
        title: 'P1',
        duration: Duration(minutes: 3),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MediaKitPlaybackHelpers', () {
    test('buildDashEdlUri encodes length-prefixed video and audio segments', () {
      const String video = 'https://cdn.example/v.m4s';
      const String audio = 'https://cdn.example/a.m4s';
      final String edl = MediaKitPlaybackHelpers.buildDashEdlUri(
        videoUrl: video,
        audioUrl: audio,
      );
      expect(edl.startsWith('edl://'), isTrue);
      expect(edl, contains('!new_stream'));
      expect(edl, contains('%${video.length}%$video'));
      expect(edl, contains('%${audio.length}%$audio'));
    });

    test('buildPlayableResource uses plain URL when audio missing', () {
      expect(
        MediaKitPlaybackHelpers.buildPlayableResource(
          videoUrl: 'https://cdn.example/v.m4s',
        ),
        'https://cdn.example/v.m4s',
      );
      expect(
        MediaKitPlaybackHelpers.buildPlayableResource(
          videoUrl: 'https://cdn.example/v.m4s',
          audioUrl: '  ',
        ),
        'https://cdn.example/v.m4s',
      );
    });

    test('buildPlayableResource uses EDL when audio present', () {
      final String resource = MediaKitPlaybackHelpers.buildPlayableResource(
        videoUrl: 'https://v',
        audioUrl: 'https://a',
      );
      expect(resource.startsWith('edl://'), isTrue);
    });

    test('buildMedia attaches httpHeaders and start', () {
      const PlayUrlManifest manifest = PlayUrlManifest(
        videoUrl: 'https://v.m4s',
        audioUrl: 'https://a.m4s',
        quality: 64,
        httpHeaders: <String, String>{'Referer': 'https://www.bilibili.com'},
      );
      final media = MediaKitPlaybackHelpers.buildMedia(
        manifest,
        start: const Duration(seconds: 12),
      );
      expect(media.uri.startsWith('edl://'), isTrue);
      expect(media.httpHeaders?['Referer'], 'https://www.bilibili.com');
      expect(media.start, const Duration(seconds: 12));
    });

    test('saved state encode/decode round-trip', () {
      final String raw = MediaKitPlaybackHelpers.encodeSavedState(
        cid: 99,
        pageNumber: 2,
        position: const Duration(milliseconds: 4500),
      );
      final SavedPlaybackState? state =
          MediaKitPlaybackHelpers.decodeSavedState(raw);
      expect(state, isNotNull);
      expect(state!.cid, 99);
      expect(state.pageNumber, 2);
      expect(state.position, const Duration(milliseconds: 4500));
    });

    test('decodeSavedState rejects garbage', () {
      expect(MediaKitPlaybackHelpers.decodeSavedState(null), isNull);
      expect(MediaKitPlaybackHelpers.decodeSavedState(''), isNull);
      expect(MediaKitPlaybackHelpers.decodeSavedState('{'), isNull);
      expect(
        MediaKitPlaybackHelpers.decodeSavedState('{"cid":0,"pageNumber":1}'),
        isNull,
      );
    });

    test('applyHostEvent maps playing/buffering/completed/position', () {
      const PlaybackSnapshot idle = PlaybackSnapshot();
      final PlaybackSnapshot loading = MediaKitPlaybackHelpers.applyHostEvent(
        idle,
        const MediaKitBufferingEvent(true),
      );
      expect(loading.phase, PlaybackPhase.loading);

      final PlaybackSnapshot ready = MediaKitPlaybackHelpers.applyHostEvent(
        loading.copyWith(isPlaying: true),
        const MediaKitPlayingEvent(true),
      );
      expect(ready.phase, PlaybackPhase.ready);
      expect(ready.isPlaying, isTrue);

      final PlaybackSnapshot pos = MediaKitPlaybackHelpers.applyHostEvent(
        ready,
        const MediaKitPositionEvent(Duration(seconds: 5)),
      );
      expect(pos.position, const Duration(seconds: 5));

      final PlaybackSnapshot ended = MediaKitPlaybackHelpers.applyHostEvent(
        pos,
        const MediaKitCompletedEvent(true),
      );
      expect(ended.phase, PlaybackPhase.ended);
      expect(ended.isPlaying, isFalse);

      final PlaybackSnapshot err = MediaKitPlaybackHelpers.applyHostEvent(
        ready,
        const MediaKitErrorEvent('demux failed'),
      );
      expect(err.phase, PlaybackPhase.error);
      expect(err.message, 'demux failed');
    });

    test('applyHostEvent updates aspect ratio from size', () {
      final PlaybackSnapshot next = MediaKitPlaybackHelpers.applyHostEvent(
        const PlaybackSnapshot(),
        const MediaKitSizeEvent(width: 1920, height: 1080),
      );
      expect(next.videoAspectRatio, closeTo(16 / 9, 0.001));
    });
  });

  group('MediaKitPlaybackService with fake host', () {
    late FakeMediaKitPlayerHost host;
    late _FakePlayUrlClient playUrl;
    late MemoryCookieHeaderProvider cookies;
    late MediaKitPlaybackService service;

    setUp(() {
      host = FakeMediaKitPlayerHost();
      playUrl = _FakePlayUrlClient();
      cookies = MemoryCookieHeaderProvider('SESSDATA=abc');
      service = MediaKitPlaybackService(
        playUrlClient: playUrl,
        cookieHeaderProvider: cookies,
        hostFactory: () => host,
        preferencesLoader: SharedPreferences.getInstance,
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test('implements MediaKitSurfaceHost and initialize returns null texture',
        () async {
      expect(service, isA<MediaKitSurfaceHost>());
      final int? textureId = await service.initialize();
      expect(textureId, isNull);
      expect(host.calls, contains('initialize'));
      // Fake host has no VideoController.
      expect(service.videoController, isNull);
    });

    test('openVideo fetches playurl with cookie and opens dual-track media',
        () async {
      final List<PlaybackSnapshot> snapshots = <PlaybackSnapshot>[];
      final sub = service.states.listen(snapshots.add);

      await service.initialize();
      await service.openVideo(_sampleVideo(), quality: 80);

      expect(playUrl.fetches, hasLength(1));
      expect(playUrl.fetches.single['bvid'], 'BV1GJ411x7h7');
      expect(playUrl.fetches.single['cid'], 137649199);
      expect(playUrl.fetches.single['quality'], 80);
      expect(playUrl.fetches.single['cookieHeader'], 'SESSDATA=abc');

      expect(host.opened, hasLength(1));
      final media = host.opened.single;
      expect(media.uri.startsWith('edl://'), isTrue);
      expect(media.httpHeaders?['Referer'], 'https://www.bilibili.com');

      expect(
        snapshots.any((PlaybackSnapshot s) => s.phase == PlaybackPhase.loading),
        isTrue,
      );
      expect(
        snapshots.any((PlaybackSnapshot s) => s.phase == PlaybackPhase.ready),
        isTrue,
      );
      final PlaybackSnapshot last = snapshots.last;
      expect(last.currentQuality, 80);
      expect(last.availableQualities.map((q) => q.id), containsAll(<int>[80, 64]));
      expect(last.isPlaying, isTrue);

      await sub.cancel();
    });

    test('openVideo video-only when audioUrl null', () async {
      playUrl.manifest = const PlayUrlManifest(
        videoUrl: 'https://upos-sz-mirror.bilivideo.com/only-video.m4s',
        audioUrl: null,
        quality: 64,
        httpHeaders: <String, String>{'User-Agent': 'ua'},
      );
      await service.initialize();
      await service.openVideo(_sampleVideo());
      expect(host.opened.single.uri, contains('only-video.m4s'));
      expect(host.opened.single.uri.startsWith('edl://'), isFalse);
    });

    test('play pause seek setSpeed selectQuality', () async {
      await service.initialize();
      await service.openVideo(_sampleVideo());

      await service.pause();
      expect(host.calls, contains('pause'));

      await service.play();
      expect(host.calls, contains('play'));

      await service.seekTo(const Duration(seconds: 10));
      expect(host.calls, contains('seek:10000'));

      await service.seekBy(const Duration(seconds: -3));
      // After seekTo 10s, seekBy -3 → 7s
      expect(host.calls, contains('seek:7000'));

      await service.setPlaybackSpeed(1.5);
      expect(host.calls, contains('setRate:1.5'));

      expect(() => service.setPlaybackSpeed(3.01), throwsArgumentError);
      expect(() => service.setPlaybackSpeed(0.4), throwsArgumentError);

      final int fetchesBefore = playUrl.fetches.length;
      await service.selectQuality(64);
      expect(playUrl.fetches.length, fetchesBefore + 1);
      expect(playUrl.fetches.last['quality'], 64);
      // Quality switch opens again.
      expect(host.opened.length, greaterThanOrEqualTo(2));
    });

    test('loadSavedPlaybackState and restore on open', () async {
      await service.savePlaybackState(
        bvid: 'BV1GJ411x7h7',
        cid: 137649199,
        pageNumber: 1,
        position: const Duration(seconds: 42),
      );
      final SavedPlaybackState? loaded =
          await service.loadSavedPlaybackState('BV1GJ411x7h7');
      expect(loaded, isNotNull);
      expect(loaded!.position, const Duration(seconds: 42));

      await service.initialize();
      await service.openVideo(_sampleVideo());
      expect(host.opened.single.start, const Duration(seconds: 42));
    });

    test('desktop stubs: levels, brightness, volume, pip, capture', () async {
      await service.initialize();
      final SystemPlaybackLevels levels =
          await service.getSystemPlaybackLevels();
      expect(levels.brightness, closeTo(0.5, 0.001));
      expect(levels.volume, closeTo(0.5, 0.001));

      await service.setScreenBrightness(0.8);
      await service.setMediaVolume(0.25);
      expect(host.calls, contains('setVolume:25.0'));

      final SystemPlaybackLevels after =
          await service.getSystemPlaybackLevels();
      expect(after.brightness, closeTo(0.8, 0.001));
      expect(after.volume, closeTo(0.25, 0.001));

      expect(await service.enterPictureInPicture(16 / 9), isFalse);
      expect(await service.captureCurrentFrame(), isNull);
    });

    test('openVideo rejects bad bvid / quality', () async {
      await service.initialize();
      expect(
        () => service.openVideo(
          const VideoPreview(
            bvid: 'not-a-bvid',
            cid: 1,
            title: 'x',
            ownerName: 'y',
            parts: <VideoPart>[
              VideoPart(
                pageNumber: 1,
                cid: 1,
                title: 'p',
                duration: Duration(seconds: 1),
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.openVideo(_sampleVideo(), quality: 0),
        throwsArgumentError,
      );
    });

    test('openVideo surfaces playurl failure as error phase', () async {
      playUrl.error = Exception('network down');
      final List<PlaybackSnapshot> snapshots = <PlaybackSnapshot>[];
      final sub = service.states.listen(snapshots.add);
      await service.initialize();
      await expectLater(
        service.openVideo(_sampleVideo()),
        throwsA(isA<Exception>()),
      );
      expect(
        snapshots.any((PlaybackSnapshot s) => s.phase == PlaybackPhase.error),
        isTrue,
      );
      await sub.cancel();
    });
  });
}
