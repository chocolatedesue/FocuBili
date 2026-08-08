import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playback_contracts.dart';

/// SharedPreferences 键：完整 Cookie 请求头值（不含 `Cookie:` 前缀）。
///
/// 供桌面粘贴登录与 [PrefsCookieHeaderProvider] 读写；勿写入日志。
@visibleForTesting
const String kFocubiliBiliCookieHeaderPrefsKey = 'focubili_bili_cookie_header';

/// Android WebView Cookie 所在 MethodChannel（与 [BilibiliCookieController] 一致）。
const String _kAuthChannelName = 'com.focubili.app/auth';

/// 内存中的 Cookie 头，供单测与无需持久化的场景使用。
class MemoryCookieHeaderProvider implements CookieHeaderProvider {
  /// 创建可选初始 Cookie 的内存实现。
  MemoryCookieHeaderProvider([this._cookieHeader = '']);

  String _cookieHeader;

  @override
  Future<String> readCookieHeader() async => _cookieHeader;

  @override
  Future<void> replaceCookies(String cookieHeader) async {
    _cookieHeader = cookieHeader.trim();
  }

  @override
  Future<void> clear() async {
    _cookieHeader = '';
  }
}

/// 用 [SharedPreferences] 持久化 Cookie 头字符串（桌面粘贴登录最小集）。
///
/// 不解析、不校验 SESSDATA；调用方负责粘贴合法会话。值仅存本机，不上传。
class PrefsCookieHeaderProvider implements CookieHeaderProvider {
  /// 创建使用默认 prefs 键的实现。
  const PrefsCookieHeaderProvider({
    this.prefsKey = kFocubiliBiliCookieHeaderPrefsKey,
  });

  /// 存储 Cookie 头的 prefs 键。
  final String prefsKey;

  @override
  Future<String> readCookieHeader() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(prefsKey)?.trim() ?? '';
  }

  @override
  Future<void> replaceCookies(String cookieHeader) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String trimmed = cookieHeader.trim();
    if (trimmed.isEmpty) {
      await preferences.remove(prefsKey);
      return;
    }
    await preferences.setString(prefsKey, trimmed);
  }

  @override
  Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(prefsKey);
  }
}

/// 通过现有 auth MethodChannel 读写 Android WebView 中的 B 站 Cookie。
///
/// 通道名与方法与 `BilibiliCookieController` / `PlatformBilibiliCookieStore` 对齐，
/// 本类不修改 auth 服务文件，仅在本模块内包装通道。
///
/// 方法：
/// - `readCookies` → Cookie 头字符串
/// - `replaceCookies` / 参数 `cookie`
/// - `clearBilibiliCookies`
class ChannelCookieHeaderProvider implements CookieHeaderProvider {
  /// 创建可注入 [MethodChannel] 的实现（测试可替换 handler）。
  const ChannelCookieHeaderProvider({
    MethodChannel channel = const MethodChannel(_kAuthChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<String> readCookieHeader() async {
    final String? cookie = await _channel.invokeMethod<String>('readCookies');
    return cookie?.trim() ?? '';
  }

  @override
  Future<void> replaceCookies(String cookieHeader) {
    return _channel.invokeMethod<void>('replaceCookies', <String, Object?>{
      'cookie': cookieHeader,
    });
  }

  @override
  Future<void> clear() {
    return _channel.invokeMethod<void>('clearBilibiliCookies');
  }
}

/// 按平台创建默认 [CookieHeaderProvider]。
///
/// | 平台 | 实现 | 说明 |
/// |------|------|------|
/// | Android | [ChannelCookieHeaderProvider] | WebView 会话与登录页共享 |
/// | Windows / macOS / Linux | [PrefsCookieHeaderProvider] | 桌面粘贴 Cookie |
/// | 其他 / Web | [PrefsCookieHeaderProvider] | 回退 prefs |
///
/// **WIRE 后续：** 若桌面登录改为统一 auth 桥，可在此切换实现；
/// Android 已直接走 channel，无需再 TODO 接 prefs。
CookieHeaderProvider createCookieHeaderProvider() {
  if (!kIsWeb && Platform.isAndroid) {
    return const ChannelCookieHeaderProvider();
  }
  // io desktop (windows/macos/linux) 与其余平台：prefs 粘贴登录。
  return const PrefsCookieHeaderProvider();
}
