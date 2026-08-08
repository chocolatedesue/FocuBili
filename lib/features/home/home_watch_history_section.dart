import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/adaptive_layout.dart';
import '../../core/router/app_router.dart';
import '../../models/video_preview.dart';
import '../../models/watch_history_entry.dart';
import '../../services/bilibili_service.dart';
import '../../services/watch_history_service.dart';
import '../common/watch_history_card.dart';

/// 首页宽屏「最近观看」网格：只读本机历史，不接推荐流。
class HomeWatchHistorySection extends StatefulWidget {
  /// 创建最近观看区块；可注入服务便于测试。
  const HomeWatchHistorySection({
    super.key,
    this.historyService,
    this.bilibiliService,
    this.refreshGeneration = 0,
    this.maxItems = 12,
  });

  final WatchHistoryService? historyService;
  final BilibiliService? bilibiliService;

  /// 与首页 `refreshGeneration` 对齐，切换回首页时重新读取。
  final int refreshGeneration;

  /// 首页最多展示条数，完整列表仍走「本机观看记录」页。
  final int maxItems;

  @override
  State<HomeWatchHistorySection> createState() =>
      _HomeWatchHistorySectionState();
}

class _HomeWatchHistorySectionState extends State<HomeWatchHistorySection> {
  late final WatchHistoryService _historyService;
  late final BilibiliService _bilibiliService;
  List<WatchHistoryEntry> _entries = const <WatchHistoryEntry>[];
  bool _loading = true;
  String? _error;
  String? _openingBvid;
  int _reloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _historyService = widget.historyService ?? WatchHistoryService();
    _bilibiliService = widget.bilibiliService ?? BilibiliVideoInfoService();
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant HomeWatchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshGeneration != widget.refreshGeneration) {
      unawaited(_reload());
    }
  }

  Future<void> _reload() async {
    final int generation = ++_reloadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<WatchHistoryEntry> all = await _historyService.loadHistory();
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      final List<WatchHistoryEntry> limited = all
          .take(widget.maxItems)
          .toList(growable: false);
      setState(() {
        _entries = limited;
        _loading = false;
      });
      unawaited(_backfillMissingThumbnails(limited));
    } catch (_) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        _entries = const <WatchHistoryEntry>[];
        _loading = false;
        _error = '读取本机观看记录失败';
      });
    }
  }

  Future<void> _backfillMissingThumbnails(
    List<WatchHistoryEntry> entries,
  ) async {
    final List<WatchHistoryEntry> missing = entries
        .where((WatchHistoryEntry e) => e.thumbnailUrl.isEmpty)
        .toList(growable: false);
    if (missing.isEmpty) {
      return;
    }
    final Map<String, String> urls = <String, String>{};
    for (int offset = 0; offset < missing.length; offset += 2) {
      final int end = (offset + 2).clamp(0, missing.length).toInt();
      final List<MapEntry<String, String>?> results = await Future.wait(
        missing.sublist(offset, end).map((WatchHistoryEntry entry) async {
          try {
            final VideoPreview video = await _bilibiliService.lookupVideo(
              entry.bvid,
            );
            if (video.thumbnailUrl.isEmpty) {
              return null;
            }
            return MapEntry<String, String>(entry.bvid, video.thumbnailUrl);
          } catch (_) {
            return null;
          }
        }),
      );
      for (final MapEntry<String, String>? item in results) {
        if (item != null) {
          urls[item.key] = item.value;
        }
      }
    }
    if (!mounted || urls.isEmpty) {
      return;
    }
    final List<WatchHistoryEntry> updated = await _historyService
        .backfillThumbnails(urls);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = updated.take(widget.maxItems).toList(growable: false);
    });
  }

  Future<void> _openEntry(WatchHistoryEntry entry) async {
    if (_openingBvid != null) {
      return;
    }
    setState(() => _openingBvid = entry.bvid);
    try {
      final VideoPreview video = await _bilibiliService.lookupVideo(entry.bvid);
      if (!mounted) {
        return;
      }
      setState(() => _openingBvid = null);
      await Navigator.of(context).pushNamed(AppRoutes.player, arguments: video);
      if (mounted) {
        unawaited(_reload());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _openingBvid = null);
      final String message = error is BilibiliLookupException
          ? error.message
          : '无法打开该视频，请稍后重试。';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openFullHistory() {
    Navigator.of(context).pushNamed(AppRoutes.watchHistory);
  }

  @override
  Widget build(BuildContext context) {
    final int columns = AdaptiveLayout.homeWatchHistoryColumnCount(
      MediaQuery.sizeOf(context).width,
    );
    return Card(
      key: const Key('home-watch-history-section'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.history_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '最近观看',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('home-watch-history-all'),
                  onPressed: _openFullHistory,
                  child: const Text('全部'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '仅本机记录，不与 B 站账号同步',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildBody(columns),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(int columns) {
    if (_loading) {
      return const Padding(
        key: Key('home-watch-history-loading'),
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        key: const Key('home-watch-history-error'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(_error!)),
            TextButton(onPressed: () => unawaited(_reload()), child: const Text('重试')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Padding(
        key: const Key('home-watch-history-empty'),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.history_toggle_off_rounded,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            const Text('还没有本机观看记录'),
            const SizedBox(height: 4),
            Text(
              '播放视频后会显示在这里，方便在桌面端继续看。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // 非滚动网格：高度由行数推算，嵌在首页 CustomScrollView 内。
    const double tileHeight = 210;
    const double spacing = 12;
    final int rows = (_entries.length / columns).ceil();
    final double gridHeight =
        rows * tileHeight + (rows > 0 ? (rows - 1) * spacing : 0);

    return SizedBox(
      key: const Key('home-watch-history-grid'),
      height: gridHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          mainAxisExtent: tileHeight,
        ),
        itemCount: _entries.length,
        itemBuilder: (BuildContext context, int index) {
          final WatchHistoryEntry entry = _entries[index];
          return WatchHistoryGridCard(
            entry: entry,
            isOpening: _openingBvid == entry.bvid,
            onTap: () => unawaited(_openEntry(entry)),
          );
        },
      ),
    );
  }
}
