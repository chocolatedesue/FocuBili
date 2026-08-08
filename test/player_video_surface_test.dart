import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focubili/features/player/player_video_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native path builds Texture when textureId is set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: PlayerVideoSurface(textureId: 42),
          ),
        ),
      ),
    );

    expect(find.byType(Texture), findsOneWidget);
    final Texture texture = tester.widget<Texture>(find.byType(Texture));
    expect(texture.textureId, 42);
    expect(
      find.descendant(
        of: find.byType(PlayerVideoSurface),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });

  testWidgets('empty slot expands when neither texture nor controller', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: PlayerVideoSurface(),
          ),
        ),
      ),
    );

    expect(find.byType(Texture), findsNothing);
    final Size size = tester.getSize(find.byType(PlayerVideoSurface));
    expect(size.width, 200);
    expect(size.height, 100);
    expect(
      find.descendant(
        of: find.byType(PlayerVideoSurface),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });

  testWidgets('unknown controller object shows dark placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: PlayerVideoSurface(videoController: Object()),
          ),
        ),
      ),
    );

    expect(find.byType(Texture), findsNothing);
    final Finder placeholder = find.descendant(
      of: find.byType(PlayerVideoSurface),
      matching: find.byType(ColoredBox),
    );
    expect(placeholder, findsOneWidget);
    final ColoredBox box = tester.widget<ColoredBox>(placeholder);
    expect(box.color, const Color(0xFF000000));
  });

  testWidgets('textureId wins over videoController when both set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: PlayerVideoSurface(
              textureId: 7,
              videoController: Object(),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Texture), findsOneWidget);
    expect(tester.widget<Texture>(find.byType(Texture)).textureId, 7);
    expect(
      find.descendant(
        of: find.byType(PlayerVideoSurface),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });
}
