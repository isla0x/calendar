import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'models.dart';
import 'parser.dart';

/// 좋아하는 시간대
enum DayPart { any, morning, afternoon, evening }

extension DayPartText on DayPart {
  String get label {
    switch (this) {
      case DayPart.any:
        return '상관없어요';
      case DayPart.morning:
        return '오전';
      case DayPart.afternoon:
        return '오후';
      case DayPart.evening:
        return '저녁';
    }
  }

  /// 시간대의 시작·끝 시각 (시)
  (int, int)? get hours {
    switch (this) {
      case DayPart.any:
        return null;
      case DayPart.morning:
        return (9, 12);
      case DayPart.afternoon:
        return (12, 18);
      case DayPart.evening:
        return (18, 22);
    }
  }
}

/// 할 일을 캘린더에 넣은 자리 하나 (캘린더 일정 id 와 이어져 있어요)
class TodoSlot {
  const TodoSlot({
    required this.eventId,
    required this.start,
    required this.end,
    this.asked = false,
    this.done = false,
  });

  final String eventId;
  final DateTime start;
  final DateTime end;

  /// 끝난 뒤 "다 했어요?" 하고 이미 물어봤는지
  final bool asked;

  /// 이 자리에서 할 일을 끝냈는지 (일정 옆 동그라미로 체크해요)
  final bool done;

  int get minutes => end.difference(start).inMinutes;

  TodoSlot copyWith({DateTime? start, DateTime? end, bool? asked, bool? done}) => TodoSlot(
        eventId: eventId,
        start: start ?? this.start,
        end: end ?? this.end,
        asked: asked ?? this.asked,
        done: done ?? this.done,
      );

  Map<String, Object?> toJson() => {
        'e': eventId,
        's': start.millisecondsSinceEpoch,
        't': end.millisecondsSinceEpoch,
        'a': asked,
        'd': done,
      };

  static TodoSlot? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['e'];
    final s = j['s'];
    final t = j['t'];
    if (e is! String || s is! int || t is! int) return null;
    return TodoSlot(
      eventId: e,
      start: DateTime.fromMillisecondsSinceEpoch(s),
      end: DateTime.fromMillisecondsSinceEpoch(t),
      asked: j['a'] == true,
      done: j['d'] == true,
    );
  }
}

/// 할 일 하나
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.minutes,
    this.due,
    this.split = true,
    this.minChunk = 30,
    this.part = DayPart.any,
    this.perWeek = 0,
    this.tags = const <String>[],
    this.done = false,
    this.doneAt,
    this.slots = const <TodoSlot>[],
    this.need = 0,
    this.notBefore,
  });

  final String id;
  final String title;

  /// 걸리는 시간(분). 반복이면 한 번에 걸리는 시간이에요.
  final int minutes;

  /// 마감일 (그날 포함). 없으면 "언젠가"
  final DateTime? due;

  /// 나눠서 넣어도 되는지, 한 번에 최소 몇 분인지 (0 이면 통째로)
  final bool split;
  final int minChunk;
  final DayPart part;

  /// 주에 몇 번 (0 이면 반복 없음, 7 이면 매일)
  final int perWeek;
  final List<String> tags;
  final bool done;
  final DateTime? doneAt;

  /// 캘린더에 넣은 자리들
  final List<TodoSlot> slots;

  /// 아직 자리를 못 찾은 시간(분). 0 이면 처음 길이([minutes]) 그대로예요.
  final int need;

  /// 이 날 전에는 넣지 않아요 ("내일로 미루기")
  final DateTime? notBefore;

  Todo copyWith({
    String? title,
    int? minutes,
    DateTime? due,
    bool clearDue = false,
    bool? split,
    int? minChunk,
    DayPart? part,
    int? perWeek,
    List<String>? tags,
    bool? done,
    DateTime? doneAt,
    List<TodoSlot>? slots,
    int? need,
    DateTime? notBefore,
    bool clearNotBefore = false,
  }) =>
      Todo(
        id: id,
        title: title ?? this.title,
        minutes: minutes ?? this.minutes,
        due: clearDue ? null : (due ?? this.due),
        split: split ?? this.split,
        minChunk: minChunk ?? this.minChunk,
        part: part ?? this.part,
        perWeek: perWeek ?? this.perWeek,
        tags: tags ?? this.tags,
        done: done ?? this.done,
        doneAt: doneAt ?? this.doneAt,
        slots: slots ?? this.slots,
        need: need ?? this.need,
        notBefore: clearNotBefore ? null : (notBefore ?? this.notBefore),
      );

  /// 아직 지나지 않은 자리들 (시간순)
  List<TodoSlot> futureSlots(DateTime now) =>
      slots.where((s) => s.end.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));

  /// 지금 자리를 찾아야 하는지 (끝나지 않았고, 앞으로 올 자리가 없을 때)
  bool needsPlan(DateTime now) => !done && futureSlots(now).isEmpty;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'min': minutes,
        'due': due == null ? null : dayKey(due!),
        'split': split,
        'chunk': minChunk,
        'part': part.index,
        'week': perWeek,
        'tags': tags,
        'done': done,
        'doneAt': doneAt?.millisecondsSinceEpoch,
        'slots': [for (final s in slots) s.toJson()],
        'need': need,
        'nb': notBefore == null ? null : dayKey(notBefore!),
      };

  static DateTime? _day(Object? v) {
    if (v is! int) return null;
    return DateTime(v ~/ 10000, (v ~/ 100) % 100, v % 100);
  }

  static Todo? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    final min = j['min'];
    if (id is! String || title is! String || min is! int) return null;
    final slots = <TodoSlot>[];
    final rawSlots = j['slots'];
    if (rawSlots is List) {
      for (final x in rawSlots) {
        final s = TodoSlot.fromJson(x);
        if (s != null) slots.add(s);
      }
    }
    final tags = <String>[];
    final rawTags = j['tags'];
    if (rawTags is List) {
      for (final x in rawTags) {
        if (x is String) tags.add(x);
      }
    }
    final part = j['part'];
    final doneAt = j['doneAt'];
    return Todo(
      id: id,
      title: title,
      minutes: min,
      due: _day(j['due']),
      split: j['split'] != false,
      minChunk: j['chunk'] is int ? j['chunk'] as int : 30,
      part: part is int && part >= 0 && part < DayPart.values.length
          ? DayPart.values[part]
          : DayPart.any,
      perWeek: j['week'] is int ? j['week'] as int : 0,
      tags: tags,
      done: j['done'] == true,
      doneAt: doneAt is int ? DateTime.fromMillisecondsSinceEpoch(doneAt) : null,
      slots: slots,
      need: j['need'] is int ? j['need'] as int : 0,
      notBefore: _day(j['nb']),
    );
  }
}

/// 할 일을 기억해 두는 곳
abstract class TodoBook {
  List<Todo> load();
  Future<void> save(List<Todo> all);
}

class MemoryTodoBook implements TodoBook {
  MemoryTodoBook([List<Todo>? initial]) : _all = List<Todo>.of(initial ?? const <Todo>[]);

  List<Todo> _all;

  @override
  List<Todo> load() => List<Todo>.of(_all);

  @override
  Future<void> save(List<Todo> all) async {
    _all = List<Todo>.of(all);
  }
}

class PrefsTodoBook implements TodoBook {
  PrefsTodoBook._(this._prefs, this._all);

  static const String _key = 'todos_v1';

  final SharedPreferences _prefs;
  List<Todo> _all;

  static Future<TodoBook> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final all = <Todo>[];
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is List) {
          for (final x in j) {
            final t = Todo.fromJson(x);
            if (t != null) all.add(t);
          }
        }
      }
      return PrefsTodoBook._(prefs, all);
    } catch (_) {
      return MemoryTodoBook();
    }
  }

  @override
  List<Todo> load() => List<Todo>.of(_all);

  @override
  Future<void> save(List<Todo> all) async {
    _all = List<Todo>.of(all);
    try {
      await _prefs.setString(_key, jsonEncode([for (final t in all) t.toJson()]));
    } catch (_) {}
  }
}

// ---------------------------------------------------------------- 문장 읽기

/// "소설 쓰기 2시간 이번 주 안에 #글쓰기" 같은 한 줄을 읽은 결과
class TodoParse {
  const TodoParse({
    required this.title,
    this.minutes,
    this.due,
    this.someday = false,
    this.perWeek = 0,
    this.tags = const <String>[],
  });

  final String title;
  final int? minutes;
  final DateTime? due;
  final bool someday;
  final int perWeek;
  final List<String> tags;
}

TodoParse parseTodo(String text, {required DateTime now}) {
  var t = text;
  final today = dayOnly(now);
  var perWeek = 0;
  var someday = false;
  DateTime? due;

  final mWeek = RegExp(r'주\s*([1-7])\s*번').firstMatch(t);
  if (mWeek != null) {
    perWeek = int.parse(mWeek.group(1)!);
    t = t.replaceRange(mWeek.start, mWeek.end, ' ');
  }
  if (t.contains('매일')) {
    perWeek = 7;
    t = t.replaceFirst('매일', ' ');
  }
  final mThis = RegExp(r'이번\s*주\s*(안에|까지)?').firstMatch(t);
  if (mThis != null) {
    due = weekDeadline(today);
    t = t.replaceRange(mThis.start, mThis.end, ' ');
  }
  if (t.contains('언젠가')) {
    someday = true;
    t = t.replaceFirst('언젠가', ' ');
  }
  t = t.replaceAll('까지', ' ');

  final q = parseQuick(t, now: now, defaultDay: today);
  if (due == null && !someday && q.hasDate) due = dayOnly(q.start);
  final minutes = q.hasDuration ? q.end.difference(q.start).inMinutes : null;
  final title = q.title.replaceAll(RegExp(r'\s+'), ' ').trim();
  return TodoParse(
    title: title,
    minutes: (minutes != null && minutes > 0) ? minutes : null,
    due: due,
    someday: someday,
    perWeek: perWeek,
    tags: q.tags,
  );
}

/// "이번 주 안에" 의 마감일: 평일이면 그 주 금요일, 주말이면 일요일
DateTime weekDeadline(DateTime today) {
  final d = dayOnly(today);
  if (d.weekday <= 5) return addDays(d, 5 - d.weekday);
  return addDays(d, 7 - d.weekday);
}

// ---------------------------------------------------------------- 자리 찾기

/// 캘린더에 넣어 보자고 제안하는 자리 하나
class Proposal {
  const Proposal({
    required this.todo,
    required this.start,
    required this.end,
    required this.index,
    required this.count,
  });

  final Todo todo;
  final DateTime start;
  final DateTime end;

  /// 나눠 넣을 때 몇 번째 / 전체 몇 조각 (조각이 하나면 count = 1)
  final int index;
  final int count;

  int get minutes => end.difference(start).inMinutes;
}

class PlanResult {
  const PlanResult(this.items, this.unplaced);

  final List<Proposal> items;

  /// 자리를 못 찾은 할 일 id → 못 넣은 시간(분)
  final Map<String, int> unplaced;
}

List<Span> _mergeSpans(List<Span> raw) {
  final s = List<Span>.of(raw)..sort((a, b) => a.a.compareTo(b.a));
  final out = <Span>[];
  for (final x in s) {
    if (out.isNotEmpty && !x.a.isAfter(out.last.b)) {
      if (x.b.isAfter(out.last.b)) out[out.length - 1] = Span(out.last.a, x.b);
    } else {
      out.add(x);
    }
  }
  return out;
}

/// 조각 길이들. 나눌 수 없으면 통째로 하나.
List<int> _pieces(Todo t, int total) {
  if (total <= 0) return const <int>[];
  if (!t.split || t.minChunk <= 0) return [total];
  final chunk = t.minChunk > 60 ? t.minChunk : 60;
  final out = <int>[];
  var rem = total;
  while (rem > 0) {
    var p = rem < chunk ? rem : chunk;
    if (rem - p > 0 && rem - p < t.minChunk) p = rem;
    out.add(p);
    rem -= p;
  }
  return out;
}

/// 자리가 필요한 할 일들을, 비는 시간에 맞춰 넣어 봐요.
/// 마감이 급한 순서 → 짧은 순서로, 좋아하는 시간대를 먼저 찾고 없으면 다른 시간대에서 찾아요.
/// [busyOn] 은 그날 이미 차 있는 시간들(종일 일정은 빼고)을 돌려줘요.
PlanResult planTodos(
  List<Todo> todos, {
  required DateTime now,
  required List<Span> Function(DateTime day) busyOn,
  DayPart? override,
  int dayStartHour = 9,
  int dayEndHour = 22,
}) {
  final today = dayOnly(now);
  final taken = <int, List<Span>>{};
  final items = <Proposal>[];
  final unplaced = <String, int>{};

  final list = todos.where((t) => t.needsPlan(now)).toList()
    ..sort((a, b) {
      final da = a.due ?? DateTime(2100);
      final db = b.due ?? DateTime(2100);
      final c = da.compareTo(db);
      if (c != 0) return c;
      return a.minutes.compareTo(b.minutes);
    });

  /// day 의 [fromH, toH) 안에서 len 분이 들어가는 첫 자리
  Span? find(DateTime day, int fromH, int toH, int len) {
    var a = DateTime(day.year, day.month, day.day, fromH);
    final b = DateTime(day.year, day.month, day.day, toH);
    if (sameDay(day, now) && now.isAfter(a)) a = ceilTo(now, 5);
    if (!b.isAfter(a)) return null;
    final blocked = _mergeSpans([...busyOn(day), ...(taken[dayKey(day)] ?? const <Span>[])]);
    var cursor = a;
    for (final s in blocked) {
      if (!s.b.isAfter(cursor)) continue;
      if (!s.a.isBefore(b)) break;
      if (s.a.isAfter(cursor)) {
        final start = ceilTo(cursor, 5);
        final end = start.add(Duration(minutes: len));
        if (!end.isAfter(s.a) && !end.isAfter(b)) return Span(start, end);
      }
      if (s.b.isAfter(cursor)) cursor = s.b;
    }
    final start = ceilTo(cursor, 5);
    final end = start.add(Duration(minutes: len));
    if (!end.isAfter(b)) return Span(start, end);
    return null;
  }

  for (final t in list) {
    var first = today;
    if (t.notBefore != null && t.notBefore!.isAfter(first)) first = dayOnly(t.notBefore!);
    final weekEnd = addDays(today, 7 - today.weekday);
    DateTime last;
    List<int> pieces;
    final perDay = t.perWeek > 0;
    if (perDay) {
      last = weekEnd;
      if (t.due != null && t.due!.isBefore(last)) last = dayOnly(t.due!);
      final span = daysBetween(first, last) + 1;
      final n = t.perWeek >= 7 ? (span > 0 ? span : 0) : (t.perWeek < span ? t.perWeek : span);
      pieces = List<int>.filled(n < 0 ? 0 : n, t.minutes);
    } else {
      last = t.due != null ? dayOnly(t.due!) : addDays(today, 13);
      pieces = _pieces(t, t.need > 0 ? t.need : t.minutes);
    }
    if (last.isBefore(first)) last = first;

    final part = override ?? t.part;
    final win = part.hours;
    final usedDays = <int>{};
    var missing = 0;

    for (var i = 0; i < pieces.length; i++) {
      final len = pieces[i];
      Span? got;
      DateTime? gotDay;

      Span? search({required bool unique, required bool preferred}) {
        var d = first;
        var guard = 0;
        while (!d.isAfter(last) && guard < 60) {
          guard++;
          if (!unique || !usedDays.contains(dayKey(d))) {
            final from = preferred && win != null ? win.$1 : dayStartHour;
            final to = preferred && win != null ? win.$2 : dayEndHour;
            final s = find(d, from, to, len);
            if (s != null) {
              gotDay = d;
              return s;
            }
          }
          d = addDays(d, 1);
        }
        return null;
      }

      got = search(unique: true, preferred: true);
      if (got == null && win != null) got = search(unique: true, preferred: false);
      if (got == null && !perDay) {
        got = search(unique: false, preferred: true);
        if (got == null && win != null) got = search(unique: false, preferred: false);
      }
      if (got == null || gotDay == null) {
        missing += len;
        continue;
      }
      usedDays.add(dayKey(gotDay!));
      taken.putIfAbsent(dayKey(gotDay!), () => <Span>[]).add(got);
      items.add(Proposal(
        todo: t,
        start: got.a,
        end: got.b,
        index: i + 1,
        count: perDay ? 1 : pieces.length,
      ));
    }
    if (missing > 0) unplaced[t.id] = missing;
  }
  items.sort((a, b) => a.start.compareTo(b.start));
  return PlanResult(items, unplaced);
}
