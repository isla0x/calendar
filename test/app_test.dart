
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/main.dart';
import 'package:yeobaek/models.dart';
import 'package:yeobaek/store.dart';
import 'package:yeobaek/theme.dart';
import 'package:yeobaek/ui/event_tile.dart';

void main() {
  // 2026-10-26 월요일 14:10
  final now = DateTime(2026, 10, 26, 14, 10);

  /// 아래 목록(EventTile)에 있는 일정 제목 (월간 달력 칸의 글자와 구분하려고)
  Finder tile(String title) =>
      find.descendant(of: find.byType(EventTile), matching: find.text(title));

  Future<CalendarStore> open(WidgetTester tester, {bool project = false}) async {
    useWebFont = false;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = CalendarStore(DemoRepo(clock: () => now, project: project), clock: () => now);
    await tester.pumpWidget(YeobaekApp(store: store, ticking: false));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('월간 화면이 열리고 날짜를 고르면 목록이 바뀌어요', (tester) async {
    final store = await open(tester);
    expect(find.text('10월'), findsOneWidget);
    expect(find.text('2026년'), findsOneWidget);
    expect(find.text('10월 26일 월요일'), findsOneWidget);
    expect(tile('스프린트 플래닝'), findsOneWidget);

    store.select(DateTime(2026, 10, 28));
    await tester.pumpAndSettle();
    expect(find.text('10월 28일 수요일'), findsOneWidget);
    expect(tile('스프린트 리뷰'), findsOneWidget);
  });

  testWidgets('월간 달력 칸에 일정 글자가 그대로 보여요', (tester) async {
    await open(tester);
    // 27일 일정은 아래 목록(26일)에는 없고, 달력 칸에만 글자로 보여요. (매주 있는 일정이라 여러 칸)
    expect(find.text('디자인 리뷰'), findsWidgets);
    expect(tile('디자인 리뷰'), findsNothing);
  });

  testWidgets('기간 일정은 주마다 이어진 띠로 보여요', (tester) async {
    await open(tester, project: true);
    expect(find.text('프로젝트 A'), findsWidgets);
    expect(tile('프로젝트 A'), findsOneWidget);
  });

  testWidgets('태그로 보기: 고른 태그 일정만 보여요', (tester) async {
    final store = await open(tester);
    expect(find.text('브런치'), findsWidgets);

    await tester.tap(find.byIcon(Icons.tag_rounded));
    await tester.pumpAndSettle();
    expect(find.text('태그로 보기'), findsOneWidget);
    await tester.tap(find.text('#회의'));
    await tester.pumpAndSettle();

    expect(store.tagFilter, '회의');
    expect(find.text('이 태그의 일정만 보는 중'), findsOneWidget);
    expect(find.text('브런치'), findsNothing);
    expect(find.text('주간 싱크'), findsWidgets);

    // 필터 줄의 태그를 누르면 전체 보기로 돌아가요.
    await tester.tap(find.text('#회의'));
    await tester.pumpAndSettle();
    expect(store.tagFilter, isNull);
    expect(find.text('브런치'), findsWidgets);
  });

  testWidgets('월간 목록을 위로 끌면 화면 가득 펼쳐져요', (tester) async {
    await open(tester);
    final before = tester.getTopLeft(find.text('10월 26일 월요일')).dy;
    await tester.drag(find.text('10월 26일 월요일'), const Offset(0, -520));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('10월 26일 월요일')).dy;
    expect(after, lessThan(before - 200));
    // 모든 일정이 목록에 보여요.
    expect(tile('러닝'), findsOneWidget);
    expect(tile('영어 공부'), findsOneWidget);
  });

  testWidgets('옆으로 넘기는 버튼으로 달을 바꿔요', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('11월'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('9월'), findsOneWidget);
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

  testWidgets('한 줄 입력: 기간(9/18~10/28)과 #태그', (tester) async {
    final store = await open(tester);
    await tester.tap(find.text('한 줄로 추가 · 예) 내일 3시 치과'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '9/18~10/28 프로젝트 #일');
    await tester.pumpAndSettle();
    expect(find.text('9월 18일 ~ 10월 28일'), findsOneWidget);
    expect(find.text('9월 18일 – 10월 28일'), findsOneWidget);
    expect(find.text('41일 동안'), findsWidgets);
    expect(find.text('#일'), findsOneWidget);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    List<Ev> on(DateTime d) => store.eventsOn(d).where((e) => e.title == '프로젝트').toList();
    expect(on(DateTime(2026, 9, 17)), isEmpty);
    expect(on(DateTime(2026, 9, 18)).length, 1);
    expect(on(DateTime(2026, 10, 1)).length, 1);
    expect(on(DateTime(2026, 10, 28)).length, 1);
    expect(on(DateTime(2026, 10, 29)), isEmpty);
    final e = on(DateTime(2026, 10, 1)).first;
    expect(e.allDay, true);
    expect(e.tags, ['일']);
  });

  testWidgets('일정을 누르면 상세 화면이 열려요', (tester) async {
    final store = await open(tester);
    // 월간 아래 목록은 입력 바에 가려질 수 있어서, 일간 화면에서 눌러요.
    store.setView(ViewMode.day);
    await tester.pumpAndSettle();
    await tester.tap(find.text('스프린트 플래닝'));
    await tester.pumpAndSettle();
    expect(find.text('공유하기'), findsOneWidget);
    expect(find.text('#회의'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    expect(find.textContaining('겹치지 않는 시간으로 옮기기'), findsOneWidget);
  });

  testWidgets('일정 편집 화면에서 제목·태그·색을 고쳐요', (tester) async {
    final store = await open(tester);
    store.setView(ViewMode.day);
    await tester.pumpAndSettle();
    await tester.tap(find.text('스프린트 플래닝'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집').first);
    await tester.pumpAndSettle();
    expect(find.text('일정 편집'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);
    expect(find.text('종일'), findsOneWidget);

    // 제목 고치기
    await tester.enterText(find.byType(TextField).first, '스프린트 회고');
    await tester.pumpAndSettle();

    // 태그 창에서 태그 하나 더 붙이기
    await tester.tap(find.text('#회의'));
    await tester.pumpAndSettle();
    expect(find.text('붙인 태그'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '회고');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(find.text('#회고'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('일정 편집'), findsNothing);
    final e = store.eventsOn(DateTime(2026, 10, 26)).firstWhere((x) => x.title == '스프린트 회고');
    expect(e.tags, ['회의', '회고']);
  });

  testWidgets('일정마다 색을 따로 정해요', (tester) async {
    final store = await open(tester);
    final e = store.eventsOn(DateTime(2026, 10, 26)).first;
    await store.setEventColor(e, const Color(0xFFF3A98C));
    final again = store.eventsOn(DateTime(2026, 10, 26)).firstWhere((x) => x.id == e.id);
    expect(again.color, const Color(0xFFF3A98C));
    await store.setEventColor(e, null);
    final back = store.eventsOn(DateTime(2026, 10, 26)).firstWhere((x) => x.id == e.id);
    expect(back.color, isNot(const Color(0xFFF3A98C)));
  });

  testWidgets('새 일정을 만들 때 고른 색이 그대로 붙어요', (tester) async {
    final store = await open(tester);
    final ok = await store.addEvent(
      title: '색 테스트',
      start: DateTime(2026, 10, 27, 9),
      end: DateTime(2026, 10, 27, 10),
      color: const Color(0xFFB4D88A),
    );
    expect(ok, true);
    final e = store.eventsOn(DateTime(2026, 10, 27)).firstWhere((x) => x.title == '색 테스트');
    expect(e.color, const Color(0xFFB4D88A));
  });

  testWidgets('빠른 추가 시간 바를 끌면 시간이 바뀌어요', (tester) async {
    await open(tester);
    await tester.tap(find.text('한 줄로 추가 · 예) 내일 3시 치과'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '내일 오전 10시 1시간 드래그');
    await tester.pumpAndSettle();
    expect(find.text('오전 10:00–11:00'), findsOneWidget);

    // 바(칠한 칸)의 가운데를 오른쪽으로 끌면 통째로 늦어져요.
    final label = find.text('드래그 10:00');
    expect(label, findsOneWidget);
    final c = tester.getCenter(label);
    await tester.dragFrom(Offset(c.dx, c.dy + 45), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('오전 10:00–11:00'), findsNothing);
    expect(find.textContaining('드래그 1'), findsOneWidget);
    // 여러 번 끌어도 글에 쉼표가 쌓이지 않아요.
    await tester.dragFrom(Offset(c.dx + 120, c.dy + 45), const Offset(-60, 0));
    await tester.pumpAndSettle();
    final txt = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(RegExp(r',\s*,').hasMatch(txt), false, reason: txt);
    expect(txt.contains('드래그'), true);
  });

  testWidgets('반복 일정은 이 일정만 / 이후 모두 / 전체로 지워요', (tester) async {
    final store = await open(tester);
    await store.addEvent(
      title: '매일 일정',
      start: DateTime(2026, 10, 27, 9),
      end: DateTime(2026, 10, 27, 10),
      repeat: Repeat(RepeatKind.daily, until: DateTime(2026, 10, 30)),
    );
    List<Ev> mine() => [
          for (var d = 27; d <= 30; d++)
            ...store.eventsOn(DateTime(2026, 10, d)).where((e) => e.title == '매일 일정'),
        ];
    expect(mine().length, 4);
    await store.deleteEvent(mine()[1], scope: DeleteScope.one);
    expect(mine().length, 3);
    await store.deleteEvent(mine()[1], scope: DeleteScope.following);
    expect(mine().length, 1);
    await store.deleteEvent(mine()[0], scope: DeleteScope.all);
    expect(mine().length, 0);
  });

  testWidgets('매일 반복 일정은 달력에서 이어진 한 줄로 그려져요', (tester) async {
    final store = await open(tester);
    await store.addEvent(
      title: '이어짐',
      start: DateTime(2026, 10, 27, 9),
      end: DateTime(2026, 10, 27, 18),
      repeat: Repeat(RepeatKind.daily, until: DateTime(2026, 10, 30)),
    );
    await tester.pumpAndSettle();
    // 27~30일이 한 줄이라 달력 칸 글자는 하나만 있어요. (아래 목록에는 선택한 날 것만)
    final inGrid = find.byWidgetPredicate(
      (w) => w is Text && w.data == '이어짐' && (w.style?.fontSize ?? 0) == 10,
    );
    expect(inGrid, findsOneWidget);
  });

  testWidgets('달력을 옆으로 밀면 다음 달 / 이전 달로 넘어가요', (tester) async {
    final store = await open(tester);
    expect(store.month, DateTime(2026, 10));
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(store.month, DateTime(2026, 11));
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(store.month, DateTime(2026, 10));
    // 버튼으로 넘겨도 페이지가 따라가요.
    store.shiftMonth(1);
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(store.month, DateTime(2026, 11));
  });

  testWidgets('주간·일간 화면도 옆으로 밀어서 넘겨요', (tester) async {
    final store = await open(tester);
    expect(find.byTooltip('다음 달'), findsNothing);
    store.setView(ViewMode.week);
    await tester.pumpAndSettle();
    final w0 = store.selected;
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(store.selected, w0.add(const Duration(days: 7)));
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(store.selected, w0);

    store.setView(ViewMode.day);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(store.selected, w0.add(const Duration(days: 1)));
    store.shiftDay(-1);
    await tester.pumpAndSettle();
    expect(store.selected, w0);
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
