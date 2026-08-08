# Fix: focus timer pausing during normal video buffering

## Problem

`PlayerPage._syncFocusPlaybackState` treated focus as playing only when:

```dart
snapshot.isPlaying && snapshot.phase == PlaybackPhase.ready
```

During normal rebuffer, media_kit can emit `phase == loading` while `isPlaying` stays true. That made `actuallyPlaying` flip to false and called `FocusTimerController.updatePlaybackState(isPlaying: false)` with `FocusPauseReason.playback`, pausing the focus timer until ready returned.

Seek already had `_focusSeekTransitionActive` grace; plain buffering did not.

## Fix (player_page only)

- Extracted `isFocusPlaybackActuallyPlaying(PlaybackSnapshot)` (top-level, `@visibleForTesting`).
- Focus counts as playing when `isPlaying` and phase is `ready` **or** `loading`.
- Still not playing for: `!isPlaying`, `ended`, `error`, `idle` (even if flags are odd).
- Existing seek transition grace unchanged.
- No changes to media_kit open path, playurl, or MediaKitPlaybackService.

## Tests

- `test/focus_playback_actually_playing_test.dart` — pure helper matrix.
- Also run: `focus_timer_controller_test.dart`, `focus_dashboard_test.dart`, `flutter analyze lib/features/player/player_page.dart`.
