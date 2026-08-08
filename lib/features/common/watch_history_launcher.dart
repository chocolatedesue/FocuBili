import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/router/player_route_args.dart';
import '../../models/video_preview.dart';
import '../../models/watch_history_entry.dart';
import '../../services/bilibili_service.dart';
import '../player/player_page.dart';

/// Opens a local watch-history entry at the last part and position when possible.
abstract final class WatchHistoryLauncher {
  /// Looks up [entry.bvid], resolves the last part, and pushes the player route.
  ///
  /// Returns `true` when navigation started. On lookup failure shows a snackbar
  /// and returns `false`. Callers should gate concurrent opens themselves.
  static Future<bool> open(
    BuildContext context,
    WatchHistoryEntry entry, {
    BilibiliService? service,
  }) async {
    final String bvid = entry.bvid.trim();
    if (bvid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('这条观看记录没有有效的视频编号'),
              duration: Duration(seconds: 3),
            ),
          );
      }
      return false;
    }
    final BilibiliService videoService = service ?? BilibiliVideoInfoService();
    try {
      final VideoPreview video = await videoService.lookupVideo(bvid);
      if (!context.mounted) {
        return false;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.player,
        arguments: buildRouteArgs(video, entry),
      );
      return true;
    } on Object catch (error) {
      if (!context.mounted) {
        return false;
      }
      final String message = error is BilibiliLookupException
          ? error.message
          : '无法打开该视频，请稍后重试。';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
        );
      return false;
    }
  }

  /// Builds named-route args that resume [entry]'s last part and non-zero position.
  static PlayerRouteArgs buildRouteArgs(
    VideoPreview video,
    WatchHistoryEntry entry,
  ) {
    final VideoPart? part = resolvePart(video, entry);
    final Duration? position =
        entry.lastPosition > Duration.zero ? entry.lastPosition : null;
    return PlayerRouteArgs(
      video: video,
      initialPartCid: part?.cid,
      initialPosition: position,
      initialPositionSource: PlayerInitialPositionSource.history,
    );
  }

  /// Builds a [PlayerPage] with the same resume fields as [buildRouteArgs].
  static PlayerPage buildPlayerPage(
    VideoPreview video,
    WatchHistoryEntry entry, {
    BilibiliService? videoService,
  }) {
    final PlayerRouteArgs args = buildRouteArgs(video, entry);
    return PlayerPage(
      video: args.video,
      bilibiliService: videoService,
      initialPartCid: args.initialPartCid,
      initialPosition: args.initialPosition,
      initialPositionSource: args.initialPositionSource,
    );
  }

  /// Resolves the history part by page number, then title; returns null if none match.
  ///
  /// History entries do not store CID. When resolution fails the player opens the
  /// default part and may still apply [WatchHistoryEntry.lastPosition] if set.
  static VideoPart? resolvePart(VideoPreview video, WatchHistoryEntry entry) {
    final int pageNumber = entry.lastPartPageNumber;
    if (pageNumber >= 1) {
      for (final VideoPart part in video.parts) {
        if (part.pageNumber == pageNumber) {
          return part;
        }
      }
    }
    final String title = entry.lastPartTitle.trim();
    if (title.isNotEmpty) {
      for (final VideoPart part in video.parts) {
        if (part.title.trim() == title) {
          return part;
        }
      }
    }
    return null;
  }
}
