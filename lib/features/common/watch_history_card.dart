import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/watch_history_entry.dart';
import 'watch_history_format.dart';

/// 网格样式的本机观看记录卡，供首页宽屏历史区使用。
class WatchHistoryGridCard extends StatelessWidget {
  /// 创建封面在上、标题在下的记录卡。
  const WatchHistoryGridCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.isOpening = false,
  });

  final WatchHistoryEntry entry;
  final VoidCallback? onTap;
  final bool isOpening;

  static const String _imageUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: Key('watch-history-grid-${entry.bvid}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: isOpening ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 封面占可用高度的一部分，避免宽列时 16:10 把文字区挤爆。
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _buildThumbnail(context),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _badge(
                      '已看 ${WatchHistoryFormat.formatWatchedPosition(entry.lastPosition)}',
                    ),
                  ),
                  if (isOpening)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      'P${entry.lastPartPageNumber} · ${entry.lastPartTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    if (entry.thumbnailUrl.isEmpty) {
      return _placeholder(context);
    }
    return CachedNetworkImage(
      imageUrl: entry.thumbnailUrl,
      httpHeaders: const <String, String>{
        'Referer': 'https://www.bilibili.com/',
        'User-Agent': _imageUserAgent,
      },
      fit: BoxFit.cover,
      memCacheWidth: 480,
      maxWidthDiskCache: 720,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (BuildContext context, String url) => _placeholder(context),
      errorWidget: (BuildContext context, String url, Object error) =>
          _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.play_arrow_rounded, color: Colors.black45),
      ),
    );
  }

  Widget _badge(String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
