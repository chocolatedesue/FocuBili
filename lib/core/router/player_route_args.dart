import '../../features/player/player_page.dart';
import '../../models/video_preview.dart';

/// Named-route arguments for [AppRoutes.player], including optional resume state.
class PlayerRouteArgs {
  /// Creates player route arguments; omit position fields to open at the default part.
  const PlayerRouteArgs({
    required this.video,
    this.initialPartCid,
    this.initialPosition,
    this.initialPositionSource = PlayerInitialPositionSource.note,
  });

  /// Video detail payload required by the player page.
  final VideoPreview video;

  /// Preferred part CID when resuming a multi-part video; null uses player defaults.
  final int? initialPartCid;

  /// Seek target within the selected part; null leaves native/history restore alone.
  final Duration? initialPosition;

  /// Labels the resume snackbar (note / focus / learning / history).
  final PlayerInitialPositionSource initialPositionSource;
}
