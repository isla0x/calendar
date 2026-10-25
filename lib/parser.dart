import 'dates.dart';

/// 한 줄 입력에서 찾아낸 부분의 종류 (색 표시용)
enum HitKind { date, time, duration }

/// 입력 글자에서 [start, end) 부분이 날짜 / 시간 / 길이로 읽혔다는 표시
class Hit {
  const Hit(this.start, this.end, this.kind);
  final int start;
  final int end;
  final HitKind kind;
}

/// "내일 오후 3시 치과 30분" 을 읽은 결과
class QuickParse {
  const QuickParse({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.hasDate,
    required this.hasTime,
    required this.hasDuration,
    required this.hits,
  });

  final String title;

  /// 종일이면 start = 그날 00:00, end = 다음 날 00:00 (끝 미포함)
  final DateTime start;
  final DateTime end;
  final bool allDay;

  /// 글에서 날짜 / 시각 / 길이를 직접 찾았는지
  final bool hasDate;
  final bool hasTime;
  final bool hasDuration;
  final List<Hit> hits;

  bool get isEmpty => title.isEmpty && !hasDate && !hasTime && !hasDuration;
}

// ---------------------------------------------------------------------------
// 도우미

const String _mask = '\u0001';
const String _period = r'(오전|오후|아침|점심|저녁|밤|새벽)';
const String _after = r'(?=$|[^가-힣]|에|은|는|부|까)';

final RegExp _hangul = RegExp(r'[가-힣]');

const Map<String, int> _hangulNum = {
  '한': 1,
  '두': 2,
  '세': 3,
  '네': 4,
  '다섯': 5,
  '여섯': 6,
  '일곱': 7,
  '여덟': 8,
  '아홉': 9,
  '열': 10,
  '열한': 11,
  '열두': 12,
};

bool _isHangul(String s, int i) => i >= 0 && i < s.length && _hangul.hasMatch(s[i]);

/// 찾은 부분을 지워가며(가려가며) 읽는 작업판
class _Work {
  _Work(this.original) : s = original;
  final String original;
  String s;
  final List<Hit> hits = <Hit>[];

  void claim(int a, int b, HitKind kind) {
    s = s.replaceRange(a, b, _mask * (b - a));
    hits.add(Hit(a, b, kind));
  }
}

/// 날짜·시간 뒤에 붙은 "에", "부터", "까지", "쯤" 같은 말도 같이 묶어요.
int _tail(String s, int end, {bool time = false}) {
  var e = end;
  if (time && (s.startsWith('쯤', e) || s.startsWith('경', e))) e += 1;
  if (s.startsWith('부터', e)) {
    e += 2;
  } else if (s.startsWith('까지', e)) {
    e += 2;
  } else if (e < s.length &&
      (s[e] == '에' || s[e] == '은' || s[e] == '는') &&
      !_isHangul(s, e + 1)) {
    e += 1;
  }
  return e;
}

DateTime? _mk(int y, int mo, int d) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final t = DateTime(y, mo, d);
  return (t.month == mo && t.day == d) ? t : null;
}

/// 월/일만 말했을 때: 오늘 이후로 가장 가까운 그 날짜
DateTime? _nextOccur(int mo, int d, DateTime today) {
  final t = _mk(today.year, mo, d);
  if (t != null && !t.isBefore(today)) return t;
  final n = _mk(today.year + 1, mo, d);
  return n ?? t;
}

/// 일만 말했을 때: 이번 달 또는 다음 달들 중 오늘 이후 첫 날짜
DateTime? _nextDayOfMonth(int d, DateTime today) {
  for (var i = 0; i < 12; i++) {
    final base = DateTime(today.year, today.month + i, 1);
    final t = _mk(base.year, base.month, d);
    if (t != null && !t.isBefore(today)) return t;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 종일

final RegExp _reAllDay = RegExp(r'하루\s*종일|종일|all\s*day', caseSensitive: false);

// ---------------------------------------------------------------------------
// 시각

final RegExp _reRangeTilde = RegExp(
    r'(?<![\d:.])(?:' + _period + r'\s*)?(\d{1,2})\s*~\s*(?:' + _period + r'\s*)?(\d{1,2})\s*시(?!간)');

final RegExp _reHour = RegExp(
    r'(?<![\d:.])(?:' + _period + r'\s*)?(\d{1,2})\s*시(?!간)(?:\s*(\d{1,2})\s*분|\s*반(?![가-힣]))?');

final RegExp _reColon =
    RegExp(r'(?<![\d:.])(?:' + _period + r'\s*)?(\d{1,2}):(\d{2})(?![\d:])');

final RegExp _reAmPm =
    RegExp(r'(?<![\d:.])(\d{1,2})(?::(\d{2}))?\s*(am|pm)(?![a-z])', caseSensitive: false);

final RegExp _reHangulHour = RegExp(r'(?<![가-힣])(?:' +
    _period +
    r'\s*)?(열한|열두|열|한|두|세|네|다섯|여섯|일곱|여덟|아홉)\s*시(?!간)(?=$|[^가-힣]|에|반|쯤|경|부|까)(?:\s*반(?![가-힣]))?');

final RegExp _reNoon = RegExp(r'(?<![가-힣])(정오|자정)(?![가-힣])');

final RegExp _reRangeGap = RegExp(r'^\s*(?:부터|에서|~|-|–|—)\s*$');

class _Tk {
  _Tk(this.start, this.end, this.h, this.m, this.p, {this.abs});
  final int start;
  final int end;
  final int h;
  final int m;
  final String? p;

  /// 이미 24시간제 분으로 정해진 값(정오, 자정)
  final int? abs;
}

class _TimeGroup {
  _TimeGroup(this.s, this.e, this.startMin, this.endMin);
  final int s;
  final int e;
  final int startMin;
  final int? endMin;
}

/// 시(hour)를 24시간제로. 오전/오후를 안 썼으면 1~8시는 오후, 9~11시는 오전으로 봐요.
int _hourOf(int h, String? p) {
  switch (p) {
    case '오전':
    case '아침':
    case '새벽':
      return h == 12 ? 0 : h;
    case '오후':
    case '저녁':
      return h < 12 ? h + 12 : h;
    case '점심':
      return (h >= 1 && h <= 5) ? h + 12 : h;
    case '밤':
      if (h == 12) return 24;
      return (h >= 6 && h < 12) ? h + 12 : h;
    default:
      if (h == 0) return 0;
      return h <= 8 ? h + 12 : h;
  }
}

int _minOf(_Tk t, String? p) => t.abs ?? (_hourOf(t.h, p) * 60 + t.m);

/// 끝 시각 정하기: "오후 3시~5시", "10시~1시", "9시~6시" 처럼 끝이 시작보다 뒤가 되게 맞춰요.
int _resolveEnd(int sMin, _Tk b, String? inherit) {
  var e = _minOf(b, b.p ?? inherit);
  if (e <= sMin && b.p == null) e = _minOf(b, null);
  if (e <= sMin && b.abs == null) e += 720;
  if (e <= sMin || e > 1440) e = sMin + 60;
  return e;
}

_TimeGroup? _findTime(String s) {
  // "3~5시"
  final r0 = _reRangeTilde.firstMatch(s);
  if (r0 != null) {
    final h1 = int.parse(r0.group(2)!);
    final h2 = int.parse(r0.group(4)!);
    if (h1 <= 24 && h2 <= 24) {
      final a = _Tk(r0.start, r0.end, h1, 0, r0.group(1));
      final b = _Tk(r0.start, r0.end, h2, 0, r0.group(3));
      final sMin = _minOf(a, a.p);
      final eMin = _resolveEnd(sMin, b, a.p);
      return _TimeGroup(r0.start, _tail(s, r0.end, time: true), sMin, eMin);
    }
  }

  final tks = <_Tk>[];
  void add(_Tk t) {
    if (t.h < 0 || t.h > 24 || t.m < 0 || t.m > 59) return;
    if (t.h == 24 && t.m != 0) return;
    tks.add(t);
  }

  for (final m in _reHour.allMatches(s)) {
    final mins = m.group(3) != null
        ? int.parse(m.group(3)!)
        : (m.group(0)!.contains('반') ? 30 : 0);
    add(_Tk(m.start, m.end, int.parse(m.group(2)!), mins, m.group(1)));
  }
  for (final m in _reColon.allMatches(s)) {
    add(_Tk(m.start, m.end, int.parse(m.group(2)!), int.parse(m.group(3)!), m.group(1)));
  }
  for (final m in _reAmPm.allMatches(s)) {
    final h = int.parse(m.group(1)!);
    if (h > 12) continue;
    final mins = m.group(2) != null ? int.parse(m.group(2)!) : 0;
    final p = m.group(3)!.toLowerCase() == 'am' ? '오전' : '오후';
    add(_Tk(m.start, m.end, h, mins, p));
  }
  for (final m in _reHangulHour.allMatches(s)) {
    final h = _hangulNum[m.group(2)!];
    if (h == null) continue;
    add(_Tk(m.start, m.end, h, m.group(0)!.contains('반') ? 30 : 0, m.group(1)));
  }
  for (final m in _reNoon.allMatches(s)) {
    final noon = m.group(1) == '정오';
    add(_Tk(m.start, m.end, noon ? 12 : 24, 0, null, abs: noon ? 720 : 1440));
  }

  tks.sort((a, b) {
    final c = a.start.compareTo(b.start);
    if (c != 0) return c;
    return (b.end - b.start).compareTo(a.end - a.start);
  });
  final kept = <_Tk>[];
  for (final t in tks) {
    if (kept.isNotEmpty && t.start < kept.last.end) continue;
    kept.add(t);
  }
  if (kept.isEmpty) return null;

  final a = kept.first;
  final sMin = _minOf(a, a.p);
  if (kept.length > 1) {
    final b = kept[1];
    final gap = s.substring(a.end, b.start);
    if (_reRangeGap.hasMatch(gap)) {
      final eMin = _resolveEnd(sMin, b, a.p);
      return _TimeGroup(a.start, _tail(s, b.end, time: true), sMin, eMin);
    }
  }
  return _TimeGroup(a.start, _tail(s, a.end, time: true), sMin, null);
}

// ---------------------------------------------------------------------------
// 길이

final RegExp _reDurH = RegExp(
    r'(?:(?<![\d.])(\d+(?:\.\d+)?)|(?<![가-힣])(한|두|세|네))\s*시간(?:\s*(\d{1,2})\s*분|\s*반(?![가-힣]))?(?:\s*동안)?');

final RegExp _reDurM = RegExp(r'(?<![\d.])(\d{1,3})\s*분(?:\s*(?:간|동안))?');

class _Dur {
  _Dur(this.minutes, this.s, this.e);
  final int minutes;
  final int s;
  final int e;
}

_Dur? _findDuration(String s) {
  final a = _reDurH.firstMatch(s);
  final b = _reDurM.firstMatch(s);
  RegExpMatch? m;
  var hourForm = true;
  if (a != null && (b == null || a.start <= b.start)) {
    m = a;
  } else if (b != null) {
    m = b;
    hourForm = false;
  }
  if (m == null) return null;

  var min = 0;
  if (hourForm) {
    final digits = m.group(1);
    if (digits != null) {
      min = (double.parse(digits) * 60).round();
    } else {
      min = (_hangulNum[m.group(2) ?? ''] ?? 1) * 60;
    }
    final extra = m.group(3);
    if (extra != null) {
      min += int.parse(extra);
    } else if (m.group(0)!.contains('반')) {
      min += 30;
    }
  } else {
    min = int.parse(m.group(1)!);
  }
  if (min <= 0 || min > 24 * 60) return null;
  return _Dur(min, m.start, m.end);
}

// ---------------------------------------------------------------------------
// 날짜

final RegExp _reWeekday = RegExp(
    r'(?<![가-힣])(?:(다다음\s*주|다음\s*주|담\s*주|이번\s*주)\s*)?([월화수목금토일])요일');

final RegExp _reRel =
    RegExp(r'(?<![가-힣])(내일모레|모레|글피|내일|낼|오늘|금일)' + _after);

final RegExp _reAfter = RegExp(r'(?<![\d.])(\d{1,3})\s*(일|주)\s*(?:후|뒤)');

final RegExp _reYmd = RegExp(
    r'(?<![\d.])(\d{4})\s*(?:년|[./-])\s*(\d{1,2})\s*(?:월|[./-])\s*(\d{1,2})(?:\s*일' +
        _after +
        r')?(?![\d:])');

final RegExp _reMd = RegExp(r'(?<![\d.])(\d{1,2})\s*월\s*(\d{1,2})\s*일' + _after);

final RegExp _reSlash = RegExp(
    r'(?<![\d.:/])(\d{1,2})\s*[/.]\s*(\d{1,2})(?:일' + _after + r')?(?![\d:/.]|시|분)');

final RegExp _reDay = RegExp(
    r'(?<![\d.월/:])(\d{1,2})\s*일(?!\s*(?:후|뒤|간|차|동안))' + _after);

final RegExp _reWeek =
    RegExp(r'(?<![가-힣])(다다음\s*주|다음\s*주|담\s*주|이번\s*주)' + _after);

class _Dt {
  _Dt(this.date, this.s, this.e);
  final DateTime date;
  final int s;
  final int e;
}

int _weekOffset(String? prefix) {
  if (prefix == null) return -1;
  final p = prefix.replaceAll(RegExp(r'\s'), '');
  if (p == '다다음주') return 14;
  if (p == '다음주' || p == '담주') return 7;
  return 0; // 이번주
}

_Dt? _findDate(String s, DateTime now) {
  final today = dayOnly(now);
  final monday = addDays(today, -(today.weekday - 1));

  // 요일: "금요일", "다음주 월요일"
  var m = _reWeekday.firstMatch(s);
  if (m != null) {
    final target = kWeekdayKo.indexOf(m.group(2)!) + 1; // 월=1 ... 일=7
    final off = _weekOffset(m.group(1));
    DateTime date;
    if (off < 0) {
      var delta = (target - today.weekday + 7) % 7;
      if (delta == 0) delta = 7;
      date = addDays(today, delta);
    } else {
      date = addDays(monday, off + target - 1);
    }
    return _Dt(date, m.start, _tail(s, m.end));
  }

  // 오늘 / 내일 / 모레 ...
  m = _reRel.firstMatch(s);
  if (m != null) {
    int n;
    switch (m.group(1)) {
      case '내일':
      case '낼':
        n = 1;
        break;
      case '모레':
      case '내일모레':
        n = 2;
        break;
      case '글피':
        n = 3;
        break;
      default:
        n = 0;
    }
    return _Dt(addDays(today, n), m.start, _tail(s, m.end));
  }

  // 3일 후 / 2주 뒤
  m = _reAfter.firstMatch(s);
  if (m != null) {
    final n = int.parse(m.group(1)!);
    final days = m.group(2) == '주' ? n * 7 : n;
    return _Dt(addDays(today, days), m.start, _tail(s, m.end));
  }

  // 2026년 11월 3일, 2026-11-03
  m = _reYmd.firstMatch(s);
  if (m != null) {
    final d = _mk(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    if (d != null) return _Dt(d, m.start, _tail(s, m.end));
  }

  // 11월 3일
  m = _reMd.firstMatch(s);
  if (m != null) {
    final d = _nextOccur(int.parse(m.group(1)!), int.parse(m.group(2)!), today);
    if (d != null) return _Dt(d, m.start, _tail(s, m.end));
  }

  // 11/3, 11.3
  m = _reSlash.firstMatch(s);
  if (m != null) {
    final d = _nextOccur(int.parse(m.group(1)!), int.parse(m.group(2)!), today);
    if (d != null) return _Dt(d, m.start, _tail(s, m.end));
  }

  // 3일
  m = _reDay.firstMatch(s);
  if (m != null) {
    final d = _nextDayOfMonth(int.parse(m.group(1)!), today);
    if (d != null) return _Dt(d, m.start, _tail(s, m.end));
  }

  // 다음주 (요일 없이)
  m = _reWeek.firstMatch(s);
  if (m != null) {
    final off = _weekOffset(m.group(1));
    return _Dt(addDays(today, off), m.start, _tail(s, m.end));
  }

  return null;
}

// ---------------------------------------------------------------------------
// 전체

/// 한 줄 입력을 읽어요.
///
/// - 날짜를 안 쓰면 [defaultDay](지금 보고 있는 날)로 해요.
/// - 시각을 안 쓰고 길이도 없으면 종일 일정이에요.
/// - 시각만 쓰면 1시간이에요.
QuickParse parseQuick(
  String input, {
  required DateTime now,
  required DateTime defaultDay,
}) {
  final w = _Work(input);

  var allDayWord = false;
  final ad = _reAllDay.firstMatch(w.s);
  if (ad != null) {
    allDayWord = true;
    w.claim(ad.start, ad.end, HitKind.time);
  }

  final tg = _findTime(w.s);
  final int? startMin = tg?.startMin;
  final int? rangeEnd = tg?.endMin;
  if (tg != null) w.claim(tg.s, tg.e, HitKind.time);

  final dur = _findDuration(w.s);
  final int? durMin = dur?.minutes;
  if (dur != null) w.claim(dur.s, dur.e, HitKind.duration);

  final dt = _findDate(w.s, now);
  if (dt != null) w.claim(dt.s, dt.e, HitKind.date);

  // 제목: 읽힌 부분을 빼고 남은 글
  var title = w.s.replaceAll(_mask, ' ').replaceAll(RegExp(r'\s+'), ' ');
  title = title.replaceAll(RegExp(r'^[\s,.\-~·:]+|[\s,.\-~·:]+$'), '');

  final day = dt?.date ?? dayOnly(defaultDay);
  final allDay = allDayWord || (startMin == null && durMin == null);

  DateTime start;
  DateTime end;
  if (allDay) {
    start = day;
    end = addDays(day, 1);
  } else {
    int sMin;
    int eMin;
    if (startMin != null) {
      sMin = startMin;
      eMin = rangeEnd ?? (sMin + (durMin ?? 60));
    } else {
      // 길이만 쓴 경우: 오늘이면 다음 15분 단위부터, 아니면 오전 9시부터
      final t = ceilTo(now, 15);
      sMin = (sameDay(day, now) && sameDay(t, now)) ? t.hour * 60 + t.minute : 9 * 60;
      eMin = sMin + (durMin ?? 60);
    }
    start = DateTime(day.year, day.month, day.day, 0, sMin);
    end = DateTime(day.year, day.month, day.day, 0, eMin);
  }

  w.hits.sort((a, b) => a.start.compareTo(b.start));

  return QuickParse(
    title: title,
    start: start,
    end: end,
    allDay: allDay,
    hasDate: dt != null,
    hasTime: startMin != null,
    hasDuration: durMin != null || rangeEnd != null,
    hits: List<Hit>.unmodifiable(w.hits),
  );
}

/// 한 줄 입력 글에서 [kinds] 로 읽힌 부분들을 지우고, 첫 번째 자리에 [insert] 를 넣어요.
/// 읽힌 부분이 없으면 글 끝에 붙여요. (날짜·시간 칩을 눌러 바꿀 때 사용)
String rewriteHits(String text, List<Hit> hits, Set<HitKind> kinds, String insert) {
  final targets = hits.where((h) => kinds.contains(h.kind)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  if (targets.isEmpty) {
    final base = text.trimRight();
    return base.isEmpty ? insert : '$base $insert';
  }
  final buf = StringBuffer();
  var cursor = 0;
  for (var i = 0; i < targets.length; i++) {
    final h = targets[i];
    buf.write(text.substring(cursor, h.start));
    if (i == 0) buf.write(insert);
    cursor = h.end;
  }
  buf.write(text.substring(cursor));
  return buf.toString().replaceAll(RegExp(r' {2,}'), ' ').trimLeft();
}
