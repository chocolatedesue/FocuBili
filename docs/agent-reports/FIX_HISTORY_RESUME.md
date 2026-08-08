# FIX_HISTORY_RESUME

## Problem
Home / full watch-history opened player with `VideoPreview` only — no part CID or seek position.

## Fix
- `PlayerRouteArgs` + `AppRouter` support resume fields (backward compatible with bare `VideoPreview`).
- `PlayerInitialPositionSource.history` snackbar label.
- `WatchHistoryLauncher` resolves part by page number then title; pushes route args.
- Home section + history page call the launcher.

## Tests
`test/watch_history_launcher_test.dart`
