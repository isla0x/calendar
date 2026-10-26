import 'package:flutter/painting.dart';

import 'dates.dart';

/// 기기에 있는 캘린더 하나 (예: 내 캘린더, 업무, 대한민국 공휴일)
class CalInfo {
  const CalInfo({
    required this.id,
    required this.name,
    required this.color,
    this.readOnly = false,
    this.isPrimary = false,
    this.account,
  });

  final String id;
  final String name;
  final Color color;
  final bool readOnly;
  final bool isPrimary;
  final String? account;
}

/// 일정 하나
class Ev {
  const Ev({
    required this.id,
    required this.instanceId,
    required this.calendarId,
    required this.calendarName,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.color,
    this.location,
    this.note,
    this.attendees = 0,
    this.recurring = false,
    this.readOnly = false,
    this.holiday = false,
    this.reminders = const <Duration>[],
    this.tags = const <String>[],
  });

  final String id;
  final String instanceId;
  final String calendarId;
  final String calendarName;
  final String title;

  /// 종일 일정은 start = 첫날 00:00, end = 마지막 날 다음 날 00:00 (끝 미포함)
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final Color color;
  final String? location;
  final String? note;
  final int attendees;
  final bool recurring;
  final bool readOnly;

  /// 공휴일 캘린더에서 온 일정 (막대로 그리지 않고 날짜를 빨갛게만 표시)
  final bool holiday;
  final List<Duration> reminders;

  /// 제목에 "#태그" 로 적어 둔 태그들 ([title] 에는 태그가 빠져 있어요)
  final List<String> tags;

  Duration get duration => end.difference(start);

  /// 일정이 걸쳐 있는 첫날 (날짜만)
  DateTime get firstDay => DateTime(start.year, start.month, start.day);

  /// 일정이 걸쳐 있는 마지막 날 (날짜만). 종일 일정은 끝이 "다음 날 00:00" 이라 하루 앞으로 봐요.
  DateTime get lastDay {
    final DateTime l;
    if (allDay) {
      l = addDays(DateTime(end.year, end.month, end.day), -1);
    } else if (end.isAfter(start)) {
      final x = end.subtract(const Duration(microseconds: 1));
      l = DateTime(x.year, x.month, x.day);
    } else {
      l = firstDay;
    }
    return l.isBefore(firstDay) ? firstDay : l;
  }

  Ev copyWith({DateTime? start, DateTime? end, List<String>? tags, Color? color}) => Ev(
        id: id,
        instanceId: instanceId,
        calendarId: calendarId,
        calendarName: calendarName,
        title: title,
        start: start ?? this.start,
        end: end ?? this.end,
        allDay: allDay,
        color: color ?? this.color,
        location: location,
        note: note,
        attendees: attendees,
        recurring: recurring,
        readOnly: readOnly,
        holiday: holiday,
        reminders: reminders,
        tags: tags ?? this.tags,
      );

  /// '10월 26일 월요일 14:30 – 15:30' 같은 한 줄 설명
  String whenText() {
    if (allDay) {
      final last = addDays(end, -1);
      if (!last.isAfter(start)) {
        return '${start.month}월 ${start.day}일 ${wdFull(start)} · 종일';
      }
      return '${start.month}월 ${start.day}일 – ${last.month}월 ${last.day}일 · 종일';
    }
    final base = '${start.month}월 ${start.day}일 ${wdFull(start)}';
    return '$base ${hm(start)} – ${hm(end)}';
  }
}

/// 반복 일정을 지울 때 범위
enum DeleteScope { one, following, all }

/// 반복 방식
enum RepeatKind { daily, weekdays, weekly, days }

/// 반복 일정 설정. [until] 은 반복이 끝나는 마지막 날(그날 포함, 날짜만). 없으면 계속 반복해요.
class Repeat {
  const Repeat(this.kind, {this.until, this.days = const <int>{}});

  final RepeatKind kind;
  final DateTime? until;

  /// [RepeatKind.days] 일 때 일정이 생기는 요일 (월=1 … 일=7)
  final Set<int> days;

  String get label {
    switch (kind) {
      case RepeatKind.daily:
        return '매일';
      case RepeatKind.weekdays:
        return '평일마다';
      case RepeatKind.weekly:
        return '매주';
      case RepeatKind.days:
        return '요일마다';
    }
  }
}

/// 시간 구간
class Span {
  const Span(this.a, this.b);
  final DateTime a;
  final DateTime b;

  Duration get length => b.difference(a);
}

/// 추천 시간
class Slot {
  const Slot(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// 공휴일 캘린더인지 (이름으로 알아봐요)
bool isHolidayName(String name) {
  final n = name.toLowerCase();
  return n.contains('공휴일') || n.contains('휴일') || n.contains('holiday');
}
