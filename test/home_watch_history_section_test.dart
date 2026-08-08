import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focubili/core/layout/adaptive_layout.dart';
import 'package:focubili/core/router/app_router.dart';
import 'package:focubili/features/focus/focus_timer_controller.dart';
import 'package:focubili/features/focus/focus_timer_scope.dart';
import 'package:focubili/features/home/home_page.dart';
import 'package:focubili/features/home/home_watch_history_section.dart';
import 'package:focubili/models/watch_history_entry.dart';
import 'package:focubili/services/watch_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  WatchHistoryEntry entry({
    required String bvid,
    String title = '标题',
  }) {
    return WatchHistoryEntry(
      bvid: bvid,
      title: title,
      ownerName: 'UP',
      lastPartTitle: 'P1',
      lastPartPageNumber: 1,
      watchedAt: DateTime(2026, 8, 1, 12),
      thumbnailUrl: '',
      lastPosition: const Duration(minutes: 3, seconds: 20),
    );
  }

  test('adaptive layout breakpoint helpers', () {
    expect(AdaptiveLayout.showHomeWatchHistory(899), isFalse);
    expect(AdaptiveLayout.showHomeWatchHistory(900), isTrue);
    expect(AdaptiveLayout.homeWatchHistoryColumnCount(900), 3);
    expect(AdaptiveLayout.homeWatchHistoryColumnCount(1300), 4);
  });

  void setViewSize(WidgetTester tester, Size logical) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logical;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('section shows empty state when no history', (
    WidgetTester tester,
  ) async {
    setViewSize(tester, const Size(1100, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeWatchHistorySection(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-watch-history-section')), findsOneWidget);
    expect(find.byKey(const Key('home-watch-history-empty')), findsOneWidget);
  });

  testWidgets('section shows grid cards for recorded history', (
    WidgetTester tester,
  ) async {
    setViewSize(tester, const Size(1100, 900));

    final WatchHistoryService service = WatchHistoryService();
    await service.record(entry(bvid: 'BV1xx411c7mD', title: 'Flutter 入门'));
    await service.record(entry(bvid: 'BV1yy411c7mE', title: 'Dart 基础'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeWatchHistorySection(historyService: service),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-watch-history-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('watch-history-grid-BV1xx411c7mD')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('watch-history-grid-BV1yy411c7mE')),
      findsOneWidget,
    );
    expect(find.text('Flutter 入门'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home page shows history section only on wide layout', (
    WidgetTester tester,
  ) async {
    final WatchHistoryService service = WatchHistoryService();
    await service.record(entry(bvid: 'BV1xx411c7mD', title: '宽屏历史条目'));

    Future<void> pumpAt(Size size) async {
      setViewSize(tester, size);
      final FocusTimerController controller = FocusTimerController(
        tickInterval: const Duration(days: 1),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: FocusTimerScope(
            controller: controller,
            child: HomePage(
              onSearchRequested: () {},
              onProfileRequested: () {},
              watchHistoryService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAt(const Size(390, 844));
    expect(find.byKey(const Key('home-watch-history-section')), findsNothing);

    await pumpAt(const Size(1100, 900));
    // 历史区在 focus 卡片下方，先滚到底再断言。
    final Finder scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-watch-history-section')), findsOneWidget);
    expect(find.text('宽屏历史条目'), findsOneWidget);
  });
}
