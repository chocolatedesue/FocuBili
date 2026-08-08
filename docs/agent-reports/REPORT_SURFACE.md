# REPORT_SURFACE (Wave 1-C)

**Agent:** SURFACE  
**Branch:** `feat/playback-surface`  
**Base:** `feat/playback-foundation` (`369c340`)  
**Date:** 2026-08-08  
**Status:** Complete

## Summary

Introduced `PlayerVideoSurface` as the dual-backend picture slot:

1. **Native (current):** `textureId != null` → Flutter `Texture` (unchanged Android Media3 path).
2. **media_kit (W2/W3):** `videoController is VideoController` → `media_kit_video.Video` with `NoVideoControls` (app owns chrome).
3. **Unknown non-null controller:** black `ColoredBox` placeholder (forward-compat).
4. **Neither:** `SizedBox.expand()` empty slot — parent keeps load/error/idle UI.

`player_page.dart` only swaps the inner `Texture` for `PlayerVideoSurface`; fit/aspect wrappers (`_buildFittedVideoOutput` / `_buildScaledVideoOutput`) and focus logic are untouched. No PlaybackService injection (W3).

## Files

| Path | Action |
|------|--------|
| `lib/features/player/player_video_surface.dart` | **New** |
| `lib/features/player/player_page.dart` | **Minimal** — import + Texture → PlayerVideoSurface |
| `test/player_video_surface_test.dart` | **New** |
| `docs/agent-reports/REPORT_SURFACE.md` | **New** (this file) |

## Exact `player_page.dart` lines touched

Diff against foundation (2 insertions, 1 deletion in body + 1 import line):

| Location | Change |
|----------|--------|
| **Line 46** | Added `import 'player_video_surface.dart';` (after chapter widgets import, before control widgets). |
| **Line 3681** | Inside `_buildVideoOutput()`: `child: Texture(textureId: textureId)` → `child: PlayerVideoSurface(textureId: textureId)`. |

Surrounding context (unchanged):

```dart
// ~3673–3683
Widget _buildVideoOutput() {
  final int? textureId = _textureId;
  if (textureId != null) {
    final double aspectRatio = ...;
    final Widget texture = RepaintBoundary(
      child: PlayerVideoSurface(textureId: textureId),  // was Texture(...)
    );
    return _buildFittedVideoOutput(texture, aspectRatio);
  }
  // idle icon branch unchanged
}
```

**Not modified:** focus timers, overlay stack, `_buildFittedVideoOutput`, `_buildScaledVideoOutput`, service construction, initialize/texture assignment (`_textureId` still from `_playbackService.initialize()`).

## `PlayerVideoSurface` API (W2/W3 hook)

```dart
PlayerVideoSurface({
  int? textureId,
  Object? videoController, // expect media_kit_video.VideoController
  BoxFit fit = BoxFit.contain,           // media_kit Video only
  FilterQuality filterQuality = FilterQuality.low,
})
```

**Priority:** `textureId` → `VideoController` → unknown controller placeholder → empty expand.

**W2 note:** `MediaKitPlaybackService.initialize()` should return `textureId: null` and expose a `VideoController` (via extension / optional getter). **W3** wires that controller into `PlayerVideoSurface(videoController: ...)` when `_textureId == null`. Page can later pass controller without another large rewrite.

**media_kit Video knobs used:**

- `controls: NoVideoControls` — avoid double chrome
- `wakelock: false` / `pauseUponEnteringBackgroundMode: false` — PlayerPage already owns lifecycle policies
- `fill: black`

Outer BoxFit (contain/cover/stretch) remains on `_buildFittedVideoOutput`; native Texture path does not apply the surface-level `fit` (parent handles it). When W3 embeds media_kit Video inside the same fit wrappers, either keep parent fit + Video `BoxFit.contain`, or pass match mode — prefer parent wrappers for parity with native.

## Tests / analyze

| Command | Result |
|---------|--------|
| `flutter analyze` (surface + player_page + test) | **No issues found** |
| `flutter test test/player_video_surface_test.dart` | **4/4 passed** |

Test coverage:

1. `textureId` → `Texture` with matching id  
2. empty surface expands to parent constraints  
3. unknown `videoController` → black `ColoredBox` under surface  
4. `textureId` wins when both args set  

Did **not** construct real `media_kit` `Player`/`VideoController` in unit tests (native lib / binding cost). Type branch is covered by compile-time `is VideoController` + placeholder path.

Related player tests run in the same session (onboarding/sheet/overlay/native/factory) continued green after surface load failures were fixed; surface file alone is the ownership gate.

## Explicit non-goals (not done)

- PlaybackService factory wiring / `videoController` from page state (W3)
- `MediaKitPlaybackService` (W2)
- pubspec / main.dart / services / focus / android
- Large player_page refactor

## Merge notes

- Branch: `feat/playback-surface` off `feat/playback-foundation`.
- Safe to merge after foundation; independent of PLAYURL/COOKIE file trees.
- Only conflict risk: another agent editing `_buildVideoOutput` / imports near line 46 of `player_page.dart` (WIRE owns later controller plumbing — should extend surface call site, not revert Texture).
