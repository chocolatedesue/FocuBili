import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focubili/features/player/player_keyboard_intents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('playerDesktopShortcutBindings', () {
    test('maps common desktop keys to player intents', () {
      final Map<ShortcutActivator, Intent> map = playerDesktopShortcutBindings();

      Intent? intentFor(LogicalKeyboardKey key, {bool shift = false}) {
        for (final MapEntry<ShortcutActivator, Intent> entry in map.entries) {
          final ShortcutActivator activator = entry.key;
          if (activator is! SingleActivator) {
            continue;
          }
          if (activator.trigger == key &&
              activator.shift == shift &&
              !activator.control &&
              !activator.alt &&
              !activator.meta) {
            return entry.value;
          }
        }
        return null;
      }

      expect(intentFor(LogicalKeyboardKey.space), isA<PlayerTogglePlayIntent>());
      expect(intentFor(LogicalKeyboardKey.escape), isA<PlayerBackIntent>());
      expect(
        intentFor(LogicalKeyboardKey.arrowLeft),
        isA<PlayerSeekBackwardIntent>(),
      );
      expect(
        intentFor(LogicalKeyboardKey.arrowRight),
        isA<PlayerSeekForwardIntent>(),
      );
      expect(
        (intentFor(LogicalKeyboardKey.arrowLeft) as PlayerSeekBackwardIntent)
            .seconds,
        5,
      );
      expect(
        (intentFor(LogicalKeyboardKey.arrowLeft, shift: true)
                as PlayerSeekBackwardIntent)
            .seconds,
        10,
      );
      expect(intentFor(LogicalKeyboardKey.arrowUp), isA<PlayerVolumeUpIntent>());
      expect(
        intentFor(LogicalKeyboardKey.arrowDown),
        isA<PlayerVolumeDownIntent>(),
      );
      expect(intentFor(LogicalKeyboardKey.keyF), isA<PlayerToggleFullscreenIntent>());
      expect(intentFor(LogicalKeyboardKey.f11), isA<PlayerToggleFullscreenIntent>());
      expect(intentFor(LogicalKeyboardKey.keyM), isA<PlayerToggleMuteIntent>());
      expect(intentFor(LogicalKeyboardKey.keyC), isA<PlayerToggleControlsIntent>());
    });
  });

  group('playerShortcutShouldIgnoreForFocus', () {
    testWidgets('returns true when EditableText holds focus', (
      WidgetTester tester,
    ) async {
      final FocusNode fieldFocus = FocusNode();
      addTearDown(fieldFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(focusNode: fieldFocus),
          ),
        ),
      );
      fieldFocus.requestFocus();
      await tester.pump();

      expect(playerShortcutShouldIgnoreForFocus(fieldFocus), isTrue);
    });

    testWidgets('returns false for plain focus without text field', (
      WidgetTester tester,
    ) async {
      final FocusNode plain = FocusNode();
      addTearDown(plain.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(focusNode: plain, child: const SizedBox()),
          ),
        ),
      );
      plain.requestFocus();
      await tester.pump();

      expect(playerShortcutShouldIgnoreForFocus(plain), isFalse);
    });
  });

  testWidgets('Shortcuts deliver space to toggle-play action', (
    WidgetTester tester,
  ) async {
    int toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Shortcuts(
          shortcuts: playerDesktopShortcutBindings(),
          child: Actions(
            actions: <Type, Action<Intent>>{
              PlayerTogglePlayIntent: CallbackAction<PlayerTogglePlayIntent>(
                onInvoke: (PlayerTogglePlayIntent intent) {
                  toggles += 1;
                  return null;
                },
              ),
            },
            child: const Focus(
              autofocus: true,
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(toggles, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    // No back action registered in this harness — toggle count unchanged.
    expect(toggles, 1);
  });
}
