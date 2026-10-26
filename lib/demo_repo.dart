import 'dates.dart';
import 'models.dart';
import 'repo.dart';
import 'skins.dart';
import 'tags.dart';
import 'l10n.dart';

class _T {
  const _T(this.h1, this.h2, this.title, this.cal, [this.loc]);
  final double h1;
  final double h2;
  final String title;
  final String cal;
  final String? loc;
}

/// 권한을 주기 전에 둘러볼 수 있는 샘플 데이터 (목업과 같은 구성)
class DemoRepo implements CalendarRepo {
  /// [project] 를 켜면 오늘을 가운데 둔 몇 주짜리 프로젝트(종일·여러 날) 일정이 하나 들어가요.
  DemoRepo({DateTime Function()? clock, bool project = false}) {
    final today = dayOnly((clock ?? DateTime.now)());
    _build(today);
    if (project) _addProject(today);
  }

  /// 일정 색은 지금 고른 색 조합(Skin)을 따라가요.
  final List<CalInfo> _cals = [
    CalInfo(id: 'work', name: tl('업무'), color: Skin.current.events[0]),
    CalInfo(id: 'personal', name: tl('개인'), color: Skin.current.events[1], isPrimary: true),
    CalInfo(id: 'meet', name: tl('약속'), color: Skin.current.events[2]),
    CalInfo(id: 'fit', name: tl('운동'), color: Skin.current.events[3]),
    CalInfo(id: 'study', name: tl('공부'), color: Skin.current.events[4]),
    CalInfo(
      id: 'holiday',
      name: tl('대한민국 공휴일'),
      color: Skin.current.holiday,
      readOnly: true,
    ),
  ];

  static Map<int, List<_T>> get _week => {
    1: [
      _T(9.5, 10.5, tl('주간 싱크 #회의'), 'work', tl('회의실 A')),
      _T(12, 13, tl('점심 약속 #약속'), 'meet'),
      _T(14.5, 15.5, tl('스프린트 플래닝 #회의'), 'work', tl('회의실 B')),
      _T(16.5, 17.5, tl('보고서 작성 #집중'), 'work', tl('집중 시간')),
      _T(19, 20, tl('러닝 #운동'), 'fit', tl('공원')),
      _T(21, 22, tl('영어 공부 #공부'), 'study', tl('온라인 수업')),
    ],
    2: [
      _T(9, 10, tl('디자인 리뷰 #회의'), 'work', tl('회의실 A')),
      _T(10.5, 12, tl('고객 인터뷰 #회의'), 'work'),
      _T(18.5, 20, tl('저녁 약속 #약속'), 'meet'),
    ],
    3: [
      _T(10, 11.5, tl('스프린트 리뷰 #회의'), 'work', tl('회의실 A')),
      _T(12.5, 13.5, tl('점심 약속 #약속'), 'meet'),
      _T(19, 20, tl('요가 #운동'), 'fit', tl('스튜디오')),
    ],
    4: [
      _T(9.5, 17.5, tl('오프사이트 워크숍 #집중'), 'work'),
      _T(19.5, 21, tl('영어 공부 #공부'), 'study', tl('온라인 수업')),
    ],
    5: [
      _T(10, 11, tl('1:1 미팅 #회의'), 'work'),
      _T(13, 14, tl('팀 점심 #약속'), 'work'),
      _T(18.5, 22, tl('저녁 약속 #약속'), 'meet'),
    ],
    6: [
      _T(11, 13, tl('브런치 #약속'), 'meet'),
      _T(15, 17, tl('산책 #운동'), 'personal'),
      _T(19, 22, tl('모임 #약속'), 'meet'),
    ],
    7: [
      _T(10.5, 12, tl('브런치 #약속'), 'personal'),
      _T(14, 15.5, tl('러닝 #운동'), 'fit', tl('공원')),
    ],
  };

  static Map<int, String> get _holidays => {
    101: tl('신정'),
    301: tl('삼일절'),
    505: tl('어린이날'),
    606: tl('현충일'),
    815: tl('광복절'),
    1003: tl('개천절'),
    1009: tl('한글날'),
    1225: tl('성탄절'),
  };

  final List<Ev> _evs = <Ev>[];
  int _seq = 0;

  CalInfo _calById(String id) =>
      _cals.firstWhere((c) => c.id == id, orElse: () => _cals.first);

  void _addProject(DateTime today) {
    final c = _calById('work');
    final n = _seq++;
    _evs.add(Ev(
      id: 'p$n',
      instanceId: 'p$n',
      calendarId: c.id,
      calendarName: c.name,
      title: tl('프로젝트 A'),
      tags: <String>[tl('프로젝트')],
      start: addDays(today, -38),
      end: addDays(today, 3),
      allDay: true,
      color: c.color,
    ));
  }

  void _build(DateTime today) {
    final from = addDays(today, -60);
    for (var i = 0; i < 200; i++) {
      final d = addDays(from, i);
      final tpl = _week[d.weekday] ?? const <_T>[];
      for (final t in tpl) {
        // 일요일 일정은 격주로만 있어요
        if (d.weekday == 7 && (d.day ~/ 7) % 2 == 1) continue;
        final c = _calById(t.cal);
        final s = d.add(Duration(minutes: (t.h1 * 60).round()));
        final e = d.add(Duration(minutes: (t.h2 * 60).round()));
        final n = _seq++;
        final parts = splitTags(t.title);
        _evs.add(Ev(
          id: 'd$n',
          instanceId: 'd$n',
          calendarId: c.id,
          calendarName: c.name,
          title: parts.title,
          tags: parts.tags,
          start: s,
          end: e,
          allDay: false,
          color: c.color,
          location: t.loc,
        ));
      }
      final h = _holidays[d.month * 100 + d.day];
      if (h != null) {
        final c = _calById('holiday');
        final n = _seq++;
        _evs.add(Ev(
          id: 'h$n',
          instanceId: 'h$n',
          calendarId: c.id,
          calendarName: c.name,
          title: h,
          start: d,
          end: addDays(d, 1),
          allDay: true,
          color: c.color,
          readOnly: true,
          holiday: true,
        ));
      }
    }
  }

  @override
  bool get isDemo => true;

  @override
  Future<PermState> permission() async => PermState.granted;

  @override
  Future<PermState> requestPermission() async => PermState.granted;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<CalInfo>> calendars() async => _cals;

  @override
  Future<List<Ev>> events(DateTime from, DateTime to) async {
    return _evs
        .where((e) => e.start.isBefore(to) && e.end.isAfter(from))
        .toList();
  }

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
  }) async {
    final c = _calById(calendarId ?? 'personal');
    final n = _seq++;
    final len = end.difference(start);

    Ev make(DateTime s, DateTime e, String inst) => Ev(
          id: 'n$n',
          instanceId: inst,
          calendarId: c.id,
          calendarName: c.name,
          title: title,
          start: s,
          end: e,
          allDay: allDay,
          color: c.color,
          location: location,
          tags: tags,
          recurring: repeat != null,
        );

    if (repeat == null) {
      _evs.add(make(start, end, 'n$n'));
      return 'n$n';
    }
    // 샘플 모드: 반복 일정을 날짜마다 풀어서 넣어요 (끝이 없으면 120일까지).
    final first = dayOnly(start);
    final last = repeat.until ?? addDays(first, 120);
    var d = first;
    var guard = 0;
    while (!d.isAfter(last) && guard < 400) {
      final wd = d.weekday;
      final ok = switch (repeat.kind) {
        RepeatKind.daily => true,
        RepeatKind.weekdays => wd <= 5,
        RepeatKind.weekly => wd == first.weekday,
        RepeatKind.days => repeat.days.contains(wd),
      };
      if (ok) {
        final s = DateTime(d.year, d.month, d.day, start.hour, start.minute);
        _evs.add(make(s, s.add(len), 'n$n@${dayKey(d)}'));
      }
      d = addDays(d, 1);
      guard++;
    }
    return 'n$n';
  }

  @override
  Future<void> move(Ev e, DateTime start, DateTime end) async {
    final i = _evs.indexWhere((x) => x.instanceId == e.instanceId);
    if (i >= 0) _evs[i] = _evs[i].copyWith(start: start, end: end);
  }

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
  }) async {
    final i = _evs.indexWhere((x) => x.instanceId == e.instanceId);
    if (i < 0) return;
    final o = _evs[i];
    final loc = (location ?? '').trim();
    final nt = (note ?? '').trim();
    _evs[i] = Ev(
      id: o.id,
      instanceId: o.instanceId,
      calendarId: o.calendarId,
      calendarName: o.calendarName,
      title: title,
      start: start,
      end: end,
      allDay: allDay,
      color: o.color,
      location: loc.isEmpty ? null : loc,
      note: nt.isEmpty ? null : nt,
      attendees: o.attendees,
      recurring: o.recurring,
      readOnly: o.readOnly,
      holiday: o.holiday,
      reminders: o.reminders,
      tags: tags,
    );
  }

  @override
  Future<void> setTags(Ev e, List<String> tags) async {
    final i = _evs.indexWhere((x) => x.instanceId == e.instanceId);
    if (i >= 0) _evs[i] = _evs[i].copyWith(tags: tags);
  }

  @override
  Future<void> delete(Ev e, {DeleteScope scope = DeleteScope.one}) async {
    switch (scope) {
      case DeleteScope.one:
        _evs.removeWhere((x) => x.instanceId == e.instanceId);
      case DeleteScope.following:
        _evs.removeWhere((x) => x.id == e.id && !x.start.isBefore(e.start));
      case DeleteScope.all:
        _evs.removeWhere((x) => x.id == e.id);
    }
  }

  @override
  Future<void> openEditor(Ev e) async {}
}
