import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:home_widget/home_widget.dart';

import 'dates.dart';
import 'projects.dart';
import 'store.dart';
import 'todos.dart';

/// iOS 위젯과 나눠 쓰는 저장 칸 (앱 그룹)
const String kWidgetGroup = 'group.com.isla0x.yeobaek';

/// 위젯 종류 이름 (Swift 쪽 `kind` 와 같아야 해요)
const List<String> kWidgetKinds = <String>[
  'YeobaekToday',
  'YeobaekTimeline',
  'YeobaekProject',
  'YeobaekTodos',
  'YeobaekWeek',
  'YeobaekLock',
];

String _hex(Color c) {
  int b(double v) => (v * 255).round().clamp(0, 255);
  String h(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${h(b(c.r))}${h(b(c.g))}${h(b(c.b))}';
}

String _ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// 위젯이 읽을 자료. 지금 시각에 따라 달라지는 값(남은 여유 등)은 넣지 않고,
/// 위젯이 직접 계산해요. 그래서 일정이 바뀌지 않으면 글자도 그대로예요.
Map<String, Object?> buildWidgetSnapshot(CalendarStore s) {
  final today = s.today;
  final days = <Map<String, Object?>>[];
  for (var i = 0; i < 7; i++) {
    final d = addDays(today, i);
    final evs = s.eventsOn(d);
    days.add({
      'date': _ymd(d),
      'wd': wd(d),
      'hol': s.holidayOn(d),
      'events': [
        for (final e in evs)
          {
            't': e.title,
            's': e.start.millisecondsSinceEpoch,
            'e': e.end.millisecondsSinceEpoch,
            'allDay': e.allDay,
            'c': _hex(e.color),
            if (s.todoForEvent(e) != null) 'todo': true,
          },
      ],
      'busy': [
        for (final b in s.busySpans(d))
          {'s': b.a.millisecondsSinceEpoch, 'e': b.b.millisecondsSinceEpoch},
      ],
      'gaps': [
        for (final g in s.gaps(d))
          {'s': g.a.millisecondsSinceEpoch, 'e': g.b.millisecondsSinceEpoch},
      ],
      'free': s.freeMinutes(d),
    });
  }

  final todos = <Map<String, Object?>>[];
  final listed = [...s.todos]..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ad = a.due, bd = b.due;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
  for (final t in listed) {
    if (todos.length >= 8) break;
    final doneToday = t.done && t.doneAt != null && sameDay(t.doneAt!, today);
    if (t.done && !doneToday) continue;
    final next = t.futureSlots(s.now);
    todos.add({
      'id': t.id,
      't': t.title,
      'm': t.need > 0 ? t.need : t.minutes,
      'done': t.done,
      if (t.due != null) 'due': _ymd(t.due!),
      if (next.isNotEmpty) 'at': next.first.start.millisecondsSinceEpoch,
      'plan': t.needsPlan(s.now),
    });
  }

  final projects = <Map<String, Object?>>[];
  final plist = s.projects.where((p) => p.statusOn(today) != ProjectStatus.done).toList()
    ..sort((a, b) => a.end.compareTo(b.end));
  for (final p in plist.take(4)) {
    final cp = p.nextCheckpoint(today);
    projects.add({
      'name': p.name,
      'c': _hex(p.color),
      'start': _ymd(p.start),
      'end': _ymd(p.end),
      'dday': p.dDay(today),
      'n': p.dayNumber(today),
      'total': p.totalDays,
      'left': p.remainingDays(today),
      'upcoming': p.statusOn(today) == ProjectStatus.upcoming,
      if (cp != null) 'cp': {'t': cp.title, 'dday': daysBetween(today, cp.date)},
    });
  }

  return {
    'v': 1,
    'today': _ymd(today),
    'dayStart': CalendarStore.dayStartHour,
    'dayEnd': CalendarStore.dayEndHour,
    'days': days,
    'todos': todos,
    'projects': projects,
  };
}

/// 위젯에 자료를 건네는 곳. 진짜(iOS 앱 그룹)와 가짜(테스트)를 바꿔 끼워요.
abstract class WidgetSink {
  Future<void> write(String json);
}

class MemoryWidgetSink implements WidgetSink {
  final List<String> writes = <String>[];

  @override
  Future<void> write(String json) async => writes.add(json);
}

class HomeWidgetSink implements WidgetSink {
  bool _ready = false;

  @override
  Future<void> write(String json) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      if (!_ready) {
        await HomeWidget.setAppGroupId(kWidgetGroup);
        _ready = true;
      }
      await HomeWidget.saveWidgetData<String>('snapshot', json);
      for (final k in kWidgetKinds) {
        await HomeWidget.updateWidget(iOSName: k);
      }
    } catch (_) {
      // 위젯이 아직 없거나 설정이 안 된 기기에서도 앱은 그대로 돌아가요.
    }
  }
}

/// 일정이 바뀔 때마다 위젯 자료를 새로 써요 (내용이 같으면 쓰지 않아요).
class WidgetSync {
  WidgetSync(this.store, this.sink) {
    store.addListener(_onChange);
    _onChange();
  }

  final CalendarStore store;
  final WidgetSink sink;
  String? _last;

  void _onChange() {
    if (!store.ready || store.loading) return;
    final today = store.today;
    if (!store.coversDays(today, addDays(today, 6))) return;
    final json = jsonEncode(buildWidgetSnapshot(store));
    if (json == _last) return;
    _last = json;
    unawaited(sink.write(json));
  }

  void dispose() => store.removeListener(_onChange);
}
