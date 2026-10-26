import 'dart:async';

import 'package:flutter/widgets.dart';

import 'color_book.dart';
import 'dates.dart';
import 'demo_repo.dart';
import 'flags.dart';
import 'models.dart';
import 'pro.dart';
import 'projects.dart';
import 'repo.dart';
import 'todos.dart';
import 'travel.dart';
import 'l10n.dart';

enum ViewMode { month, week, day }

/// 앱 상태 + 일정 계산(비는 시간, 바쁨 단계 등)
class CalendarStore extends ChangeNotifier {
  CalendarStore(
    this.repo, {
    DateTime Function()? clock,
    ColorBook? colors,
    ProjectBook? projects,
    TodoBook? todos,
    TravelBook? travel,
    AppFlags? flags,
    ProState? pro,
  })  : _clock = clock ?? DateTime.now,
        _colors = colors ?? MemoryColorBook(),
        _projectBook = projects ?? MemoryProjectBook(),
        _todoBook = todos ?? MemoryTodoBook(),
        flags = flags ?? MemoryFlags(),
        pro = pro ?? ProState(),
        _travel = travel ?? MemoryTravelBook() {
    _projects = _projectBook.load();
    _todos = _todoBook.load();
    final t = dayOnly(_clock());
    selected = t;
    month = DateTime(t.year, t.month);
  }

  /// "비는 시간"을 계산하는 하루 범위 (9시 ~ 22시)
  static const int dayStartHour = 9;
  static const int dayEndHour = 22;

  CalendarRepo repo;
  final DateTime Function() _clock;

  /// 일정마다 따로 고른 색
  ColorBook _colors;

  /// 작은 표시들(처음 안내를 봤는지 등)
  final AppFlags flags;

  /// Pro 결제 상태
  final ProState pro;

  /// 일정마다 정한 이동시간
  TravelBook _travel;

  /// 프로젝트 저장소와 목록
  ProjectBook _projectBook;
  List<Project> _projects = const <Project>[];

  /// 할 일 저장소와 목록
  TodoBook _todoBook;
  List<Todo> _todos = const <Todo>[];

  /// 방금 만든 일정의 id (프로젝트에 이어 줄 때 써요)
  String? lastCreatedId;

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
      _events = _tint(await repo.events(from, to));
      _from = from;
      _to = to;
      _index();
      _syncTodoSlots();
      error = null;
    } catch (e) {
      error = tl('일정을 불러오지 못했어요');
    }
    loading = false;
    notifyListeners();
  }

  /// 일정마다 따로 고른 색이 있으면 그 색으로 바꿔요.
  List<Ev> _tint(List<Ev> list) {
    return [
      for (final e in list)
        if (_colors.of(e.id) case final c?) e.copyWith(color: c) else e,
    ];
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
    final list = _tint(await repo.events(from, to));
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
      final tr = _travel.of(e.id);
      final s = maxDate(e.start.subtract(Duration(minutes: tr.before)), w.a);
      final t = minDate(e.end.add(Duration(minutes: tr.after)), w.b);
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

  /// [a]~[b] 날짜의 일정을 이미 읽어 왔는지 (위젯 자료를 만들어도 되는지 확인용)
  bool coversDays(DateTime a, DateTime b) {
    final f = _from;
    final t = _to;
    if (f == null || t == null) return false;
    return !dayOnly(a).isBefore(f) && dayOnly(b).isBefore(t);
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
    Travel travel = Travel.none,
  }) {
    final out = <Slot>[];
    final pad = Duration(minutes: travel.before + travel.after);
    for (final g in gaps(day, from: from, min: need + pad, skip: skip)) {
      final s = ceilTo(g.a, 15).add(Duration(minutes: travel.before));
      final e = s.add(need);
      if (!e.add(Duration(minutes: travel.after)).isAfter(g.b)) {
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
    Travel travel = Travel.none,
  }) {
    final out = <Slot>[];
    final n = now;
    for (var i = 0; i < days && out.length < count; i++) {
      final d = addDays(dayOnly(fromDay), i);
      if (d.isBefore(today)) continue;
      final from = sameDay(d, n) ? ceilTo(n, 15) : null;
      final s = slotsOnDay(need, d, count: 1, from: from, travel: travel);
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
    Repeat? repeat,
    Color? color,
  }) async {
    try {
      final id = await repo.create(
        calendarId: calendarId,
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        location: location,
        tags: tags,
        repeat: repeat,
      );
      lastCreatedId = id;
      if (color != null && id != null) await _colors.set(id, color);
      await _refresh(force: true);
      return true;
    } catch (e) {
      error = tl('일정을 저장하지 못했어요');
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
      error = tl('일정을 옮기지 못했어요');
      notifyListeners();
      return false;
    }
  }

  /// 일정을 고쳐서 저장해요. 성공하면 true.
  Future<bool> updateEvent(
    Ev e, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String? location,
    String? note,
    List<String> tags = const <String>[],
  }) async {
    try {
      await repo.update(
        e,
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        location: location,
        note: note,
        tags: tags,
      );
      await _refresh(force: true);
      return true;
    } catch (_) {
      error = tl('일정을 저장하지 못했어요');
      notifyListeners();
      return false;
    }
  }

  /// 이 일정만 다른 색으로 (null 이면 캘린더 색으로 되돌려요)
  Future<void> setEventColor(Ev e, Color? color) async {
    await _colors.set(e.id, color);
    await _refresh(force: true);
  }

  /// 이 일정에 따로 고른 색 (없으면 null)
  Color? customColorOf(Ev e) => _colors.of(e.id);

  /// 이 일정의 이동시간 (없으면 Travel.none)
  Travel travelOf(Ev e) => _travel.of(e.id);

  /// 이동시간을 정해요 (반복 일정이면 같은 반복 전체에 적용돼요)
  Future<void> setEventTravel(Ev e, Travel t) async {
    await _travel.set(e.id, t);
    notifyListeners();
  }

  /// 새로 만든 일정에 이동시간을 붙여요 (아직 목록에 없을 수 있어서 id 로)
  Future<void> setTravelById(String id, Travel t) async {
    await _travel.set(id, t);
    notifyListeners();
  }

  Future<bool> setEventTags(Ev e, List<String> tags) async {
    try {
      await repo.setTags(e, tags);
      await _refresh(force: true);
      return true;
    } catch (_) {
      error = tl('태그를 바꾸지 못했어요');
      notifyListeners();
      return false;
    }
  }

  /// 화면에서 이 태그가 붙은 일정만 또렷하게 보여줘요 (없으면 전체)
  String? _tagFilter;
  String? get tagFilter => _tagFilter;

  void setTagFilter(String? tag) {
    if (_tagFilter == tag) return;
    _tagFilter = tag;
    notifyListeners();
  }

  /// 걸러보기 중일 때, 이 일정이 고른 태그에 해당하는지
  bool tagMatch(Ev e) => _tagFilter == null || e.tags.contains(_tagFilter);

  /// 프로젝트 안에 든 "속 일정"인지. 프로젝트 자체(이름이 같은 일정)는 달력에 그대로 보이고,
  /// 그 안에 넣은 다른 일정들만 바깥 화면에서 숨겨요 (프로젝트 화면에서만 보여줘요).
  bool inProject(Ev e) {
    for (final p in _projects) {
      if (p.eventIds.contains(e.id)) return e.title.trim() != p.name.trim();
    }
    return false;
  }

  /// 프로젝트 자체(프로젝트와 이름이 같은 일정)인지. 눌렀을 때 프로젝트 화면으로 가요.
  Project? projectSelfOf(Ev e) {
    for (final p in _projects) {
      if (p.eventIds.contains(e.id) && e.title.trim() == p.name.trim()) return p;
    }
    return null;
  }

  /// 그날 이 프로젝트 안에 넣은 속 일정 (프로젝트 자체는 빼고)
  List<Ev> innerEventsOn(Project p, DateTime d) {
    return eventsOn(d)
        .where((e) => !e.allDay && p.eventIds.contains(e.id) && e.title.trim() != p.name.trim())
        .toList();
  }

  /// 그날의 일정 중 바깥 화면에 늘어놓을 것 (프로젝트 안 일정은 뺀 것)
  List<Ev> listedOn(DateTime d) {
    final all = eventsOn(d);
    if (_projects.isEmpty) return all;
    return all.where((e) => !inProject(e)).toList();
  }

  /// 그날의 일정 중 화면에 보여줄 것 (태그로 걸러보는 중이면 그 태그만)
  List<Ev> shownOn(DateTime d) {
    final all = listedOn(d);
    if (_tagFilter == null) return all;
    return all.where(tagMatch).toList();
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

  Future<bool> deleteEvent(Ev e, {DeleteScope scope = DeleteScope.one}) async {
    try {
      await repo.delete(e, scope: scope);
      await _refresh(force: true);
      return true;
    } catch (_) {
      error = tl('일정을 지우지 못했어요');
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------- 프로젝트

  List<Project> get projects => List<Project>.unmodifiable(_projects);

  Project? projectById(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 이 일정이 들어 있는 프로젝트 (없으면 null)
  Project? projectOf(Ev e) {
    for (final p in _projects) {
      if (p.eventIds.contains(e.id)) return p;
    }
    return null;
  }

  /// 지금 진행 중인 프로젝트 중 가장 먼저 끝나는 것 (월 화면 위 띠에 보여줘요)
  Project? get currentProject {
    Project? best;
    for (final p in _projects) {
      if (p.statusOn(today) != ProjectStatus.active) continue;
      if (best == null || p.end.isBefore(best.end)) best = p;
    }
    return best;
  }

  Future<void> _saveProjects(List<Project> next) async {
    _projects = next;
    notifyListeners();
    await _projectBook.save(next);
  }

  String newProjectId() => 'p${DateTime.now().microsecondsSinceEpoch}';

  /// 새 프로젝트를 저장하거나, 같은 id 가 있으면 바꿔 저장해요.
  Future<void> saveProject(Project p) async {
    final next = List<Project>.of(_projects);
    final i = next.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      next[i] = p;
    } else {
      next.add(p);
    }
    await _saveProjects(next);
  }

  Future<void> deleteProject(String id) async {
    await _saveProjects(_projects.where((p) => p.id != id).toList());
  }

  /// 일정 하나를 프로젝트에 넣거나(projectId), 빼요(null). 한 일정은 한 프로젝트에만 있어요.
  Future<void> setEventProject(Ev e, String? projectId) async {
    final next = <Project>[];
    for (final p in _projects) {
      final ids = Set<String>.of(p.eventIds)..remove(e.id);
      if (p.id == projectId) ids.add(e.id);
      next.add(ids.length == p.eventIds.length && p.id != projectId ? p : p.copyWith(eventIds: ids));
    }
    await _saveProjects(next);
  }

  /// 프로젝트에 일정 id 여러 개를 한꺼번에 넣어요.
  Future<void> addEventIdsToProject(String projectId, Iterable<String> ids) async {
    final p = projectById(projectId);
    if (p == null) return;
    final all = Set<String>.of(ids);
    final next = <Project>[];
    for (final x in _projects) {
      if (x.id == projectId) {
        next.add(x.copyWith(eventIds: {...x.eventIds, ...all}));
      } else {
        next.add(x.copyWith(eventIds: x.eventIds.difference(all)));
      }
    }
    await _saveProjects(next);
  }

  /// 프로젝트에 넣은 일정들 (기간 안, 시간순). 기기에서 새로 읽어와요.
  Future<List<Ev>> projectEvents(Project p) async {
    if (p.eventIds.isEmpty) return const <Ev>[];
    final list = await eventsBetween(p.start, addDays(p.end, 1));
    return list.where((e) => p.eventIds.contains(e.id)).toList();
  }

  /// 아직 어느 프로젝트에도 안 들어간, 프로젝트 기간 안의 일정들 (묶음 반복은 하나로)
  Future<List<Ev>> unlinkedEventsIn(Project p) async {
    final list = await eventsBetween(p.start, addDays(p.end, 1));
    final seen = <String>{};
    final out = <Ev>[];
    for (final e in list) {
      if (e.readOnly || e.holiday) continue;
      if (projectOf(e) != null) continue;
      if (!seen.add(e.id)) continue;
      out.add(e);
    }
    return out;
  }

  /// 오늘부터 앞으로 최대 [n] 근무일의 하루 평균 비는 시간(분). 불러온 일정 범위 안에서만 계산해요.
  int avgFreeMinutes(Project p, {int n = 7}) {
    var sum = 0;
    var cnt = 0;
    for (final d in p.workDays) {
      if (d.isBefore(today)) continue;
      if (cnt >= n) break;
      sum += freeMinutes(d);
      cnt++;
    }
    return cnt == 0 ? 0 : sum ~/ cnt;
  }

  // ---------------------------------------------------------------- 할 일

  List<Todo> get todos => List<Todo>.unmodifiable(_todos);

  Todo? todoById(String id) {
    for (final t in _todos) {
      if (t.id == id) return t;
    }
    return null;
  }

  String newTodoId() => 't${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _saveTodos(List<Todo> next) async {
    _todos = next;
    notifyListeners();
    await _todoBook.save(next);
  }

  Future<void> saveTodo(Todo t) async {
    final next = List<Todo>.of(_todos);
    final i = next.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      next[i] = t;
    } else {
      next.add(t);
    }
    await _saveTodos(next);
  }

  Future<void> deleteTodo(String id) async {
    await _saveTodos(_todos.where((t) => t.id != id).toList());
  }

  Future<void> setTodoDone(String id, bool done) async {
    final t = todoById(id);
    if (t == null) return;
    await saveTodo(t.copyWith(done: done, doneAt: done ? now : null));
  }

  /// 캘린더에서 일정을 옮기거나 지웠으면, 할 일의 자리도 거기에 맞춰요.
  /// (옮겼으면 새 시간으로, 지웠으면 자리를 비워서 다시 찾게 해요.)
  void _syncTodoSlots() {
    final f = _from;
    final t = _to;
    if (f == null || t == null || _todos.isEmpty) return;
    var changed = false;
    final next = <Todo>[];
    for (final todo in _todos) {
      if (todo.slots.isEmpty) {
        next.add(todo);
        continue;
      }
      final slots = <TodoSlot>[];
      for (final s in todo.slots) {
        if (s.start.isBefore(addDays(f, 1)) || s.start.isAfter(addDays(t, -1))) {
          slots.add(s);
          continue;
        }
        Ev? hit;
        for (final e in _events) {
          if (e.id == s.eventId) {
            if (hit == null || (e.start.difference(s.start)).abs() < (hit.start.difference(s.start)).abs()) {
              hit = e;
            }
          }
        }
        if (hit == null) {
          changed = true;
          continue;
        }
        if (hit.start != s.start || hit.end != s.end) {
          changed = true;
          slots.add(s.copyWith(start: hit.start, end: hit.end));
        } else {
          slots.add(s);
        }
      }
      next.add(slots.length == todo.slots.length && !changed ? todo : todo.copyWith(slots: slots));
    }
    if (changed) {
      _todos = next;
      _todoBook.save(next);
    }
  }

  /// 자리가 필요한 할 일들을 비는 시간에 맞춰 넣어 본 결과 (아직 캘린더에는 안 넣어요)
  PlanResult planTodoSlots({DayPart? override, List<Todo>? only}) {
    return planTodos(
      only ?? _todos,
      now: now,
      override: override,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
      busyOn: (d) => [
        for (final e in eventsOn(d))
          if (!e.allDay && e.end.isAfter(e.start))
            Span(
              e.start.subtract(Duration(minutes: _travel.of(e.id).before)),
              e.end.add(Duration(minutes: _travel.of(e.id).after)),
            ),
      ],
    );
  }

  /// 제안한 자리를 캘린더 일정으로 만들고 할 일과 이어요. 만든 일정 수를 돌려줘요.
  Future<int> applyProposals(List<Proposal> items) async {
    var made = 0;
    final slots = <String, List<TodoSlot>>{};
    final createdIds = <String>[];
    for (final it in items) {
      final title = it.count > 1 ? '${it.todo.title} ${it.index}/${it.count}' : it.todo.title;
      final ok = await addEvent(
        title: title,
        start: it.start,
        end: it.end,
        tags: it.todo.tags,
      );
      final id = lastCreatedId;
      if (ok && id != null) {
        made++;
        createdIds.add(id);
        slots.putIfAbsent(it.todo.id, () => <TodoSlot>[]).add(
              TodoSlot(eventId: id, start: it.start, end: it.end),
            );
      }
    }
    final next = <Todo>[];
    for (final t in _todos) {
      final add = slots[t.id];
      next.add(add == null ? t : t.copyWith(slots: [...t.slots, ...add], need: 0, clearNotBefore: true));
    }
    await _saveTodos(next);
    if (createdIds.isNotEmpty) {
      undo = (eventIds: createdIds, until: now.add(const Duration(seconds: 20)));
      notifyListeners();
    }
    return made;
  }

  /// 끝난 시간 중 아직 "다 했어요?" 하고 안 물어본 가장 최근 것
  ({Todo todo, TodoSlot slot})? get todoQuestion {
    ({Todo todo, TodoSlot slot})? best;
    for (final t in _todos) {
      if (t.done) continue;
      for (final s in t.slots) {
        if (s.asked || s.end.isAfter(now)) continue;
        if (best == null || s.end.isAfter(best.slot.end)) best = (todo: t, slot: s);
      }
    }
    return best;
  }

  /// 끝난 시간에 대한 대답. [more] 면 그만큼 더 자리를 찾고, [postpone] 이면 내일 이후로 미뤄요.
  Future<void> answerTodo(
    String todoId,
    String eventId, {
    bool done = false,
    int more = 0,
    bool postpone = false,
  }) async {
    final t = todoById(todoId);
    if (t == null) return;
    final slots = [
      for (final s in t.slots) s.eventId == eventId ? s.copyWith(asked: true) : s,
    ];
    var next = t.copyWith(slots: slots);
    if (done) {
      next = next.copyWith(done: true, doneAt: now);
    } else if (postpone) {
      final slot = t.slots.firstWhere((s) => s.eventId == eventId, orElse: () => t.slots.first);
      next = next.copyWith(need: slot.minutes, notBefore: addDays(today, 1));
    } else if (more > 0) {
      next = next.copyWith(need: more);
    }
    await saveTodo(next);
  }

  // ---------------------------------------------------------------- 후보 · 되돌리기

  List<Proposal> _candidates = const <Proposal>[];

  /// 자리 찾기 결과 중 아직 캘린더에 안 넣고 "후보"로만 보여주는 것들
  List<Proposal> get candidates => List<Proposal>.unmodifiable(_candidates);

  /// 후보를 일간 화면에 점선으로 보여줘요 (첫 후보가 있는 날로 이동).
  void showCandidates(List<Proposal> items) {
    _candidates = List<Proposal>.of(items);
    if (_candidates.isNotEmpty) {
      view = ViewMode.day;
      final first = _candidates.map((x) => x.start).reduce((a, b) => a.isBefore(b) ? a : b);
      select(first);
    } else {
      notifyListeners();
    }
  }

  void removeCandidate(Proposal x) {
    _candidates = _candidates.where((c) => c != x).toList();
    notifyListeners();
  }

  void clearCandidates() {
    if (_candidates.isEmpty) return;
    _candidates = const <Proposal>[];
    notifyListeners();
  }

  /// 후보를 캘린더에 넣어요. 만든 일정 수.
  Future<int> confirmCandidates() async {
    final items = _candidates;
    _candidates = const <Proposal>[];
    notifyListeners();
    return applyProposals(items);
  }

  /// 방금 넣은 일정들 (되돌리기용)
  ({List<String> eventIds, DateTime until})? undo;

  /// 방금 한 번에 넣은 일정들을 지우고 할 일을 "자리 찾기 전" 으로 돌려놔요.
  Future<void> undoLast() async {
    final u = undo;
    if (u == null) return;
    undo = null;
    final ids = u.eventIds.toSet();
    for (final id in ids) {
      final e = findEvent(id);
      if (e != null) {
        try {
          await repo.delete(e);
        } catch (_) {}
      }
    }
    final next = <Todo>[];
    for (final t in _todos) {
      final gone = t.slots.where((s) => ids.contains(s.eventId)).toList();
      if (gone.isEmpty) {
        next.add(t);
        continue;
      }
      final mins = gone.fold<int>(0, (a, s) => a + s.minutes);
      next.add(t.copyWith(
        slots: t.slots.where((s) => !ids.contains(s.eventId)).toList(),
        need: t.need + mins,
      ));
    }
    await _saveTodos(next);
    await _refresh(force: true);
  }

  void dismissUndo() {
    if (undo == null) return;
    undo = null;
    notifyListeners();
  }

  /// 이 일정이 이어져 있는 할 일 (없으면 null) 과 그 자리
  ({Todo todo, TodoSlot slot})? todoForEvent(Ev e) {
    for (final t in _todos) {
      for (final s in t.slots) {
        if (s.eventId == e.id) return (todo: t, slot: s);
      }
    }
    return null;
  }

  /// 일정 옆 동그라미: 이 자리에서 끝냈다고 표시해요. 모든 자리가 끝나면 할 일도 끝나요.
  Future<void> toggleSlotDone(Ev e) async {
    final hit = todoForEvent(e);
    if (hit == null) return;
    final on = !hit.slot.done;
    final slots = [
      for (final s in hit.todo.slots)
        s.eventId == e.id ? s.copyWith(done: on, asked: true) : s,
    ];
    final all = slots.every((s) => s.done) && hit.todo.need <= 0;
    var next = hit.todo.copyWith(slots: slots, done: all);
    if (all && !hit.todo.done) next = next.copyWith(doneAt: now);
    await saveTodo(next);
  }

  // ---------------------------------------------------------------- 백업 · 복원

  /// 백업을 가져온 뒤, 기기에 새로 쓴 값을 다시 읽어요.
  Future<void> replaceBooks({
    required ColorBook colors,
    required ProjectBook projects,
    required TodoBook todos,
    required TravelBook travel,
  }) async {
    _colors = colors;
    _projectBook = projects;
    _todoBook = todos;
    _travel = travel;
    _projects = _projectBook.load();
    _todos = _todoBook.load();
    notifyListeners();
    await _refresh(force: true);
  }

  // ---------------------------------------------------------------- 이동시간 장소 기억

  /// 이 장소에 기억해 둔 이동시간 (없으면 Travel.none)
  Travel travelForPlace(String place) => _travel.ofPlace(place);

  /// 자주 가는 곳 (기억해 둔 장소, 최근 쓴 순서)
  List<(String, Travel)> get knownPlaces => _travel.places();

  /// 이 장소의 이동시간을 기억해요 (null 이면 잊어요)
  Future<void> rememberPlace(String place, Travel? t) async {
    await _travel.setPlace(place, t);
    notifyListeners();
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
