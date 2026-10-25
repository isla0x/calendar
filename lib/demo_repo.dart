import 'dates.dart';
import 'models.dart';
import 'repo.dart';
import 'skins.dart';
import 'tags.dart';

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
    CalInfo(id: 'work', name: '업무', color: Skin.current.events[0]),
    CalInfo(id: 'personal', name: '개인', color: Skin.current.events[1], isPrimary: true),
    CalInfo(id: 'meet', name: '약속', color: Skin.current.events[2]),
    CalInfo(id: 'fit', name: '운동', color: Skin.current.events[3]),
    CalInfo(id: 'study', name: '공부', color: Skin.current.events[4]),
    CalInfo(
      id: 'holiday',
      name: '대한민국 공휴일',
      color: Skin.current.holiday,
      readOnly: true,
    ),
  ];

  static const Map<int, List<_T>> _week = {
    1: [
      _T(9.5, 10.5, '주간 싱크 #회의', 'work', '회의실 A'),
      _T(12, 13, '점심 약속 #약속', 'meet'),
      _T(14.5, 15.5, '스프린트 플래닝 #회의', 'work', '회의실 B'),
      _T(16.5, 17.5, '보고서 작성 #집중', 'work', '집중 시간'),
      _T(19, 20, '러닝 #운동', 'fit', '공원'),
      _T(21, 22, '영어 공부 #공부', 'study', '온라인 수업'),
    ],
    2: [
      _T(9, 10, '디자인 리뷰 #회의', 'work', '회의실 A'),
      _T(10.5, 12, '고객 인터뷰 #회의', 'work'),
      _T(18.5, 20, '저녁 약속 #약속', 'meet'),
    ],
    3: [
      _T(10, 11.5, '스프린트 리뷰 #회의', 'work', '회의실 A'),
      _T(12.5, 13.5, '점심 약속 #약속', 'meet'),
      _T(19, 20, '요가 #운동', 'fit', '스튜디오'),
    ],
    4: [
      _T(9.5, 17.5, '오프사이트 워크숍 #집중', 'work'),
      _T(19.5, 21, '영어 공부 #공부', 'study', '온라인 수업'),
    ],
    5: [
      _T(10, 11, '1:1 미팅 #회의', 'work'),
      _T(13, 14, '팀 점심 #약속', 'work'),
      _T(18.5, 22, '저녁 약속 #약속', 'meet'),
    ],
    6: [
      _T(11, 13, '브런치 #약속', 'meet'),
      _T(15, 17, '산책 #운동', 'personal'),
      _T(19, 22, '모임 #약속', 'meet'),
    ],
    7: [
      _T(10.5, 12, '브런치 #약속', 'personal'),
      _T(14, 15.5, '러닝 #운동', 'fit', '공원'),
    ],
  };

  static const Map<int, String> _holidays = {
    101: '신정',
    301: '삼일절',
    505: '어린이날',
    606: '현충일',
    815: '광복절',
    1003: '개천절',
    1009: '한글날',
    1225: '성탄절',
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
      title: '프로젝트 A',
      tags: const <String>['프로젝트'],
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
  Future<void> create({
    String? calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    List<String> tags = const <String>[],
  }) async {
    final c = _calById(calendarId ?? 'personal');
    final n = _seq++;
    _evs.add(Ev(
      id: 'n$n',
      instanceId: 'n$n',
      calendarId: c.id,
      calendarName: c.name,
      title: title,
      start: start,
      end: end,
      allDay: allDay,
      color: c.color,
      location: location,
      tags: tags,
    ));
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
  Future<void> delete(Ev e) async {
    _evs.removeWhere((x) => x.instanceId == e.instanceId);
  }

  @override
  Future<void> openEditor(Ev e) async {}
}
