import 'package:media_kit_video/media_kit_video.dart';

/// Optional surface hook for media_kit backends without changing [PlaybackService].
///
/// WIRE / [PlayerPage] should:
/// 1. Call [PlaybackService.initialize] (returns `null` texture for media_kit).
/// 2. If the service `is MediaKitSurfaceHost`, pass [videoController] into
///    `PlayerVideoSurface(videoController: host.videoController)`.
///
/// Native [NativePlaybackService] does not implement this interface.
abstract interface class MediaKitSurfaceHost {
  /// media_kit [VideoController] for [PlayerVideoSurface]; null before
  /// [PlaybackService.initialize] or after dispose.
  VideoController? get videoController;
}
