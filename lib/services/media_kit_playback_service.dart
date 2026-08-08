import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_preview.dart';
import 'bilibili_playurl_service.dart';
import 'cookie_header_provider.dart';
import 'native_playback_service.dart';
import 'playback_contracts.dart';
import 'playback_service_media_kit_ext.dart';

/// Loads SharedPreferences; injectable for unit tests.
typedef MediaKitPrefsLoader = Future<SharedPreferences> Function();

/// Builds a real or fake media_kit host; injectable so tests avoid native Player.
typedef MediaKitHostFactory = MediaKitPlayerHost Function();

/// Desktop / cross-platform [PlaybackService] backed by media_kit (libmpv).
///
/// - [initialize] returns `null` texture id; UI embeds [videoController] via
///   [MediaKitSurfaceHost] → [PlayerVideoSurface].
/// - [openVideo] uses [BilibiliPlayUrlClient] + [CookieHeaderProvider], then
///   opens DASH video (+ optional audio via mpv `edl://` dual-stream).
class MediaKitPlaybackService
    implements PlaybackService, MediaKitSurfaceHost {
  /// Creates a media_kit playback service.
  ///
  /// Defaults: [BilibiliPlayUrlService], [createCookieHeaderProvider], live
  /// [MediaKitPlayerHost]. Tests inject fakes via [hostFactory] / clients.
  MediaKitPlaybackService({
    BilibiliPlayUrlClient? playUrlClient,
    CookieHeaderProvider? cookieHeaderProvider,
    MediaKitPrefsLoader? preferencesLoader,
    MediaKitHostFactory? hostFactory,
  }) : _playUrlClient = playUrlClient ?? BilibiliPlayUrlService(),
       _cookieHeaderProvider =
           cookieHeaderProvider ?? createCookieHeaderProvider(),
       _preferencesLoader =
           preferencesLoader ?? SharedPreferences.getInstance,
       _hostFactory = hostFactory ?? MediaKitPlayerHost.live;

  static final RegExp _bvidPattern = RegExp(
    r'^BV[0-9A-Za-z]{10}$',
    caseSensitive: false,
  );

  /// Prefs key prefix for per-bvid last cid / page / position.
  @visibleForTesting
  static const String savedStatePrefsPrefix = 'focubili_mk_playback_';

  final BilibiliPlayUrlClient _playUrlClient;
  final CookieHeaderProvider _cookieHeaderProvider;
  final MediaKitPrefsLoader _preferencesLoader;
  final MediaKitHostFactory _hostFactory;

  // sync: true so UI and tests see phase updates in the same turn as open/play.
  final StreamController<PlaybackSnapshot> _stateController =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);

  MediaKitPlayerHost? _host;
  StreamSubscription<void>? _hostEventsSub;
  bool _disposed = false;
  bool _initialized = false;

  PlaybackSnapshot _snapshot = const PlaybackSnapshot();
  VideoPreview? _currentVideo;
  VideoPart? _currentPart;
  /// Last successful playurl manifest (qualities / URLs); used by selectQuality path.
  PlayUrlManifest? _lastManifest;
  double _mediaVolume = 0.5;
  double _screenBrightness = 0.5;

  /// Last fetched manifest after a successful [openVideo] / [selectQuality].
  @visibleForTesting
  PlayUrlManifest? get lastManifest => _lastManifest;

  @override
  Stream<PlaybackSnapshot> get states => _stateController.stream;

  /// media_kit video output for [PlayerVideoSurface]; null until [initialize].
  @override
  VideoController? get videoController => _host?.videoController;

  /// Underlying media_kit [Player] when using the live host; null in tests
  /// that inject a host without a real player, or before [initialize].
  Player? get player => _host?.player;

  @override
  Future<int?> initialize() async {
    _ensureNotDisposed();
    if (_initialized) {
      return null;
    }
    final MediaKitPlayerHost host = _hostFactory();
    _host = host;
    await host.initialize();
    _hostEventsSub = host.events.listen(_onHostEvent);
    _initialized = true;
    _emit(
      _snapshot.copyWith(
        phase: PlaybackPhase.idle,
        clearMessage: true,
      ),
    );
    // Desktop / media_kit path uses Widget surface, not Flutter Texture id.
    return null;
  }

  @override
  Future<void> openVideo(
    VideoPreview video, {
    VideoPart? part,
    int quality = 64,
  }) async {
    _ensureNotDisposed();
    await _ensureInitialized();

    if (!_bvidPattern.hasMatch(video.bvid.trim())) {
      throw ArgumentError.value(video.bvid, 'video.bvid', '需要有效的 BV 号。');
    }
    final VideoPart targetPart = part ?? video.initialPart;
    if (targetPart.cid <= 0) {
      throw ArgumentError.value(targetPart.cid, 'part.cid', '需要有效的分P编号。');
    }
    if (quality <= 0) {
      throw ArgumentError.value(quality, 'quality', '需要有效的清晰度编号。');
    }

    _currentVideo = video;
    _currentPart = targetPart;

    _emit(
      _snapshot.copyWith(
        phase: PlaybackPhase.loading,
        isPlaying: false,
        position: Duration.zero,
        duration: targetPart.duration > Duration.zero
            ? targetPart.duration
            : video.duration,
        currentQuality: quality,
        clearMessage: true,
      ),
    );

    try {
      final String cookie = await _cookieHeaderProvider.readCookieHeader();
      final PlayUrlManifest manifest = await _playUrlClient.fetch(
        bvid: video.bvid.trim(),
        cid: targetPart.cid,
        quality: quality,
        cookieHeader: cookie,
      );
      _lastManifest = manifest;

      final SavedPlaybackState? saved = await loadSavedPlaybackState(
        video.bvid,
      );
      Duration start = Duration.zero;
      if (saved != null &&
          saved.cid == targetPart.cid &&
          saved.position > Duration.zero) {
        start = saved.position;
      }

      final Media media = MediaKitPlaybackHelpers.buildMedia(
        manifest,
        start: start > Duration.zero ? start : null,
      );

      // WARNING (dual-track): when [manifest.audioUrl] is set we open an mpv
      // `edl://` multi-stream URI (video + audio) so DASH separate tracks play
      // together. Headers from [manifest.httpHeaders] are attached to Media.
      // If edl fails on a platform, fall back is not automatic — see REPORT.
      await _host!.openMedia(media, play: true);

      // Host events may already have flipped phase to ready; always publish
      // quality list + restore markers after a successful open.
      _emit(
        _snapshot.copyWith(
          phase: _snapshot.phase == PlaybackPhase.error
              ? PlaybackPhase.error
              : (_snapshot.phase == PlaybackPhase.idle ||
                      _snapshot.phase == PlaybackPhase.loading
                  ? PlaybackPhase.ready
                  : _snapshot.phase),
          isPlaying: true,
          currentQuality: manifest.quality,
          availableQualities: List<PlaybackQuality>.unmodifiable(
            manifest.qualities,
          ),
          restoredPosition: start,
          position: start > Duration.zero ? start : _snapshot.position,
          clearMessage: true,
        ),
      );
      await _persistCurrentProgress(force: true);
    } catch (error) {
      final String message = error is BilibiliPlayUrlException
          ? error.message
          : '无法打开视频：$error';
      _emit(
        _snapshot.copyWith(
          phase: PlaybackPhase.error,
          isPlaying: false,
          message: message,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    if (_disposed || _host == null) {
      return;
    }
    await _host!.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed || _host == null) {
      return;
    }
    await _host!.pause();
    await _persistCurrentProgress(force: true);
  }

  @override
  Future<void> seekBy(Duration offset) async {
    if (_disposed || _host == null) {
      return;
    }
    final Duration target = _snapshot.position + offset;
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (_snapshot.duration > Duration.zero && target > _snapshot.duration
              ? _snapshot.duration
              : target);
    await _host!.seek(clamped);
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_disposed || _host == null) {
      return;
    }
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : position;
    await _host!.seek(clamped);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    if (!speed.isFinite || speed < 0.5 || speed > 3) {
      throw ArgumentError.value(speed, 'speed', '倍速必须在 0.5 到 3.0 之间。');
    }
    if (_disposed || _host == null) {
      return;
    }
    await _host!.setRate(speed);
    _emit(_snapshot.copyWith(speed: speed));
  }

  @override
  Future<void> selectQuality(int quality) async {
    if (quality <= 0) {
      throw ArgumentError.value(quality, 'quality', '需要有效的清晰度编号。');
    }
    final VideoPreview? video = _currentVideo;
    final VideoPart? part = _currentPart;
    if (video == null || part == null) {
      throw StateError('尚未打开视频，无法切换清晰度。');
    }
    final Duration resumeAt = _snapshot.position;
    final bool wasPlaying = _snapshot.isPlaying;

    _emit(
      _snapshot.copyWith(
        phase: PlaybackPhase.loading,
        currentQuality: quality,
        clearMessage: true,
      ),
    );

    try {
      final String cookie = await _cookieHeaderProvider.readCookieHeader();
      final PlayUrlManifest manifest = await _playUrlClient.fetch(
        bvid: video.bvid.trim(),
        cid: part.cid,
        quality: quality,
        cookieHeader: cookie,
      );
      _lastManifest = manifest;

      final Media media = MediaKitPlaybackHelpers.buildMedia(
        manifest,
        start: resumeAt > Duration.zero ? resumeAt : null,
      );
      // Always start after quality switch; UI may pause if needed.
      await _host!.openMedia(media, play: true);
      if (!wasPlaying) {
        await _host!.pause();
      }

      _emit(
        _snapshot.copyWith(
          phase: PlaybackPhase.loading,
          currentQuality: manifest.quality,
          availableQualities: List<PlaybackQuality>.unmodifiable(
            manifest.qualities,
          ),
          position: resumeAt,
          restoredPosition: resumeAt,
          clearMessage: true,
        ),
      );
    } catch (error) {
      final String message = error is BilibiliPlayUrlException
          ? error.message
          : '切换清晰度失败：$error';
      _emit(
        _snapshot.copyWith(
          phase: PlaybackPhase.error,
          isPlaying: false,
          message: message,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<SavedPlaybackState?> loadSavedPlaybackState(String bvid) async {
    final String key = MediaKitPlaybackHelpers.savedStateKey(bvid);
    try {
      final SharedPreferences preferences = await _preferencesLoader();
      final String? raw = preferences.getString(key);
      return MediaKitPlaybackHelpers.decodeSavedState(raw);
    } catch (_) {
      return null;
    }
  }

  /// Persists last cid / page / position for [bvid] (desktop prefs stub).
  @visibleForTesting
  Future<void> savePlaybackState({
    required String bvid,
    required int cid,
    required int pageNumber,
    required Duration position,
  }) async {
    final String key = MediaKitPlaybackHelpers.savedStateKey(bvid);
    try {
      final SharedPreferences preferences = await _preferencesLoader();
      await preferences.setString(
        key,
        MediaKitPlaybackHelpers.encodeSavedState(
          cid: cid,
          pageNumber: pageNumber,
          position: position,
        ),
      );
    } catch (_) {
      // Prefs unavailable — ignore.
    }
  }

  @override
  Future<SystemPlaybackLevels> getSystemPlaybackLevels() async {
    return SystemPlaybackLevels(
      brightness: _screenBrightness.clamp(0.01, 1).toDouble(),
      volume: _mediaVolume.clamp(0, 1).toDouble(),
    );
  }

  @override
  Future<void> setScreenBrightness(double brightness) async {
    // Desktop: no reliable cross-platform window brightness API here.
    _screenBrightness = brightness.clamp(0.01, 1).toDouble();
  }

  @override
  Future<void> setMediaVolume(double volume) async {
    _mediaVolume = volume.clamp(0, 1).toDouble();
    if (_disposed || _host == null) {
      return;
    }
    // media_kit volume is 0–100.
    await _host!.setVolume(_mediaVolume * 100);
  }

  @override
  Future<bool> enterPictureInPicture(double aspectRatio) async {
    // Desktop PiP not implemented in this wave.
    return false;
  }

  @override
  Future<String?> captureCurrentFrame() async {
    // JPEG bytes are available from media_kit; writing a file path is deferred
    // (needs path_provider wiring). Return null so callers keep native path.
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _persistCurrentProgress(force: true);
    await _hostEventsSub?.cancel();
    _hostEventsSub = null;
    try {
      await _host?.dispose();
    } catch (_) {
      // Host dispose must not block teardown.
    }
    _host = null;
    _initialized = false;
    await _stateController.close();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('MediaKitPlaybackService 已释放。');
    }
  }

  void _onHostEvent(MediaKitHostEvent event) {
    if (_disposed || _stateController.isClosed) {
      return;
    }
    final PlaybackSnapshot next = MediaKitPlaybackHelpers.applyHostEvent(
      _snapshot,
      event,
    );
    _emit(next);
    if (event is MediaKitPositionEvent) {
      unawaited(_persistCurrentProgress(force: false));
    }
  }

  void _emit(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_stateController.isClosed) {
      _stateController.add(snapshot);
    }
  }

  DateTime _lastPersistAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _persistCurrentProgress({required bool force}) async {
    final VideoPreview? video = _currentVideo;
    final VideoPart? part = _currentPart;
    if (video == null || part == null) {
      return;
    }
    final DateTime now = DateTime.now();
    if (!force && now.difference(_lastPersistAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastPersistAt = now;
    await savePlaybackState(
      bvid: video.bvid,
      cid: part.cid,
      pageNumber: part.pageNumber,
      position: _snapshot.position,
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested without native Player)
// ---------------------------------------------------------------------------

/// Stateless helpers for media URI construction and snapshot mapping.
class MediaKitPlaybackHelpers {
  MediaKitPlaybackHelpers._();

  /// Prefs key for a bvid's last playback memory.
  static String savedStateKey(String bvid) {
    return '${MediaKitPlaybackService.savedStatePrefsPrefix}'
        '${bvid.trim().toUpperCase()}';
  }

  /// Builds mpv `edl://` multi-stream URI for separate DASH video + audio URLs.
  ///
  /// Pattern matches the minimal dual-open approach used by libmpv clients
  /// (length-prefixed segments + `!new_stream`). Not a copy of third-party
  /// application sources — only the documented EDL syntax.
  static String buildDashEdlUri({
    required String videoUrl,
    required String audioUrl,
  }) {
    final String video = videoUrl.trim();
    final String audio = audioUrl.trim();
    return 'edl://'
        '!no_clip;!no_chapters;'
        '%${video.length}%$video;'
        '!new_stream;!no_clip;!no_chapters;'
        '%${audio.length}%$audio';
  }

  /// Resource URI for [Media]: plain video URL, or EDL when [audioUrl] present.
  static String buildPlayableResource({
    required String videoUrl,
    String? audioUrl,
  }) {
    final String video = videoUrl.trim();
    final String? audio = audioUrl?.trim();
    if (audio == null || audio.isEmpty) {
      return video;
    }
    return buildDashEdlUri(videoUrl: video, audioUrl: audio);
  }

  /// Creates a [Media] with CDN headers and optional start offset.
  static Media buildMedia(
    PlayUrlManifest manifest, {
    Duration? start,
  }) {
    final String resource = buildPlayableResource(
      videoUrl: manifest.videoUrl,
      audioUrl: manifest.audioUrl,
    );
    final Map<String, String>? headers = manifest.httpHeaders.isEmpty
        ? null
        : Map<String, String>.from(manifest.httpHeaders);
    return Media(
      resource,
      httpHeaders: headers,
      start: start,
    );
  }

  /// JSON encode saved playback memory.
  static String encodeSavedState({
    required int cid,
    required int pageNumber,
    required Duration position,
  }) {
    return jsonEncode(<String, Object?>{
      'cid': cid,
      'pageNumber': pageNumber,
      'positionMs': position.inMilliseconds,
    });
  }

  /// JSON decode saved playback memory; invalid → null.
  static SavedPlaybackState? decodeSavedState(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Map<Object?, Object?> map = Map<Object?, Object?>.from(decoded);
      final SavedPlaybackState state = SavedPlaybackState(
        cid: (map['cid'] as num?)?.toInt() ?? 0,
        pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 0,
        position: Duration(
          milliseconds: (map['positionMs'] as num?)?.toInt() ?? 0,
        ),
      );
      if (state.cid <= 0 || state.pageNumber <= 0) {
        return null;
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  /// Maps host events onto the last snapshot (pure).
  static PlaybackSnapshot applyHostEvent(
    PlaybackSnapshot current,
    MediaKitHostEvent event,
  ) {
    switch (event) {
      case MediaKitPlayingEvent(:final bool playing):
        PlaybackPhase phase = current.phase;
        if (playing &&
            (phase == PlaybackPhase.loading || phase == PlaybackPhase.idle)) {
          phase = PlaybackPhase.ready;
        }
        if (playing && phase == PlaybackPhase.ended) {
          phase = PlaybackPhase.ready;
        }
        return current.copyWith(
          isPlaying: playing,
          phase: phase,
          clearMessage: phase != PlaybackPhase.error,
        );
      case MediaKitBufferingEvent(:final bool buffering):
        if (buffering &&
            current.phase != PlaybackPhase.error &&
            current.phase != PlaybackPhase.ended) {
          return current.copyWith(phase: PlaybackPhase.loading);
        }
        if (!buffering &&
            current.phase == PlaybackPhase.loading &&
            (current.isPlaying || current.duration > Duration.zero)) {
          return current.copyWith(phase: PlaybackPhase.ready);
        }
        return current;
      case MediaKitCompletedEvent(:final bool completed):
        if (completed) {
          return current.copyWith(
            phase: PlaybackPhase.ended,
            isPlaying: false,
          );
        }
        return current;
      case MediaKitPositionEvent(:final Duration position):
        return current.copyWith(position: position);
      case MediaKitDurationEvent(:final Duration duration):
        if (duration <= Duration.zero) {
          return current;
        }
        final PlaybackPhase phase =
            current.phase == PlaybackPhase.loading ||
                current.phase == PlaybackPhase.idle
            ? PlaybackPhase.ready
            : current.phase;
        return current.copyWith(duration: duration, phase: phase);
      case MediaKitRateEvent(:final double rate):
        return current.copyWith(speed: rate);
      case MediaKitSizeEvent(:final int? width, :final int? height):
        if (width == null ||
            height == null ||
            width <= 0 ||
            height <= 0) {
          return current;
        }
        return current.copyWith(
          videoAspectRatio: width / height,
        );
      case MediaKitErrorEvent(:final String message):
        final String trimmed = message.trim();
        if (trimmed.isEmpty) {
          return current;
        }
        return current.copyWith(
          phase: PlaybackPhase.error,
          isPlaying: false,
          message: trimmed,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Host abstraction (live media_kit vs test fake)
// ---------------------------------------------------------------------------

/// Events from the player host, mapped into [PlaybackSnapshot].
sealed class MediaKitHostEvent {
  const MediaKitHostEvent();
}

/// Playing / paused.
final class MediaKitPlayingEvent extends MediaKitHostEvent {
  const MediaKitPlayingEvent(this.playing);
  final bool playing;
}

/// Buffering flag.
final class MediaKitBufferingEvent extends MediaKitHostEvent {
  const MediaKitBufferingEvent(this.buffering);
  final bool buffering;
}

/// End of media.
final class MediaKitCompletedEvent extends MediaKitHostEvent {
  const MediaKitCompletedEvent(this.completed);
  final bool completed;
}

/// Playback position.
final class MediaKitPositionEvent extends MediaKitHostEvent {
  const MediaKitPositionEvent(this.position);
  final Duration position;
}

/// Media duration.
final class MediaKitDurationEvent extends MediaKitHostEvent {
  const MediaKitDurationEvent(this.duration);
  final Duration duration;
}

/// Playback rate.
final class MediaKitRateEvent extends MediaKitHostEvent {
  const MediaKitRateEvent(this.rate);
  final double rate;
}

/// Video pixel size (for aspect ratio).
final class MediaKitSizeEvent extends MediaKitHostEvent {
  const MediaKitSizeEvent({this.width, this.height});
  final int? width;
  final int? height;
}

/// Player error string.
final class MediaKitErrorEvent extends MediaKitHostEvent {
  const MediaKitErrorEvent(this.message);
  final String message;
}

/// Abstracts media_kit [Player] so unit tests can open video without libmpv.
abstract class MediaKitPlayerHost {
  /// Live factory: real [Player] + [VideoController].
  static MediaKitPlayerHost live() => _LiveMediaKitPlayerHost();

  /// Broadcast of mapped host events.
  Stream<MediaKitHostEvent> get events;

  /// Video controller for surface; null on fakes that do not render.
  VideoController? get videoController;

  /// Underlying player when live; null on fakes.
  Player? get player;

  Future<void> initialize();
  Future<void> openMedia(Media media, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// Production host wrapping media_kit [Player] / [VideoController].
class _LiveMediaKitPlayerHost implements MediaKitPlayerHost {
  Player? _player;
  VideoController? _videoController;
  final StreamController<MediaKitHostEvent> _events =
      StreamController<MediaKitHostEvent>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];

  @override
  Stream<MediaKitHostEvent> get events => _events.stream;

  @override
  VideoController? get videoController => _videoController;

  @override
  Player? get player => _player;

  @override
  Future<void> initialize() async {
    final Player player = Player(
      configuration: const PlayerConfiguration(
        title: 'FocuBili',
        ready: null,
      ),
    );
    _player = player;
    _videoController = VideoController(player);
    _subs.addAll(<StreamSubscription<dynamic>>[
      player.stream.playing.listen((bool v) {
        _events.add(MediaKitPlayingEvent(v));
      }),
      player.stream.buffering.listen((bool v) {
        _events.add(MediaKitBufferingEvent(v));
      }),
      player.stream.completed.listen((bool v) {
        _events.add(MediaKitCompletedEvent(v));
      }),
      player.stream.position.listen((Duration v) {
        _events.add(MediaKitPositionEvent(v));
      }),
      player.stream.duration.listen((Duration v) {
        _events.add(MediaKitDurationEvent(v));
      }),
      player.stream.rate.listen((double v) {
        _events.add(MediaKitRateEvent(v));
      }),
      player.stream.width.listen((int? w) {
        _events.add(
          MediaKitSizeEvent(width: w, height: player.state.height),
        );
      }),
      player.stream.height.listen((int? h) {
        _events.add(
          MediaKitSizeEvent(width: player.state.width, height: h),
        );
      }),
      player.stream.error.listen((String message) {
        if (message.trim().isNotEmpty) {
          _events.add(MediaKitErrorEvent(message));
        }
      }),
    ]);
  }

  @override
  Future<void> openMedia(Media media, {bool play = true}) async {
    final Player? player = _player;
    if (player == null) {
      throw StateError('Player 尚未 initialize。');
    }
    await player.open(media, play: play);
  }

  @override
  Future<void> play() => _player?.play() ?? Future<void>.value();

  @override
  Future<void> pause() => _player?.pause() ?? Future<void>.value();

  @override
  Future<void> seek(Duration position) =>
      _player?.seek(position) ?? Future<void>.value();

  @override
  Future<void> setRate(double rate) =>
      _player?.setRate(rate) ?? Future<void>.value();

  @override
  Future<void> setVolume(double volume) =>
      _player?.setVolume(volume) ?? Future<void>.value();

  @override
  Future<void> dispose() async {
    for (final StreamSubscription<dynamic> sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _player?.dispose();
    _player = null;
    _videoController = null;
    await _events.close();
  }
}

/// Test double: records opens and can push host events.
@visibleForTesting
class FakeMediaKitPlayerHost implements MediaKitPlayerHost {
  FakeMediaKitPlayerHost();

  final StreamController<MediaKitHostEvent> _events =
      StreamController<MediaKitHostEvent>.broadcast(sync: true);

  final List<Media> opened = <Media>[];
  final List<String> calls = <String>[];
  bool playOnOpen = true;
  bool failOpen = false;
  Object? openError;

  @override
  Stream<MediaKitHostEvent> get events => _events.stream;

  @override
  VideoController? get videoController => null;

  @override
  Player? get player => null;

  /// Push a synthetic host event into the service.
  void emit(MediaKitHostEvent event) => _events.add(event);

  @override
  Future<void> initialize() async {
    calls.add('initialize');
  }

  @override
  Future<void> openMedia(Media media, {bool play = true}) async {
    calls.add('open');
    opened.add(media);
    playOnOpen = play;
    if (failOpen) {
      throw openError ?? Exception('fake open failed');
    }
    // Simulate ready after open.
    emit(const MediaKitDurationEvent(Duration(minutes: 3)));
    emit(const MediaKitBufferingEvent(false));
    emit(MediaKitPlayingEvent(play));
    if (media.start != null && media.start! > Duration.zero) {
      emit(MediaKitPositionEvent(media.start!));
    }
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit(const MediaKitPlayingEvent(true));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(const MediaKitPlayingEvent(false));
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    emit(MediaKitPositionEvent(position));
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('setRate:$rate');
    emit(MediaKitRateEvent(rate));
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume:$volume');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await _events.close();
  }
}
