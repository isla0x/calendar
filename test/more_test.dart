import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yeobaek/backup.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/flags.dart';
import 'package:yeobaek/main.dart';
import 'package:yeobaek/pro.dart';
import 'package:yeobaek/store.dart';
import 'package:yeobaek/theme.dart';
import 'package:yeobaek/todos.dart';
import 'package:yeobaek/travel.dart';

void main() {
  final now = DateTime(2026, 10, 26, 14, 10);

  Future<CalendarStore> open(
    WidgetTester tester, {
    AppFlags? flags,
    ProState? pro,
    TravelBook? travel,
  }) async {
    useWebFont = false;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = CalendarStore(
      DemoRepo(clock: () => now),
      clock: () => now,
      flags: flags,
      pro: pro,
      travel: travel,
    );
    await tester.pumpWidget(YeobaekApp(store: store, ticking: false));
    await tester.pumpAndSettle();
    return store;
  }

  group('백업', () {
    test('내보낸 글자를 그대로 가져오면 같은 값이 돌아와요', () async {
      SharedPreferences.setMockInitialValues({
        'projects_v1': '[{"id":"p1"}]',
        'todos_v1': '[{"id":"t1"},{"id":"t2"}]',
        'event_travel_v1': '{"e1":[10,10]}',
        'other_key': 'x',
      });
      final prefs = await SharedPreferences.getInstance();
      final text = await Backup.export(prefs, now: now);
      expect(text.contains('other_key'), false);

      SharedPreferences.setMockInitialValues({});
      final fresh = await SharedPreferences.getInstance();
      final sum = await Backup.import(fresh, text);
      expect(sum, isNotNull);
      expect(sum!.projects, 1);
      expect(sum.todos, 2);
      expect(sum.travel, 1);
      expect(fresh.getString('todos_v1'), '[{"id":"t1"},{"id":"t2"}]');
    });

    test('여백 백업이 아니면 아무것도 바꾸지 않아요', () async {
      SharedPreferences.setMockInitialValues({'todos_v1': '[{"id":"keep"}]'});
      final prefs = await SharedPreferences.getInstance();
      expect(await Backup.import(prefs, 'not json'), isNull);
      expect(await Backup.import(prefs, '{"app":"other","data":{}}'), isNull);
      expect(await Backup.import(prefs, '{"app":"yeobaek","data":{"todos":"{broken"}}'), isNull);
      expect(prefs.getString('todos_v1'), '[{"id":"keep"}]');
    });
  });

  group('자주 가는 곳', () {
    test('장소 이동시간을 기억하고, 띄어쓰기·대소문자는 같게 봐요', () async {
      final book = MemoryTravelBook();
      await book.setPlace('강남 Station', const Travel(before: 30, after: 30));
      expect(book.ofPlace('강남station').before, 30);
      expect(book.ofPlace('판교').isNone, true);
      expect(book.places().length, 1);
      await book.setPlace('강남 Station', null);
      expect(book.places(), isEmpty);
    });

    test('기기에 저장했다가 다시 열어도 남아 있어요', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await PrefsTravelBook.open();
      await a.setPlace('회사', const Travel(before: 20, after: 45));
      final b = await PrefsTravelBook.open();
      expect(b.ofPlace('회사').after, 45);
      expect(b.places().first.$1, '회사');
    });
  });

  group('Pro', () {
    test('사면 Pro 가 돼요', () async {
      final pro = ProState(FakeProBackend());
      expect(pro.isPro, false);
      await pro.loadPrice();
      expect(pro.price, isNotNull);
      await pro.buy();
      expect(pro.isPro, true);
      expect(pro.busy, false);
    });
  });

  group('후보 · 되돌리기 · 동그라미', () {
    testWidgets('후보를 보여주고 넣으면 일정이 되고, 되돌리면 사라져요', (tester) async {
      final store = await open(tester);
      await store.saveTodo(
        Todo(id: 't1', title: '치과 예약 전화', minutes: 10, due: DateTime(2026, 10, 27), split: false, minChunk: 0),
      );
      final plan = store.planTodoSlots();
      store.showCandidates(plan.items);
      await tester.pumpAndSettle();
      expect(store.view, ViewMode.day);
      expect(find.text('이렇게 넣어볼까요?'), findsOneWidget);
      expect(find.text('캘린더에 넣기 · 1개'), findsOneWidget);
      expect(store.todoById('t1')!.slots, isEmpty);

      await tester.tap(find.text('캘린더에 넣기 · 1개'));
      await tester.pumpAndSettle();
      expect(store.candidates, isEmpty);
      expect(store.todoById('t1')!.slots.length, 1);
      expect(find.text('일정 1개를 넣었어요'), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(store.todoById('t1')!.slots, isEmpty);
      expect(store.todoById('t1')!.need, 10);
      expect(find.text('일정 1개를 넣었어요'), findsNothing);
    });

    testWidgets('후보 지우기', (tester) async {
      final store = await open(tester);
      await store.saveTodo(
        Todo(id: 't1', title: '운동', minutes: 30, due: DateTime(2026, 10, 28), split: false, minChunk: 0),
      );
      store.showCandidates(store.planTodoSlots().items);
      await tester.pumpAndSettle();
      await tester.tap(find.text('후보 지우기'));
      await tester.pumpAndSettle();
      expect(store.candidates, isEmpty);
      expect(find.text('이렇게 넣어볼까요?'), findsNothing);
    });

    testWidgets('일정 동그라미를 누르면 할 일이 끝나요', (tester) async {
      final store = await open(tester);
      await store.saveTodo(
        Todo(id: 't1', title: '치과 예약 전화', minutes: 10, due: DateTime(2026, 10, 27), split: false, minChunk: 0),
      );
      await store.applyProposals(store.planTodoSlots().items);
      final slot = store.todoById('t1')!.slots.first;
      final day = DateTime(slot.start.year, slot.start.month, slot.start.day);
      final ev = store.eventsOn(day).firstWhere((e) => e.title == '치과 예약 전화');
      expect(store.todoForEvent(ev), isNotNull);
      await store.toggleSlotDone(ev);
      expect(store.todoById('t1')!.done, true);
      await store.toggleSlotDone(ev);
      expect(store.todoById('t1')!.done, false);
    });
  });

  group('첫 화면', () {
    testWidgets('위쪽에 검색 · ⋯ · 알약 줄이 있어요', (tester) async {
      await open(tester);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.tag_rounded), findsOneWidget);
      expect(find.text('태그'), findsOneWidget);
    });

    testWidgets('⋯ 메뉴: 백업 · 복원(PRO)과 사용 방법', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('백업 · 복원'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('사용 방법'), findsOneWidget);

      await tester.tap(find.text('사용 방법'));
      await tester.pumpAndSettle();
      expect(find.text('여백은 이렇게 써요'), findsOneWidget);
    });

    testWidgets('Pro 가 아니면 백업을 누를 때 Pro 안내가 먼저 떠요', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('백업 · 복원'));
      await tester.pumpAndSettle();
      expect(find.text('여백 Pro'), findsOneWidget);
      expect(find.textContaining('Pro 열기'), findsOneWidget);
      expect(find.text('구매 복원'), findsOneWidget);
    });

    testWidgets('처음 열면 안내가 한 번 떠요', (tester) async {
      final flags = MemoryFlags(welcomeSeen: false);
      await open(tester, flags: flags);
      expect(find.text('여백은 이렇게 써요'), findsOneWidget);
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('여백은 이렇게 써요'), findsNothing);
      expect(flags.welcomeSeen, true);
    });
  });
}
