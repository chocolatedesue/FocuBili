import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focubili/core/router/app_router.dart';
import 'package:focubili/core/router/player_route_args.dart';
import 'package:focubili/features/common/watch_history_launcher.dart';
import 'package:focubili/features/player/player_page.dart';
import 'package:focubili/models/video_preview.dart';
import 'package:focubili/models/watch_history_entry.dart';
import 'package:focubili/services/bilibili_service.dart';

WatchHistoryEntry _entry({
  String bvid = 'BV1TEST',
  int lastPartPageNumber = 2,
  String lastPartTitle = 'P2 中篇',
  Duration lastPosition = const Duration(minutes: 4, seconds: 20),
}) {
  return WatchHistoryEntry(
    bvid: bvid,
    title: '测试视频',
    ownerName: 'UP',
    lastPartTitle: lastPartTitle,
    lastPartPageNumber: lastPartPageNumber,
    watchedAt: DateTime(2026, 8, 1, 12),
    lastPosition: lastPosition,
  );
}

VideoPreview _multiPartVideo() {
  return const VideoPreview(
    bvid: 'BV1TEST',
    cid: 100,
    title: '测试视频',
    ownerName: 'UP',
    parts: <VideoPart>[
      VideoPart(
        pageNumber: 1,
        cid: 100,
        title: 'P1 开篇',
        duration: Duration(minutes: 10),
      ),
      VideoPart(
        pageNumber: 2,
        cid: 200,
        title: 'P2 中篇',
        duration: Duration(minutes: 12),
      ),
      VideoPart(
        pageNumber: 3,
        cid: 300,
        title: 'P3 结尾',
        duration: Duration(minutes: 8),
      ),
    ],
  );
}

class _FakeBilibiliService implements BilibiliService {
  _FakeBilibiliService(this.video, {this.throwOnLookup = false});

  final VideoPreview video;
  final bool throwOnLookup;
  int lookupCount = 0;

  @override
  Future<VideoPreview> lookupVideo(String input) async {
    lookupCount += 1;
    if (throwOnLookup) {
      throw const BilibiliLookupException('lookup failed');
    }
    return video;
  }

  @override
  Future<VideoSearchPage> searchVideos(
    String keyword, {
    int page = 1,
    VideoSearchFilter filter = const VideoSearchFilter(),
  }) async {
    return VideoSearchPage(
      results: const <VideoSearchResult>[],
      page: page,
      totalPages: 0,
    );
  }

  @override
  Future<List<String>> suggestKeywords(String input) async {
    return const <String>[];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolvePart matches lastPartPageNumber to part cid', () {
    final VideoPreview video = _multiPartVideo();
    final WatchHistoryEntry entry = _entry(lastPartPageNumber: 2);

    final VideoPart? part = WatchHistoryLauncher.resolvePart(video, entry);

    expect(part, isNotNull);
    expect(part!.cid, 200);
    expect(part.pageNumber, 2);
  });

  test('resolvePart falls back to lastPartTitle when page missing', () {
    final VideoPreview video = _multiPartVideo();
    final WatchHistoryEntry entry = _entry(
      lastPartPageNumber: 99,
      lastPartTitle: 'P3 结尾',
    );

    final VideoPart? part = WatchHistoryLauncher.resolvePart(video, entry);

    expect(part, isNotNull);
    expect(part!.cid, 300);
  });

  test('resolvePart returns null when page and title do not match', () {
    final VideoPreview video = _multiPartVideo();
    final WatchHistoryEntry entry = _entry(
      lastPartPageNumber: 99,
      lastPartTitle: '不存在的分P',
    );

    expect(WatchHistoryLauncher.resolvePart(video, entry), isNull);
  });

  test('buildRouteArgs passes cid and non-zero position with history source', () {
    final VideoPreview video = _multiPartVideo();
    final WatchHistoryEntry entry = _entry(
      lastPartPageNumber: 2,
      lastPosition: const Duration(minutes: 4, seconds: 20),
    );

    final PlayerRouteArgs args = WatchHistoryLauncher.buildRouteArgs(
      video,
      entry,
    );

    expect(args.video.bvid, 'BV1TEST');
    expect(args.initialPartCid, 200);
    expect(args.initialPosition, const Duration(minutes: 4, seconds: 20));
    expect(args.initialPositionSource, PlayerInitialPositionSource.history);
  });

  test('buildRouteArgs omits zero position', () {
    final VideoPreview video = _multiPartVideo();
    final WatchHistoryEntry entry = _entry(lastPosition: Duration.zero);

    final PlayerRouteArgs args = WatchHistoryLauncher.buildRouteArgs(
      video,
      entry,
    );

    expect(args.initialPartCid, 200);
    expect(args.initialPosition, isNull);
  });

  test('buildPlayerPage mirrors route args', () {
    final VideoPreview video = _multiPartVideo();
    final WatchHistoryEntry entry = _entry(lastPartPageNumber: 3);

    final PlayerPage page = WatchHistoryLauncher.buildPlayerPage(video, entry);

    expect(page.initialPartCid, 300);
    expect(page.initialPosition, const Duration(minutes: 4, seconds: 20));
    expect(page.initialPositionSource, PlayerInitialPositionSource.history);
  });

  testWidgets('AppRouter player route accepts PlayerRouteArgs', (
    WidgetTester tester,
  ) async {
    final VideoPreview video = _multiPartVideo();
    PlayerPage? opened;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (RouteSettings settings) {
          final Route<dynamic> route = AppRouter.onGenerateRoute(settings);
          if (settings.name == AppRoutes.player) {
            final MaterialPageRoute<void> material =
                route as MaterialPageRoute<void>;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                opened = material.builder(context) as PlayerPage;
                return const Scaffold(body: Text('player-ready'));
              },
            );
          }
          return route;
        },
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.player,
                  arguments: PlayerRouteArgs(
                    video: video,
                    initialPartCid: 200,
                    initialPosition: const Duration(seconds: 42),
                    initialPositionSource: PlayerInitialPositionSource.history,
                  ),
                );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(opened, isNotNull);
    expect(opened!.video.bvid, 'BV1TEST');
    expect(opened!.initialPartCid, 200);
    expect(opened!.initialPosition, const Duration(seconds: 42));
    expect(opened!.initialPositionSource, PlayerInitialPositionSource.history);
  });

  testWidgets('AppRouter player route keeps VideoPreview backward compat', (
    WidgetTester tester,
  ) async {
    final VideoPreview video = _multiPartVideo();
    PlayerPage? opened;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (RouteSettings settings) {
          final Route<dynamic> route = AppRouter.onGenerateRoute(settings);
          if (settings.name == AppRoutes.player) {
            final MaterialPageRoute<void> material =
                route as MaterialPageRoute<void>;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) {
                opened = material.builder(context) as PlayerPage;
                return const Scaffold(body: Text('player-ready'));
              },
            );
          }
          return route;
        },
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.player,
                  arguments: video,
                );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(opened, isNotNull);
    expect(opened!.video.bvid, 'BV1TEST');
    expect(opened!.initialPartCid, isNull);
    expect(opened!.initialPosition, isNull);
  });

  testWidgets('WatchHistoryLauncher.open pushes player with resume args', (
    WidgetTester tester,
  ) async {
    final VideoPreview video = _multiPartVideo();
    final _FakeBilibiliService service = _FakeBilibiliService(video);
    final WatchHistoryEntry entry = _entry(lastPartPageNumber: 2);
    Object? pushedArguments;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                key: const Key('open-history'),
                onPressed: () {
                  WatchHistoryLauncher.open(context, entry, service: service);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
        onGenerateRoute: (RouteSettings settings) {
          pushedArguments = settings.arguments;
          if (settings.name == AppRoutes.player) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) =>
                  const Scaffold(body: Text('player-ready')),
            );
          }
          return AppRouter.onGenerateRoute(settings);
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-history')));
    await tester.pumpAndSettle();

    expect(service.lookupCount, 1);
    expect(pushedArguments, isA<PlayerRouteArgs>());
    final PlayerRouteArgs args = pushedArguments! as PlayerRouteArgs;
    expect(args.initialPartCid, 200);
    expect(args.initialPosition, const Duration(minutes: 4, seconds: 20));
    expect(args.initialPositionSource, PlayerInitialPositionSource.history);
  });
}
