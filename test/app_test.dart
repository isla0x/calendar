
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/main.dart';
import 'package:yeobaek/store.dart';
import 'package:yeobaek/theme.dart';

void main() {
  // 2026-10-26 월요일 14:10
  final now = DateTime(2026, 10, 26, 14, 10);

  Future<CalendarStore> open(WidgetTester tester) async {
    useWebFont = false;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = CalendarStore(DemoRepo(clock: () => now), clock: () => now);
    await tester.pumpWidget(YeobaekApp(store: store, ticking: false));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('월간 화면이 열리고 날짜를 고르면 목록이 바뀌어요', (tester) async {
    final store = await open(tester);
    expect(find.text('10월'), findsOneWidget);
    expect(find.text('2026년'), findsOneWidget);
    expect(find.text('10월 26일 월요일'), findsOneWidget);
    expect(find.text('스프린트 플래닝'), findsOneWidget);

    store.select(DateTime(2026, 10, 28));
    await tester.pumpAndSettle();
    expect(find.text('10월 28일 수요일'), findsOneWidget);
    expect(find.text('스프린트 리뷰'), findsOneWidget);
  });

  testWidgets('일간 화면: 남은 여유 3시간 50분', (tester) async {
    final store = await open(tester);
    store.setView(ViewMode.day);
    await tester.pumpAndSettle();
    expect(find.text('오늘 남은 여유'), findsOneWidget);
    expect(find.text('3시간 50분'), findsOneWidget);
    expect(find.text('스프린트 플래닝'), findsOneWidget);
    expect(find.text('20분 후'), findsOneWidget);
    expect(find.text('지난 일정 2개'), findsOneWidget);

    await tester.tap(find.text('지난 일정 2개'));
    await tester.pumpAndSettle();
    expect(find.text('지난 일정 접기'), findsOneWidget);
    expect(find.text('주간 싱크'), findsOneWidget);
  });

  testWidgets('주간 화면', (tester) async {
    final store = await open(tester);
    store.setView(ViewMode.week);
    await tester.pumpAndSettle();
    expect(find.text('25일 – 31일'), findsOneWidget);
    expect(find.text('가장 여유로운 날'), findsOneWidget);
    expect(find.text('가장 바쁜 날'), findsOneWidget);
    expect(find.text('남은 여유 3시간 50분'), findsOneWidget);
  });

  testWidgets('한 줄 입력으로 일정을 추가해요', (tester) async {
    final store = await open(tester);
    await tester.tap(find.text('한 줄로 추가 · 예) 내일 3시 치과'));
    await tester.pumpAndSettle();
    expect(find.text('새 일정'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '내일 오후 3시 치과 30분');
    await tester.pumpAndSettle();
    expect(find.text('10월 27일 화'), findsOneWidget);
    expect(find.text('오후 3:00–3:30'), findsOneWidget);
    expect(find.text('치과 15:00'), findsOneWidget);
    expect(find.text('겹치는 일정 없음'), findsOneWidget);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('새 일정'), findsNothing);
    final added = store.eventsOn(DateTime(2026, 10, 27)).where((e) => e.title == '치과');
    expect(added.length, 1);
    expect(added.first.start, DateTime(2026, 10, 27, 15));
    expect(added.first.end, DateTime(2026, 10, 27, 15, 30));
  });

  testWidgets('일정을 누르면 상세 화면이 열려요', (tester) async {
    await open(tester);
    await tester.tap(find.text('스프린트 플래닝'));
    await tester.pumpAndSettle();
    expect(find.text('공유하기'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    expect(find.textContaining('겹치지 않는 시간으로 옮기기'), findsOneWidget);
  });

  testWidgets('다크 모드에서도 그려져요', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = await open(tester);
    store.setView(ViewMode.day);
    await tester.pumpAndSettle();
    expect(find.text('오늘 남은 여유'), findsOneWidget);
  });
}
