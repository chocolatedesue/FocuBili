import 'package:flutter_test/flutter_test.dart';

import 'package:focubili/features/player/player_page.dart';
import 'package:focubili/services/native_playback_service.dart';

/// 覆盖专注计时与播放快照相位的耦合：缓冲 loading 不应打断专注。
void main() {
  group('isFocusPlaybackActuallyPlaying', () {
    test('ready + isPlaying counts as playing for focus', () {
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.ready,
            isPlaying: true,
          ),
        ),
        isTrue,
      );
    });

    test('loading + isPlaying (rebuffer) still counts as playing for focus', () {
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.loading,
            isPlaying: true,
          ),
        ),
        isTrue,
      );
    });

    test('ready but paused does not count as playing', () {
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.ready,
            isPlaying: false,
          ),
        ),
        isFalse,
      );
    });

    test('loading without isPlaying (initial open) does not count as playing', () {
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.loading,
            isPlaying: false,
          ),
        ),
        isFalse,
      );
    });

    test('ended and error never count as playing even if isPlaying stays true', () {
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.ended,
            isPlaying: true,
          ),
        ),
        isFalse,
      );
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.error,
            isPlaying: true,
          ),
        ),
        isFalse,
      );
    });

    test('idle never counts as playing for focus', () {
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.idle,
            isPlaying: true,
          ),
        ),
        isFalse,
      );
      expect(
        isFocusPlaybackActuallyPlaying(
          const PlaybackSnapshot(
            phase: PlaybackPhase.idle,
            isPlaying: false,
          ),
        ),
        isFalse,
      );
    });
  });
}
