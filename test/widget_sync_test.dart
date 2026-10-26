import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/store.dart';
import 'package:yeobaek/todos.dart';
import 'package:yeobaek/widget_sync.dart';

void main() {
  final now = DateTime(2026, 10, 26, 14, 10);

  Future<CalendarStore> open() async {
    final store = CalendarStore(DemoRepo(clock: () => now), clock: () => now);
    await store.init();
    return store;
  }

  test('위젯 자료: 7일치 일정·비는 시간·할 일이 들어 있어요', () async {
    final store = await open();
    await store.saveTodo(Todo(id: 't1', title: '영어 공부', minutes: 30, due: DateTime(2026, 10, 28)));
    final snap = buildWidgetSnapshot(store);
    final json = jsonDecode(jsonEncode(snap)) as Map<String, dynamic>;
    expect(json['today'], '2026-10-26');
    final days = json['days'] as List;
    expect(days.length, 7);
    final d0 = days.first as Map<String, dynamic>;
    expect(d0['wd'], '월');
    expect((d0['events'] as List).isNotEmpty, true);
    expect((d0['busy'] as List).isNotEmpty, true);
    expect(d0['free'], isA<int>());
    final e0 = (d0['events'] as List).first as Map<String, dynamic>;
    expect(e0['c'], matches(RegExp(r'^#[0-9a-f]{6}$')));
    final todos = json['todos'] as List;
    expect((todos.first as Map)['t'], '영어 공부');
    expect((todos.first as Map)['plan'], true);
  });

  test('내용이 같으면 다시 쓰지 않고, 바뀌면 새로 써요', () async {
    final store = await open();
    final sink = MemoryWidgetSink();
    final sync = WidgetSync(store, sink);
    expect(sink.writes.length, 1);
    store.select(DateTime(2026, 10, 27)); // 보는 날만 바뀜 → 위젯 자료는 그대로
    expect(sink.writes.length, 1);
    await store.saveTodo(Todo(id: 't2', title: '운동', minutes: 60));
    expect(sink.writes.length, 2);
    sync.dispose();
  });
}
