import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';

/// 프로젝트 안의 체크포인트 (착수, 중간 보고, 최종 보고 …)
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.title,
    required this.date,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final bool done;

  Checkpoint copyWith({String? title, DateTime? date, bool? done}) => Checkpoint(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        done: done ?? this.done,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'date': dayKey(date),
        'done': done,
      };

  static Checkpoint? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    final date = _fromKey(j['date']);
    if (id is! String || title is! String || date == null) return null;
    return Checkpoint(id: id, title: title, date: date, done: j['done'] == true);
  }
}

DateTime? _fromKey(Object? v) {
  if (v is! int) return null;
  return DateTime(v ~/ 10000, (v ~/ 100) % 100, v % 100);
}

enum ProjectStatus { upcoming, active, done }

/// 프로젝트 하나. 일정과는 [eventIds] 로 따로 이어 두어서, 태그와 상관없이 묶여요.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.colorValue,
    this.rest = const <int>{6, 7},
    this.checkpoints = const <Checkpoint>[],
    this.eventIds = const <String>{},
    this.timeText = '종일',
    this.cells = false,
  });

  final String id;
  final String name;

  /// 첫날, 마지막 날 (둘 다 포함, 날짜만)
  final DateTime start;
  final DateTime end;
  final int colorValue;

  /// 쉬는 요일 (월=1 … 일=7)
  final Set<int> rest;
  final List<Checkpoint> checkpoints;

  /// 이 프로젝트에 넣은 일정들의 id
  final Set<String> eventIds;

  /// 카드에 보여줄 시간 설명 (예: "매일 09:00 – 18:00", "종일")
  final String timeText;

  /// 근무일마다 칸으로 보여줄지 (아니면 이어진 막대)
  final bool cells;

  Color get color => Color(colorValue);

  Project copyWith({
    String? name,
    DateTime? start,
    DateTime? end,
    int? colorValue,
    Set<int>? rest,
    List<Checkpoint>? checkpoints,
    Set<String>? eventIds,
    String? timeText,
    bool? cells,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        start: start ?? this.start,
        end: end ?? this.end,
        colorValue: colorValue ?? this.colorValue,
        rest: rest ?? this.rest,
        checkpoints: checkpoints ?? this.checkpoints,
        eventIds: eventIds ?? this.eventIds,
        timeText: timeText ?? this.timeText,
        cells: cells ?? this.cells,
      );

  bool isRestDay(DateTime d) => rest.contains(d.weekday);

  bool contains(DateTime d) {
    final x = dayOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  /// 쉬는 요일을 뺀 날들
  List<DateTime> get workDays {
    final out = <DateTime>[];
    var d = start;
    var guard = 0;
    while (!d.isAfter(end) && guard < 800) {
      if (!rest.contains(d.weekday)) out.add(d);
      d = addDays(d, 1);
      guard++;
    }
    return out;
  }

  int get totalDays => workDays.length;

  ProjectStatus statusOn(DateTime today) {
    final t = dayOnly(today);
    if (t.isBefore(start)) return ProjectStatus.upcoming;
    if (t.isAfter(end)) return ProjectStatus.done;
    return ProjectStatus.active;
  }

  /// 오늘이 몇 번째 근무일인지 (시작 전 0, 끝난 뒤 전체)
  int dayNumber(DateTime today) {
    final t = dayOnly(today);
    var n = 0;
    for (final d in workDays) {
      if (!d.isAfter(t)) n++;
    }
    return n;
  }

  int remainingDays(DateTime today) => totalDays - dayNumber(today);

  /// 끝나는 날까지 며칠 (끝난 뒤엔 음수)
  int dDay(DateTime today) => daysBetween(dayOnly(today), end);

  /// 0.0 ~ 1.0
  double progress(DateTime today) {
    final total = totalDays;
    if (total == 0) return 0;
    return (dayNumber(today) / total).clamp(0.0, 1.0);
  }

  /// 아직 안 끝났고 오늘 이후(오늘 포함)인 가장 가까운 체크포인트
  Checkpoint? nextCheckpoint(DateTime today) {
    final t = dayOnly(today);
    Checkpoint? best;
    for (final c in checkpoints) {
      if (c.done || c.date.isBefore(t)) continue;
      if (best == null || c.date.isBefore(best.date)) best = c;
    }
    return best;
  }

  String dDayLabel(DateTime today) {
    final n = dDay(today);
    if (n == 0) return 'D-Day';
    return n > 0 ? 'D-$n' : 'D+${-n}';
  }

  String get rangeText =>
      '${start.month}/${start.day} – ${end.month}/${end.day}';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'start': dayKey(start),
        'end': dayKey(end),
        'color': colorValue,
        'rest': rest.toList()..sort(),
        'cps': [for (final c in checkpoints) c.toJson()],
        'events': eventIds.toList(),
        'time': timeText,
        'cells': cells,
      };

  static Project? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final name = j['name'];
    final start = _fromKey(j['start']);
    final end = _fromKey(j['end']);
    final color = j['color'];
    if (id is! String || name is! String || start == null || end == null || color is! int) {
      return null;
    }
    final cps = <Checkpoint>[];
    final rawCps = j['cps'];
    if (rawCps is List) {
      for (final x in rawCps) {
        final c = Checkpoint.fromJson(x);
        if (c != null) cps.add(c);
      }
    }
    final rest = <int>{};
    final rawRest = j['rest'];
    if (rawRest is List) {
      for (final x in rawRest) {
        if (x is int && x >= 1 && x <= 7) rest.add(x);
      }
    }
    final ev = <String>{};
    final rawEv = j['events'];
    if (rawEv is List) {
      for (final x in rawEv) {
        if (x is String) ev.add(x);
      }
    }
    return Project(
      id: id,
      name: name,
      start: start,
      end: end.isBefore(start) ? start : end,
      colorValue: color,
      rest: rest,
      checkpoints: cps,
      eventIds: ev,
      timeText: j['time'] is String ? j['time'] as String : '종일',
      cells: j['cells'] == true,
    );
  }
}

/// 프로젝트를 기억해 두는 곳
abstract class ProjectBook {
  List<Project> load();
  Future<void> save(List<Project> all);
}

/// 저장 없이 메모리에만 (테스트·샘플용)
class MemoryProjectBook implements ProjectBook {
  MemoryProjectBook([List<Project>? initial]) : _all = List<Project>.of(initial ?? const <Project>[]);

  List<Project> _all;

  @override
  List<Project> load() => List<Project>.of(_all);

  @override
  Future<void> save(List<Project> all) async {
    _all = List<Project>.of(all);
  }
}

/// 기기에 저장 (앱을 껐다 켜도 남아요)
class PrefsProjectBook implements ProjectBook {
  PrefsProjectBook._(this._prefs, this._all);

  static const String _key = 'projects_v1';

  final SharedPreferences _prefs;
  List<Project> _all;

  static Future<ProjectBook> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final all = <Project>[];
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is List) {
          for (final x in j) {
            final p = Project.fromJson(x);
            if (p != null) all.add(p);
          }
        }
      }
      return PrefsProjectBook._(prefs, all);
    } catch (_) {
      return MemoryProjectBook();
    }
  }

  @override
  List<Project> load() => List<Project>.of(_all);

  @override
  Future<void> save(List<Project> all) async {
    _all = List<Project>.of(all);
    try {
      await _prefs.setString(_key, jsonEncode([for (final p in all) p.toJson()]));
    } catch (_) {}
  }
}
