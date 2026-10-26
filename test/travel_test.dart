import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/models.dart';
import 'package:yeobaek/repo.dart';
import 'package:yeobaek/store.dart';
import 'package:yeobaek/travel.dart';

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
  Future<String?> create({
    String? calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    List<String> tags = const <String>[],
    Repeat? repeat,
  }) async => null;
  @override
  Future<void> update(
    Ev e, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String? location,
    String? note,
    List<String> tags = const <String>[],
  }) async {}
  @override
  Future<void> setTags(Ev e, List<String> tags) async {}
  @override
  Future<void> move(Ev e, DateTime start, DateTime end) async {}
  @override
  Future<void> delete(Ev e, {DeleteScope scope = DeleteScope.one}) async {}
  @override
  Future<void> openEditor(Ev e) async {}
}

Ev _ev(String id, DateTime s, DateTime e) => Ev(
      id: id,
      instanceId: id,
      calendarId: 'c',
      calendarName: '테스트',
      title: id,
      start: s,
      end: e,
      allDay: false,
      color: const Color(0xFF4F6BFF),
    );

void main() {
  final now = DateTime(2026, 10, 26, 14, 10);
  final day = DateTime(2026, 10, 27);
  final evs = [_ev('a', DateTime(2026, 10, 27, 13), DateTime(2026, 10, 27, 14))];

  Future<CalendarStore> make() async {
    final s = CalendarStore(_Repo(evs), clock: () => now);
    await s.init();
    return s;
  }

  test('글자: 같으면 씩, 다르면 갈 때/올 때', () {
    expect(Travel.none.label, '없음');
    expect(const Travel(before: 30, after: 30).label, '갈 때·올 때 30분씩');
    expect(const Travel(before: 60, after: 10).label, '갈 때 1시간 · 올 때 10분');
    expect(const Travel(before: 90).shortLabel, '이동 1시간 30분');
  });

  test('이동시간만큼 바쁜 시간이 늘어요', () async {
    final s = await make();
    expect(s.freeMinutes(day), 12 * 60);
    await s.setEventTravel(evs.first, const Travel(before: 30, after: 20));
    final spans = s.busySpans(day);
    expect(spans.length, 1);
    expect(spans[0].a, DateTime(2026, 10, 27, 12, 30));
    expect(spans[0].b, DateTime(2026, 10, 27, 14, 20));
    expect(s.freeMinutes(day), 13 * 60 - 110);
    await s.setEventTravel(evs.first, Travel.none);
    expect(s.freeMinutes(day), 12 * 60);
  });

  test('자리 추천은 새 일정의 이동시간까지 넣어서 찾아요', () async {
    final s = await make();
    // 9–13 사이(4시간)에 3시간 30분짜리 + 앞뒤 30분이면 들어갈 수 없어요.
    final tight = s.slotsOnDay(const Duration(hours: 3, minutes: 30), day,
        travel: const Travel(before: 30, after: 30), count: 5);
    expect(tight.where((x) => x.start.hour < 13).isEmpty, true);
    final ok = s.slotsOnDay(const Duration(hours: 1), day, travel: const Travel(before: 30), count: 1);
    expect(ok.first.start, DateTime(2026, 10, 27, 9, 30));
  });

  test('저장소: 넣고 빼기', () async {
    final b = MemoryTravelBook();
    await b.set('x', const Travel(before: 20, after: 20));
    expect(b.of('x').before, 20);
    await b.set('x', Travel.none);
    expect(b.of('x').isNone, true);
  });
}
