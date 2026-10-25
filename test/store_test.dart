import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/models.dart';
import 'package:yeobaek/repo.dart';
import 'package:yeobaek/store.dart';
import 'package:flutter/painting.dart';

class _Repo implements CalendarRepo {
  _Repo(this.list);
  final List<Ev> list;

  @override
  bool get isDemo => true;
  @override
  Future<PermState> permission() async => PermState.granted;
  @override
  Future<PermState> requestPermission() async => PermState.granted;
  @override
  Future<void> openSettings() async {}
  @override
  Future<List<CalInfo>> calendars() async => const <CalInfo>[];
  @override
  Future<List<Ev>> events(DateTime from, DateTime to) async => list;
  @override
  Future<void> create({
    String? calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    List<String> tags = const <String>[],
  }) async {}
  @override
  Future<void> setTags(Ev e, List<String> tags) async {}
  @override
  Future<void> move(Ev e, DateTime start, DateTime end) async {}
  @override
  Future<void> delete(Ev e) async {}
  @override
  Future<void> openEditor(Ev e) async {}
}

Ev _ev(String id, DateTime s, DateTime e, {bool allDay = false}) => Ev(
      id: id,
      instanceId: id,
      calendarId: 'c',
      calendarName: '테스트',
      title: id,
      start: s,
      end: e,
      allDay: allDay,
      color: const Color(0xFF4F6BFF),
    );

void main() {
  final now = DateTime(2026, 10, 26, 14, 10);
  final day = DateTime(2026, 10, 27);

  Future<CalendarStore> make(List<Ev> evs) async {
    final s = CalendarStore(_Repo(evs), clock: () => now);
    await s.init();
    return s;
  }

  final evs = [
    _ev('a', DateTime(2026, 10, 27, 10), DateTime(2026, 10, 27, 11)),
    _ev('b', DateTime(2026, 10, 27, 10, 30), DateTime(2026, 10, 27, 12)),
    _ev('c', DateTime(2026, 10, 27, 18, 30), DateTime(2026, 10, 27, 20)),
    _ev('d', DateTime(2026, 10, 27), DateTime(2026, 10, 28), allDay: true),
  ];

  test('겹치는 일정은 합쳐서 계산하고 종일 일정은 빼요', () async {
    final s = await make(evs);
    expect(s.eventsOn(day).length, 4);
    final spans = s.busySpans(day);
    expect(spans.length, 2);
    expect(spans[0].a, DateTime(2026, 10, 27, 10));
    expect(spans[0].b, DateTime(2026, 10, 27, 12));
    expect(s.freeMinutes(day), 570); // 13시간 - 3시간 30분
    expect(s.loadLevel(day), 1);
  });

  test('비는 시간 구간 (30분 이상)', () async {
    final s = await make(evs);
    final g = s.gaps(day);
    expect(g.length, 3);
    expect(g[0].a, DateTime(2026, 10, 27, 9));
    expect(g[0].b, DateTime(2026, 10, 27, 10));
    expect(g[1].a, DateTime(2026, 10, 27, 12));
    expect(g[1].b, DateTime(2026, 10, 27, 18, 30));
    expect(g[2].a, DateTime(2026, 10, 27, 20));
    expect(g[2].b, DateTime(2026, 10, 27, 22));
  });

  test('지금부터 남은 여유', () async {
    final s = await make(evs);
    expect(s.freeMinutes(day, from: DateTime(2026, 10, 27, 11)), 510);
  });

  test('옮길 수 있는 시간 추천', () async {
    final s = await make(evs);
    final slots = s.slotsOnDay(const Duration(hours: 1), day);
    expect(slots.length, 3);
    expect(slots[0].start, DateTime(2026, 10, 27, 9));
    expect(slots[1].start, DateTime(2026, 10, 27, 12));
    expect(slots[2].start, DateTime(2026, 10, 27, 20));
  });

  test('다른 날까지 하루에 하나씩 추천', () async {
    final s = await make(evs);
    final slots = s.suggestAcrossDays(const Duration(hours: 1), day, count: 3, days: 5);
    expect(slots.length, 3);
    expect(slots[0].start, DateTime(2026, 10, 27, 9));
    expect(slots[1].start.day, 28);
    expect(slots[2].start.day, 29);
  });

  test('여러 날에 걸친 종일 일정은 모든 날에 나와요', () async {
    final s = await make([
      _ev('x', DateTime(2026, 10, 27), DateTime(2026, 10, 30), allDay: true),
    ]);
    expect(s.eventsOn(DateTime(2026, 10, 27)).length, 1);
    expect(s.eventsOn(DateTime(2026, 10, 29)).length, 1);
    expect(s.eventsOn(DateTime(2026, 10, 30)).length, 0);
  });

  test('태그로 걸러보기: shownOn 은 고른 태그만, eventsOn 은 전부', () async {
    final s = await make([
      _ev('a', DateTime(2026, 10, 27, 10), DateTime(2026, 10, 27, 11)).copyWith(tags: ['회의']),
      _ev('b', DateTime(2026, 10, 27, 12), DateTime(2026, 10, 27, 13)),
    ]);
    expect(s.shownOn(day).length, 2);
    expect(s.knownTags(), ['회의']);
    s.setTagFilter('회의');
    expect(s.shownOn(day).map((e) => e.id).toList(), ['a']);
    expect(s.eventsOn(day).length, 2);
    expect(s.tagMatch(s.eventsOn(day).last), false);
    s.setTagFilter(null);
    expect(s.shownOn(day).length, 2);
  });

  test('Ev.firstDay / lastDay: 종일은 끝 날짜를 하루 앞으로, 자정에 끝나면 그 전날', () {
    final allDay = _ev('p', DateTime(2026, 9, 18), DateTime(2026, 10, 29), allDay: true);
    expect(allDay.firstDay, DateTime(2026, 9, 18));
    expect(allDay.lastDay, DateTime(2026, 10, 28));
    final one = _ev('o', DateTime(2026, 10, 27), DateTime(2026, 10, 28), allDay: true);
    expect(one.lastDay, DateTime(2026, 10, 27));
    final timed = _ev('t', DateTime(2026, 10, 27, 10), DateTime(2026, 10, 27, 11));
    expect(timed.lastDay, DateTime(2026, 10, 27));
    final night = _ev('n', DateTime(2026, 10, 27, 22), DateTime(2026, 10, 28, 2));
    expect(night.lastDay, DateTime(2026, 10, 28));
    final toMidnight = _ev('m', DateTime(2026, 10, 27, 22), DateTime(2026, 10, 28));
    expect(toMidnight.lastDay, DateTime(2026, 10, 27));
  });
}
