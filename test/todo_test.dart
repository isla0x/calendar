import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/models.dart';
import 'package:yeobaek/todos.dart';

void main() {
  // 2026-10-26 월요일 14:10
  final now = DateTime(2026, 10, 26, 14, 10);

  List<Span> busy(DateTime d) {
    if (d.day == 26) {
      return [
        Span(DateTime(2026, 10, 26, 13), DateTime(2026, 10, 26, 14, 30)),
        Span(DateTime(2026, 10, 26, 17), DateTime(2026, 10, 26, 18)),
      ];
    }
    return const <Span>[];
  }

  group('한 줄 읽기', () {
    test('길이 · 이번 주 안에 · 태그', () {
      final r = parseTodo('소설 쓰기 2시간 이번 주 안에 #글쓰기', now: now);
      expect(r.title, '소설 쓰기');
      expect(r.minutes, 120);
      expect(r.due, DateTime(2026, 10, 30));
      expect(r.tags, ['글쓰기']);
    });

    test('주 2번 · 언젠가 · 까지', () {
      final a = parseTodo('운동 1시간 주 2번', now: now);
      expect(a.perWeek, 2);
      expect(a.minutes, 60);
      expect(a.title, '운동');
      final b = parseTodo('책장 정리 30분 언젠가', now: now);
      expect(b.someday, true);
      expect(b.due, isNull);
      final c = parseTodo('영어 공부 30분 오늘까지', now: now);
      expect(c.due, DateTime(2026, 10, 26));
      expect(c.title, '영어 공부');
    });

    test('이번 주 마감: 평일은 금요일, 주말은 일요일', () {
      expect(weekDeadline(DateTime(2026, 10, 26)), DateTime(2026, 10, 30));
      expect(weekDeadline(DateTime(2026, 10, 31)), DateTime(2026, 11, 1));
    });
  });

  group('자리 찾기', () {
    test('오늘까지인 30분은 회의가 끝난 14:30 에 넣어요', () {
      final t = Todo(
        id: 'a',
        title: '영어 공부',
        minutes: 30,
        due: DateTime(2026, 10, 26),
        split: false,
        minChunk: 0,
      );
      final r = planTodos([t], now: now, busyOn: busy);
      expect(r.items.length, 1);
      expect(r.items.first.start, DateTime(2026, 10, 26, 14, 30));
      expect(r.items.first.end, DateTime(2026, 10, 26, 15));
      expect(r.unplaced, isEmpty);
    });

    test('2시간은 저녁에 하루씩 나눠서 넣어요', () {
      final t = Todo(
        id: 'b',
        title: '소설 쓰기',
        minutes: 120,
        due: DateTime(2026, 10, 30),
        minChunk: 60,
        part: DayPart.evening,
      );
      final r = planTodos([t], now: now, busyOn: busy);
      expect(r.items.length, 2);
      expect(r.items[0].start.day != r.items[1].start.day, true);
      for (final x in r.items) {
        expect(x.start.hour >= 18, true);
        expect(x.minutes, 60);
        expect(x.count, 2);
      }
    });

    test('주 2번은 서로 다른 날에 한 번씩', () {
      final t = Todo(
        id: 'c',
        title: '운동',
        minutes: 60,
        perWeek: 2,
        due: DateTime(2026, 10, 30),
      );
      final r = planTodos([t], now: now, busyOn: busy);
      expect(r.items.length, 2);
      expect(r.items[0].start.day != r.items[1].start.day, true);
    });

    test('마감 전에 자리가 없으면 못 넣은 시간을 알려줘요', () {
      final t = Todo(
        id: 'd',
        title: '너무 긴 일',
        minutes: 600,
        due: DateTime(2026, 10, 26),
        split: false,
        minChunk: 0,
      );
      final r = planTodos([t], now: now, busyOn: busy);
      expect(r.items, isEmpty);
      expect(r.unplaced['d'], 600);
    });

    test('이미 앞으로 올 자리가 있으면 다시 찾지 않아요', () {
      final t = Todo(
        id: 'e',
        title: '이미 넣음',
        minutes: 30,
        slots: [
          TodoSlot(
            eventId: 'x',
            start: DateTime(2026, 10, 27, 10),
            end: DateTime(2026, 10, 27, 10, 30),
          ),
        ],
      );
      expect(t.needsPlan(now), false);
      expect(planTodos([t], now: now, busyOn: busy).items, isEmpty);
    });

    test('저장했다가 다시 읽어도 같아요', () {
      final t = Todo(
        id: 'f',
        title: '보고서',
        minutes: 90,
        due: DateTime(2026, 10, 30),
        part: DayPart.afternoon,
        tags: ['프로젝트'],
        slots: [
          TodoSlot(
            eventId: 'x',
            start: DateTime(2026, 10, 27, 10),
            end: DateTime(2026, 10, 27, 11),
            asked: true,
          ),
        ],
      );
      final u = Todo.fromJson(t.toJson())!;
      expect(u.title, '보고서');
      expect(u.due, DateTime(2026, 10, 30));
      expect(u.part, DayPart.afternoon);
      expect(u.tags, ['프로젝트']);
      expect(u.slots.single.asked, true);
      expect(u.slots.single.start, DateTime(2026, 10, 27, 10));
    });
  });
}
