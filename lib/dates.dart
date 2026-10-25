const List<String> kWeekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// '월' ~ '일'
String wd(DateTime d) => kWeekdayKo[d.weekday - 1];

/// '월요일' ~ '일요일'
String wdFull(DateTime d) => '${wd(d)}요일';

String two(int n) => n.toString().padLeft(2, '0');

/// '14:30'
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// '1시간 30분', '30분', '2시간'
String durText(Duration d) {
  final m = d.inMinutes;
  if (m <= 0) return '0분';
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$r분';
  if (r == 0) return '$h시간';
  return '$h시간 $r분';
}

/// 그 주의 일요일 (달력은 일요일 시작)
DateTime weekStartSunday(DateTime d) =>
    addDays(dayOnly(d), -(d.weekday % 7));

DateTime maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

/// t 를 step(분) 단위로 올림
DateTime ceilTo(DateTime t, int stepMinutes) {
  final m = t.hour * 60 + t.minute + (t.second > 0 ? 1 : 0);
  final r = ((m + stepMinutes - 1) ~/ stepMinutes) * stepMinutes;
  return dayOnly(t).add(Duration(minutes: r));
}

/// 'x월 y일 요일' (예: 10월 27일 화)
String dateChip(DateTime d) => '${d.month}월 ${d.day}일 ${wd(d)}';

/// '오후 3:00' 형태
String ampm(DateTime d) {
  final h = d.hour;
  final label = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$label $h12:${two(d.minute)}';
}

/// a 날짜부터 b 날짜까지 며칠 차이인지 (시각·서머타임과 상관없이 날짜만 비교)
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// '여유 없음' 또는 '1시간 30분'
String freeText(int minutes) =>
    minutes <= 0 ? '여유 없음' : durText(Duration(minutes: minutes));

/// '오늘', '내일', '어제', 그 외 '10월 27일'
String relDay(DateTime d, DateTime today) {
  final n = daysBetween(today, d);
  if (n == 0) return '오늘';
  if (n == 1) return '내일';
  if (n == -1) return '어제';
  return '${d.month}월 ${d.day}일';
}

/// '오후 3:00–3:30' (같은 오전/오후면 뒤쪽은 시각만)
String rangeText(DateTime s, DateTime e) {
  final sameHalf = sameDay(s, e) && (s.hour < 12) == (e.hour < 12);
  if (!sameHalf) return '${ampm(s)}–${ampm(e)}';
  final h12 = e.hour % 12 == 0 ? 12 : e.hour % 12;
  return '${ampm(s)}–$h12:${two(e.minute)}';
}

/// 남은 분을 '20분', '1시간 30분' 으로. 하루 넘으면 '2일'.
String leftText(int minutes) {
  if (minutes >= 48 * 60) return '${minutes ~/ (24 * 60)}일';
  return durText(Duration(minutes: minutes));
}

/// day 날짜 안에서 t 가 몇 분째인지(0~1440). day 를 벗어나면 처음/끝으로 맞춰요.
int minOfDay(DateTime t, DateTime day) {
  final d0 = dayOnly(day);
  if (t.isBefore(d0)) return 0;
  if (!t.isBefore(addDays(d0, 1))) return 1440;
  return t.hour * 60 + t.minute;
}

/// '오후 3시', '오전 9시 30분'
String timeWords(int hour, int minute) {
  final label = hour < 12 ? '오전' : '오후';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return minute == 0 ? '$label $h12시' : '$label $h12시 $minute분';
}
