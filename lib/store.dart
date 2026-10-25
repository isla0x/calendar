import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dates.dart';
import 'demo_repo.dart';
import 'models.dart';
import 'repo.dart';

enum ViewMode { month, week, day }

/// 앱 상태 + 일정 계산(비는 시간, 바쁨 단계 등)
class CalendarStore extends ChangeNotifier {
  CalendarStore(this.repo, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    final t = dayOnly(_clock());
    selected = t;
    month = DateTime(t.year, t.month);
  }

  /// "비는 시간"을 계산하는 하루 범위 (9시 ~ 22시)
  static const int dayStartHour = 9;
  static const int dayEndHour = 22;

  CalendarRepo repo;
  final DateTime Function() _clock;

  PermState perm = PermState.unknown;

  /// 권한 상태를 처음 확인하는 일이 끝났는지 (끝나기 전엔 빈 화면)
  bool ready = false;
  bool loading = false;
  String? error;
  List<CalInfo> calendars = const <CalInfo>[];

  late DateTime selected;
  late DateTime month;
  ViewMode view = ViewMode.month;

  /// 오늘 화면에서 지난 일정을 펼쳤는지
  bool pastOpen = false;

  List<Ev> _events = const <Ev>[];
  Map<int, List<Ev>> _byDay = <int, List<Ev>>{};
  Map<int, String> _holidays = <int, String>{};
  DateTime? _from;
  DateTime? _to;
  Timer? _timer;

  DateTime get now => _clock();
  DateTime get today => dayOnly(_clock());
  bool get isDemo => repo.isDemo;

  // ---------------------------------------------------------------- 불러오기

  Future<void> init() async {
    try {
      perm = await repo.permission();
    } catch (_) {
      perm = PermState.unknown;
    }
    ready = true;
    if (perm == PermState.granted) {
      await _refresh(force: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    try {
      perm = await repo.requestPermission();
    } catch (_) {
      perm = PermState.denied;
    }
    if (perm == PermState.granted) {
      await _refresh(force: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> openSettings() => repo.openSettings();

  /// 권한 없이 샘플로 둘러보기
  Future<void> useDemo() async {
    repo = DemoRepo(clock: _clock);
    perm = PermState.granted;
    await _refresh(force: true);
  }

  /// 앱으로 돌아왔을 때 등, 다시 읽기
  Future<void> reload() async {
    if (perm != PermState.granted) {
      try {
        perm = await repo.permission();
      } catch (_) {}
    }
    if (perm == PermState.granted) {
      await _refresh(force: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> _refresh({DateTime? around, bool force = false}) async {
    final c = dayOnly(around ?? selected);
    final f = _from;
    final t = _to;
    if (!force &&
        f != null &&
        t != null &&
        !c.isBefore(addDays(f, 20)) &&
        c.isBefore(addDays(t, -20))) {
      return;
    }
    final from = addDays(DateTime(c.year, c.month), -50);
    final to = addDays(DateTime(c.year, c.month + 1), 50);
    loading = true;
    notifyListeners();
    try {
      calendars = await repo.calendars();
      _events = await repo.events(from, to);
      _from = from;
      _to = to;
      _index();
      error = null;
    } catch (e) {
      error = '일정을 불러오지 못했어요';
    }
    loading = false;
    notifyListeners();
  }

  void _index() {
    final idx = <int, List<Ev>>{};
    final hol = <int, String>{};
    for (final e in _events) {
      var d = dayOnly(e.start);
      final DateTime last;
      if (e.allDay) {
        last = addDays(dayOnly(e.end), -1);
      } else if (e.end.isAfter(e.start)) {
        last = dayOnly(e.end.subtract(const Duration(microseconds: 1)));
      } else {
        last = d;
      }
      var guard = 0;
      while (!d.isAfter(last) && guard < 62) {
        if (e.holiday) {
          hol[dayKey(d)] = e.title;
        } else {
          (idx[dayKey(d)] ??= <Ev>[]).add(e);
        }
        d = addDays(d, 1);
        guard++;
      }
    }
    for (final l in idx.values) {
      l.sort(_compare);
    }
    _byDay = idx;
    _holidays = hol;
  }

  static int _compare(Ev a, Ev b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    final c = a.start.compareTo(b.start);
    if (c != 0) return c;
    return a.title.compareTo(b.title);
  }

  // ---------------------------------------------------------------- 조회

  List<Ev> eventsOn(DateTime d) => _byDay[dayKey(d)] ?? const <Ev>[];

  String? holidayOn(DateTime d) => _holidays[dayKey(d)];

  /// 기간을 정해서 일정을 읽어와요 (검색용). 공휴일은 빼요.
  Future<List<Ev>> eventsBetween(DateTime from, DateTime to) async {
    final list = await repo.events(from, to);
    final out = list.where((e) => !e.holiday).toList();
    out.sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return out;
  }

  /// 방금 고친 일정을 다시 찾기. 같은 id 중 시작 시각이 같은 것을 먼저, 없으면 첫 번째.
  Ev? findEvent(String id, {DateTime? start}) {
    Ev? any;
    for (final e in _events) {
      if (e.id != id) continue;
      if (start != null && e.start == start) return e;
      any ??= e;
    }
    return any;
  }

  Span? _window(DateTime d, DateTime? from) {
    final day = dayOnly(d);
    var a = DateTime(day.year, day.month, day.day, dayStartHour);
    final b = DateTime(day.year, day.month, day.day, dayEndHour);
    if (from != null && from.isAfter(a)) a = from;
    if (!b.isAfter(a)) return null;
    return Span(a, b);
  }

  /// 일정이 차지한 시간(겹치면 합쳐서). skip 일정은 빼고 계산해요.
  List<Span> busySpans(DateTime d, {DateTime? from, Ev? skip}) {
    final w = _window(d, from);
    if (w == null) return const <Span>[];
    final raw = <Span>[];
    for (final e in eventsOn(d)) {
      if (e.allDay) continue;
      if (skip != null && e.instanceId == skip.instanceId) continue;
      final s = maxDate(e.start, w.a);
      final t = minDate(e.end, w.b);
      if (t.isAfter(s)) raw.add(Span(s, t));
    }
    raw.sort((x, y) => x.a.compareTo(y.a));
    final out = <Span>[];
    for (final s in raw) {
      if (out.isNotEmpty && !s.a.isAfter(out.last.b)) {
        if (s.b.isAfter(out.last.b)) {
          out[out.length - 1] = Span(out.last.a, s.b);
        }
      } else {
        out.add(s);
      }
    }
    return out;
  }

  /// 비는 시간 구간 (min 이상인 것만)
  List<Span> gaps(
    DateTime d, {
    DateTime? from,
    Duration min = const Duration(minutes: 30),
    Ev? skip,
  }) {
    final w = _window(d, from);
    if (w == null) return const <Span>[];
    final out = <Span>[];
    var cursor = w.a;
    for (final s in busySpans(d, from: from, skip: skip)) {
      if (s.a.isAfter(cursor) && s.a.difference(cursor) >= min) {
        out.add(Span(cursor, s.a));
      }
      if (s.b.isAfter(cursor)) cursor = s.b;
    }
    if (w.b.difference(cursor) >= min) out.add(Span(cursor, w.b));
    return out;
  }

  /// 비는 시간(분)
  int freeMinutes(DateTime d, {DateTime? from}) {
    final w = _window(d, from);
    if (w == null) return 0;
    var busy = 0;
    for (final s in busySpans(d, from: from)) {
      busy += s.length.inMinutes;
    }
    return w.length.inMinutes - busy;
  }

  /// 바쁨 단계 0~3 (월간 화면의 배경 진하기)
  int loadLevel(DateTime d) {
    final w = _window(d, null);
    if (w == null) return 0;
    var busy = 0;
    for (final s in busySpans(d)) {
      busy += s.length.inMinutes;
    }
    final f = busy / w.length.inMinutes;
    if (f >= 0.55) return 3;
    if (f >= 0.40) return 2;
    if (f >= 0.25) return 1;
    return 0;
  }

  /// 같은 날 안에서 need 길이가 들어가는 시간 (옮기기 추천)
  List<Slot> slotsOnDay(
    Duration need,
    DateTime day, {
    int count = 3,
    Ev? skip,
    DateTime? from,
  }) {
    final out = <Slot>[];
    for (final g in gaps(day, from: from, min: need, skip: skip)) {
      final s = ceilTo(g.a, 15);
      final e = s.add(need);
      if (!e.isAfter(g.b)) {
        if (skip != null && s == skip.start) continue;
        out.add(Slot(s, e));
        if (out.length >= count) break;
      }
    }
    return out;
  }

  /// 앞으로 며칠 동안 하루에 하나씩, 들어갈 만한 시간 (한 줄 입력의 "이 시간이 어렵다면")
  List<Slot> suggestAcrossDays(
    Duration need,
    DateTime fromDay, {
    int count = 3,
    int days = 10,
  }) {
    final out = <Slot>[];
    final n = now;
    for (var i = 0; i < days && out.length < count; i++) {
      final d = addDays(dayOnly(fromDay), i);
      if (d.isBefore(today)) continue;
      final from = sameDay(d, n) ? ceilTo(n, 15) : null;
      final s = slotsOnDay(need, d, count: 1, from: from);
      if (s.isNotEmpty) out.add(s.first);
    }
    return out;
  }

  // ---------------------------------------------------------------- 이동·선택

  void setView(ViewMode v) {
    if (view == v) return;
    view = v;
    notifyListeners();
  }

  void togglePast() {
    pastOpen = !pastOpen;
    notifyListeners();
  }

  void select(DateTime d) {
    final day = dayOnly(d);
    if (!sameDay(day, selected)) pastOpen = false;
    selected = day;
    if (day.month != month.month || day.year != month.year) {
      month = DateTime(day.year, day.month);
    }
    notifyListeners();
    unawaited(_refresh(around: day));
  }

  void shiftMonth(int delta) {
    month = DateTime(month.year, month.month + delta);
    final last = DateTime(month.year, month.month + 1, 0).day;
    selected =
        DateTime(month.year, month.month, selected.day > last ? last : selected.day);
    pastOpen = false;
    notifyListeners();
    unawaited(_refresh(around: selected));
  }

  void shiftWeek(int delta) => select(addDays(selected, 7 * delta));

  void shiftDay(int delta) => select(addDays(selected, delta));

  void goToday() => select(today);

  // ---------------------------------------------------------------- 저장·삭제

  Future<bool> addEvent({
    String? calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    List<String> tags = const <String>[],
  }) async {
    try {
      await repo.create(
        calendarId: calendarId,
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        location: location,
        tags: tags,
      );
      await _refresh(force: true);
      return true;
    } catch (e) {
      error = '일정을 저장하지 못했어요';
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveEvent(Ev e, DateTime start, DateTime end) async {
    try {
      await repo.move(e, start, end);
      await _refresh(force: true);
      return true;
    } catch (_) {
      error = '일정을 옮기지 못했어요';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setEventTags(Ev e, List<String> tags) async {
    try {
      await repo.setTags(e, tags);
      await _refresh(force: true);
      return true;
    } catch (_) {
      error = '태그를 바꾸지 못했어요';
      notifyListeners();
      return false;
    }
  }

  /// 지금 불러와 둔 일정들에서 쓰인 태그 (많이 쓴 순)
  List<String> knownTags() {
    final count = <String, int>{};
    for (final e in _events) {
      for (final t in e.tags) {
        count[t] = (count[t] ?? 0) + 1;
      }
    }
    final keys = count.keys.toList()
      ..sort((a, b) {
        final c = (count[b] ?? 0).compareTo(count[a] ?? 0);
        return c != 0 ? c : a.compareTo(b);
      });
    return keys;
  }

  Future<bool> deleteEvent(Ev e) async {
    try {
      await repo.delete(e);
      await _refresh(force: true);
      return true;
    } catch (_) {
      error = '일정을 지우지 못했어요';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------- 시계

  /// 지금 시각 표시를 갱신하려고 30초마다 화면을 새로 그려요.
  void startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
  }

  void stopClock() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }
}

/// 어디서든 store 를 꺼내 쓰기 위한 통로
class StoreScope extends InheritedNotifier<CalendarStore> {
  const StoreScope({
    super.key,
    required CalendarStore store,
    required super.child,
  }) : super(notifier: store);

  /// 다시 그리지 않고 한 번만 꺼낼 때 (initState 등)
  static CalendarStore read(BuildContext context) {
    final w = context.getInheritedWidgetOfExactType<StoreScope>();
    assert(w != null, 'StoreScope 가 위젯 트리 위쪽에 없어요');
    return w!.notifier!;
  }

  static CalendarStore of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(w != null, 'StoreScope 가 위젯 트리 위쪽에 없어요');
    return w!.notifier!;
  }
}
