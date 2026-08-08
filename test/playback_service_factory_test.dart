import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:focubili/services/media_kit_playback_service.dart';
import 'package:focubili/services/native_playback_service.dart';
import 'package:focubili/services/playback_contracts.dart';
import 'package:focubili/services/playback_service_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('createPlaybackService returns platform-appropriate backend', () {
    final PlaybackService service = createPlaybackService();
    addTearDown(service.dispose);

    final bool desktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (desktop) {
      // VM / Linux CI and desktop hosts default to media_kit.
      expect(service, isA<MediaKitPlaybackService>());
    } else {
      expect(service, isA<NativePlaybackService>());
    }
  });

  test('PlayUrlManifest holds DASH fields used by later waves', () {
    const PlayUrlManifest manifest = PlayUrlManifest(
      videoUrl: 'https://example.com/v.m4s',
      audioUrl: 'https://example.com/a.m4s',
      quality: 64,
      qualities: <PlaybackQuality>[
        PlaybackQuality(id: 64, label: '720P'),
        PlaybackQuality(id: 80, label: '1080P'),
      ],
      httpHeaders: <String, String>{
        'Referer': 'https://www.bilibili.com',
        'User-Agent': 'test',
      },
    );

    expect(manifest.videoUrl, contains('v.m4s'));
    expect(manifest.audioUrl, contains('a.m4s'));
    expect(manifest.quality, 64);
    expect(manifest.qualities.map((PlaybackQuality q) => q.id), <int>[64, 80]);
    expect(manifest.httpHeaders['Referer'], isNotEmpty);
  });
}
