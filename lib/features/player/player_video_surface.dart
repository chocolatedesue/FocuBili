import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Dual-backend video surface for [PlayerPage].
///
/// - Native Media3 path: pass a non-null [textureId] → Flutter [Texture].
/// - media_kit path (W2/W3): pass a [VideoController] as [videoController]
///   → [Video] from `media_kit_video` (controls disabled; chrome stays in-app).
/// - Neither: empty slot so the parent can keep showing load/error chrome.
///
/// Fit / aspect ratio wrappers stay on the caller (`_buildFittedVideoOutput`);
/// this widget only fills the picture slot.
class PlayerVideoSurface extends StatelessWidget {
  /// Creates a surface that prefers native [textureId], then media_kit.
  const PlayerVideoSurface({
    super.key,
    this.textureId,
    this.videoController,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
  });

  /// Platform texture id from native playback (`PlaybackService.initialize`).
  final int? textureId;

  /// media_kit [VideoController] (or any object typed as such by W2/W3).
  ///
  /// Typed as [Object?] so callers can pass a controller without this file
  /// needing service-layer imports. Only a real [VideoController] is embedded;
  /// other non-null values render a dark placeholder (forward-compat hook).
  final Object? videoController;

  /// BoxFit applied to the media_kit [Video] widget only.
  /// Native [Texture] is laid out by the parent fit wrappers.
  final BoxFit fit;

  /// Filter quality for the media_kit [Video] texture path.
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final int? id = textureId;
    if (id != null) {
      return Texture(textureId: id);
    }

    final Object? controller = videoController;
    if (controller is VideoController) {
      return Video(
        controller: controller,
        fit: fit,
        fill: const Color(0xFF000000),
        filterQuality: filterQuality,
        // PlayerPage owns transport chrome; do not stack media_kit defaults.
        controls: NoVideoControls,
        wakelock: false,
        pauseUponEnteringBackgroundMode: false,
      );
    }

    if (controller != null) {
      // W2/W3 may pass a non-VideoController handle briefly; keep a dark slot.
      // Expected type once wired: media_kit_video.VideoController.
      return const ColoredBox(color: Color(0xFF000000));
    }

    // No picture yet — parent shows loading / idle icon / error UI.
    return const SizedBox.expand();
  }
}
