import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focubili/services/bilibili_auth_service.dart';
import 'package:focubili/services/cookie_header_provider.dart';
import 'package:focubili/services/playback_contracts.dart';

/// 验证 Cookie 头提供方的读写、清除与工厂行为。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryCookieHeaderProvider', () {
    test('读写与清除', () async {
      final MemoryCookieHeaderProvider provider = MemoryCookieHeaderProvider();
      expect(await provider.readCookieHeader(), isEmpty);

      await provider.replaceCookies('SESSDATA=abc; bili_jct=xyz');
      expect(await provider.readCookieHeader(), 'SESSDATA=abc; bili_jct=xyz');

      await provider.clear();
      expect(await provider.readCookieHeader(), isEmpty);
    });

    test('构造时可带初始值；replace 会 trim', () async {
      final MemoryCookieHeaderProvider provider =
          MemoryCookieHeaderProvider('  SESSDATA=init  ');
      expect(await provider.readCookieHeader(), '  SESSDATA=init  ');

      await provider.replaceCookies('  SESSDATA=next  ');
      expect(await provider.readCookieHeader(), 'SESSDATA=next');
    });
  });

  group('PrefsCookieHeaderProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('空 prefs 读到空串', () async {
      const PrefsCookieHeaderProvider provider = PrefsCookieHeaderProvider();
      expect(await provider.readCookieHeader(), isEmpty);
    });

    test('replace 后可读；clear 后为空', () async {
      const PrefsCookieHeaderProvider provider = PrefsCookieHeaderProvider();
      const String cookie = 'SESSDATA=desktop_session; DedeUserID=1';

      await provider.replaceCookies(cookie);
      expect(await provider.readCookieHeader(), cookie);

      // 二次读取仍来自 prefs 持久化。
      const PrefsCookieHeaderProvider again = PrefsCookieHeaderProvider();
      expect(await again.readCookieHeader(), cookie);

      await provider.clear();
      expect(await provider.readCookieHeader(), isEmpty);
      expect(await again.readCookieHeader(), isEmpty);
    });

    test('replace 空串等同于 clear', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kFocubiliBiliCookieHeaderPrefsKey: 'SESSDATA=stale',
      });
      const PrefsCookieHeaderProvider provider = PrefsCookieHeaderProvider();

      await provider.replaceCookies('   ');
      expect(await provider.readCookieHeader(), isEmpty);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kFocubiliBiliCookieHeaderPrefsKey), isFalse);
    });

    test('读取时 trim 已存值', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kFocubiliBiliCookieHeaderPrefsKey: '  SESSDATA=padded  ',
      });
      const PrefsCookieHeaderProvider provider = PrefsCookieHeaderProvider();
      expect(await provider.readCookieHeader(), 'SESSDATA=padded');
    });
  });

  group('ChannelCookieHeaderProvider', () {
    const MethodChannel channel = MethodChannel('com.focubili.app/auth');
    late Map<String, Object?> store;
    late List<MethodCall> calls;

    setUp(() {
      store = <String, Object?>{};
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'readCookies':
            return store['cookie'] as String? ?? '';
          case 'replaceCookies':
            final Object? args = call.arguments;
            final String cookie = args is Map
                ? (args['cookie'] as String? ?? '')
                : '';
            store['cookie'] = cookie;
            return null;
          case 'clearBilibiliCookies':
            store.remove('cookie');
            return null;
          default:
            fail('unexpected method: ${call.method}');
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('读写与清除走 auth channel', () async {
      const ChannelCookieHeaderProvider provider =
          ChannelCookieHeaderProvider();

      expect(await provider.readCookieHeader(), isEmpty);
      expect(calls.last.method, 'readCookies');

      await provider.replaceCookies('SESSDATA=android');
      expect(calls.last.method, 'replaceCookies');
      expect(
        (calls.last.arguments as Map)['cookie'],
        'SESSDATA=android',
      );
      expect(await provider.readCookieHeader(), 'SESSDATA=android');

      await provider.clear();
      expect(calls.last.method, 'clearBilibiliCookies');
      expect(await provider.readCookieHeader(), isEmpty);
    });
  });

  group('createCookieHeaderProvider', () {
    test('返回实现 CookieHeaderProvider 的实例', () {
      final CookieHeaderProvider provider = createCookieHeaderProvider();
      expect(provider, isA<CookieHeaderProvider>());
      // 本测试宿主一般为 Linux/桌面 → Prefs；Android 设备上为 Channel。
      // 不硬编码平台，只保证工厂可调用且类型正确。
      expect(
        provider is PrefsCookieHeaderProvider ||
            provider is ChannelCookieHeaderProvider,
        isTrue,
      );
    });
  });

  group('PrefsBilibiliCookieStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('默认键与 PrefsCookieHeaderProvider 相同且互通', () async {
      const PrefsBilibiliCookieStore store = PrefsBilibiliCookieStore();
      const PrefsCookieHeaderProvider provider = PrefsCookieHeaderProvider();
      const String cookie = 'SESSDATA=shared_desktop; DedeUserID=9';

      expect(store.prefsKey, kFocubiliBiliCookieHeaderPrefsKey);
      expect(provider.prefsKey, kFocuBiliSameKeyAsStore(store));

      await store.replaceCookies(cookie);
      expect(await provider.readCookieHeader(), cookie);
      expect(await store.readCookies(), cookie);

      await provider.clear();
      expect(await store.readCookies(), isEmpty);
    });

    test('clearBilibiliCookies 清空 prefs', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kFocubiliBiliCookieHeaderPrefsKey: 'SESSDATA=stale',
      });
      const PrefsBilibiliCookieStore store = PrefsBilibiliCookieStore();
      await store.clearBilibiliCookies();
      expect(await store.readCookies(), isEmpty);
    });
  });

  group('createDefaultBilibiliCookieStore', () {
    test('返回实现 BilibiliCookieStore 的实例', () {
      final BilibiliCookieStore store = createDefaultBilibiliCookieStore();
      expect(store, isA<BilibiliCookieStore>());
      // VM / Linux CI → Prefs；Android 设备 → Platform。
      expect(
        store is PrefsBilibiliCookieStore ||
            store is PlatformBilibiliCookieStore,
        isTrue,
      );
    });

    test('桌面默认 Auth 与播放 Cookie 提供方共用 prefs 键', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final BilibiliCookieStore store = createDefaultBilibiliCookieStore();
      final CookieHeaderProvider provider = createCookieHeaderProvider();
      // 本机 CI 为桌面时两侧皆 prefs；若为 Android 则跳过键互通断言。
      if (store is! PrefsBilibiliCookieStore ||
          provider is! PrefsCookieHeaderProvider) {
        return;
      }
      const String cookie = 'SESSDATA=auth_playback_bridge';
      await store.replaceCookies(cookie);
      expect(await provider.readCookieHeader(), cookie);
      expect(store.prefsKey, provider.prefsKey);
      expect(store.prefsKey, kFocubiliBiliCookieHeaderPrefsKey);
    });
  });
}

/// 测试辅助：与 store 对齐的 prefs 键（避免魔法字符串漂移）。
String kFocuBiliSameKeyAsStore(PrefsBilibiliCookieStore store) => store.prefsKey;
