import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/l10n.dart';
import 'package:yeobaek/reminder.dart';
import 'package:yeobaek/store.dart';

void main() {
  final now = DateTime(2026, 10, 26, 14, 10);
  final start = DateTime(2026, 10, 27, 14); // 화요일 오후 2시

  test('알림 시점마다 일정 시작보다 얼마나 앞서 울리는지', () {
    expect(Reminder.atTime.offset(start), Duration.zero);
    expect(Reminder.min10.offset(start), const Duration(minutes: 10));
    expect(Reminder.hour1.offset(start), const Duration(hours: 1));
    // 당일 아침 8시 → 오후 2시 일정이면 6시간 전
    expect(Reminder.morning.offset(start), const Duration(hours: 6));
    // 전날 저녁 6시 → 20시간 전
    expect(Reminder.eveningBefore.offset(start), const Duration(hours: 20));
  });

  test('아침 8시보다 이른 일정은 "당일 아침"을 고를 수 없어요', () {
    expect(Reminder.morning.offset(DateTime(2026, 10, 27, 7)), isNull);
    expect(Reminder.morning.offset(DateTime(2026, 10, 27, 8)), isNull);
    expect(Reminder.morning.offset(DateTime(2026, 10, 27, 8, 30)), const Duration(minutes: 30));
  });

  test('종일 일정은 "전날"만 있어요', () {
    final day = DateTime(2026, 10, 27);
    expect(ReminderX.options(allDay: true), [Reminder.eveningBefore, Reminder.morningBefore]);
    expect(Reminder.eveningBefore.offset(day), const Duration(hours: 6));
    expect(Reminder.morningBefore.offset(day), const Duration(hours: 15));
  });

  test('기기에 있던 알림이 어느 선택지인지 알아봐요', () {
    expect(ReminderX.match(const [Duration(minutes: 10)], start, allDay: false), Reminder.min10);
    expect(ReminderX.match(const [Duration(hours: 20)], start, allDay: false), Reminder.eveningBefore);
    expect(ReminderX.match(const [Duration(minutes: 25)], start, allDay: false), isNull);
    expect(ReminderX.match(const <Duration>[], start, allDay: false), isNull);
  });

  test('저장할 목록: 없음은 빈 목록', () {
    expect(ReminderX.toList(null, start), isEmpty);
    expect(ReminderX.toList(Reminder.hour1, start), [const Duration(hours: 1)]);
    expect(ReminderX.toList(Reminder.morning, DateTime(2026, 10, 27, 7)), isEmpty);
  });

  test('글자', () {
    L10n.lang = Lang.ko;
    expect(Reminder.atTime.label, '정각');
    expect(Reminder.eveningBefore.label, '전날 저녁');
    expect(ReminderX.describe(const Duration(minutes: 30)), '30분 전 알림');
    expect(ReminderX.summary(null, const <Duration>[], touched: false), '없음');
    expect(ReminderX.summary(Reminder.min10, const <Duration>[], touched: true), '10분 전');
    L10n.lang = Lang.en;
    expect(Reminder.morning.label, 'Morning of');
    L10n.lang = Lang.ko;
  });

  test('일정을 만들 때 넣은 알림이 일정에 남아요', () async {
    final s = CalendarStore(DemoRepo(clock: () => now), clock: () => now);
    await s.init();
    final ok = await s.addEvent(
      title: '알림 시험',
      start: start,
      end: start.add(const Duration(hours: 1)),
      reminders: ReminderX.toList(Reminder.min10, start),
    );
    expect(ok, isTrue);
    final e = s.eventsOn(DateTime(2026, 10, 27)).firstWhere((x) => x.title == '알림 시험');
    expect(e.reminders, [const Duration(minutes: 10)]);
    // 알림을 안 건드리고 고치면 그대로, 없음으로 고치면 비어요
    await s.updateEvent(e, title: '알림 시험', start: start, end: e.end, allDay: false);
    var e2 = s.eventsOn(DateTime(2026, 10, 27)).firstWhere((x) => x.title == '알림 시험');
    expect(e2.reminders, [const Duration(minutes: 10)]);
    await s.updateEvent(e2, title: '알림 시험', start: start, end: e.end, allDay: false, reminders: const <Duration>[]);
    e2 = s.eventsOn(DateTime(2026, 10, 27)).firstWhere((x) => x.title == '알림 시험');
    expect(e2.reminders, isEmpty);
  });

  test('완료 표시는 날마다 따로, 껐다 켤 수 있어요', () async {
    final s = CalendarStore(DemoRepo(clock: () => now), clock: () => now);
    await s.init();
    final day1 = DateTime(2026, 10, 27, 13);
    await s.addEvent(title: '완료 시험', start: day1, end: day1.add(const Duration(hours: 1)));
    final e = s.eventsOn(DateTime(2026, 10, 27)).firstWhere((x) => x.title == '완료 시험');
    expect(s.isDone(e), isFalse);
    await s.toggleDone(e);
    expect(s.isDone(e), isTrue);
    // 같은 일정의 다른 날은 따로예요
    final other = e.copyWith(start: e.start.add(const Duration(days: 1)), end: e.end.add(const Duration(days: 1)));
    expect(s.isDone(other), isFalse);
    await s.toggleDone(e);
    expect(s.isDone(e), isFalse);
  });
}
