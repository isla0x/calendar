import 'l10n.dart';

const List<String> kWeekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

const List<String> _wdEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _wdEnFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const List<String> _wdFr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const List<String> _wdFrFull = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const List<String> _wdZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const List<String> _wdZhFull = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
const List<String> _wdJa = ['月', '火', '水', '木', '金', '土', '日'];
const List<String> _wdJaFull = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
const List<String> _wdHeadEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> _wdHeadFr = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const List<String> _wdHeadZh = ['一', '二', '三', '四', '五', '六', '日'];
const List<String> _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _monEnFull = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
];
const List<String> _monFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];
const List<String> _monFrFull = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

/// 요일 한 칸 머리글용 (월=1 … 일=7)
String wdHead(int weekday) {
  final i = weekday - 1;
  switch (L10n.lang) {
    case Lang.ko:
      return kWeekdayKo[i];
    case Lang.en:
      return _wdHeadEn[i];
    case Lang.fr:
      return _wdHeadFr[i];
    case Lang.zh:
      return _wdHeadZh[i];
    case Lang.ja:
      return _wdJa[i];
  }
}

/// 짧은 요일: '금' / 'Fri' / 'ven.' / '周五' / '金'
String wd(DateTime d) {
  final i = d.weekday - 1;
  switch (L10n.lang) {
    case Lang.ko:
      return kWeekdayKo[i];
    case Lang.en:
      return _wdEn[i];
    case Lang.fr:
      return _wdFr[i];
    case Lang.zh:
      return _wdZh[i];
    case Lang.ja:
      return _wdJa[i];
  }
}

/// 긴 요일: '금요일' / 'Friday' / 'vendredi' / '星期五' / '金曜日'
String wdFull(DateTime d) {
  final i = d.weekday - 1;
  switch (L10n.lang) {
    case Lang.ko:
      return '${kWeekdayKo[i]}요일';
    case Lang.en:
      return _wdEnFull[i];
    case Lang.fr:
      return _wdFrFull[i];
    case Lang.zh:
      return _wdZhFull[i];
    case Lang.ja:
      return _wdJaFull[i];
  }
}

/// '10월 30일' / 'Oct 30' / '30 oct.' / '10月30日'
String mdText(DateTime d) {
  switch (L10n.lang) {
    case Lang.ko:
      return '${d.month}월 ${d.day}일';
    case Lang.en:
      return '${_monEn[d.month - 1]} ${d.day}';
    case Lang.fr:
      return '${d.day} ${_monFr[d.month - 1]}';
    case Lang.zh:
    case Lang.ja:
      return '${d.month}月${d.day}日';
  }
}

/// '10월' / 'October' / 'octobre' / '10月' (큰 제목용)
String mText(int month) {
  switch (L10n.lang) {
    case Lang.ko:
      return '$month월';
    case Lang.en:
      return _monEnFull[month - 1];
    case Lang.fr:
      return _monFrFull[month - 1];
    case Lang.zh:
    case Lang.ja:
      return '$month月';
  }
}

/// '2026년' / '2026'
String yText(int year) => L10n.lang == Lang.ko ? '$year년' : (L10n.lang == Lang.zh || L10n.lang == Lang.ja ? '$year年' : '$year');

/// '25일' / '25' / '25日'
String dText(int day) {
  switch (L10n.lang) {
    case Lang.ko:
      return '$day일';
    case Lang.zh:
    case Lang.ja:
      return '$day日';
    case Lang.en:
    case Lang.fr:
      return '$day';
  }
}

/// '2026년 10월' / 'Oct 2026' / 'oct. 2026' / '2026年10月'
String ymText(DateTime d) {
  switch (L10n.lang) {
    case Lang.ko:
      return '${d.year}년 ${d.month}월';
    case Lang.en:
      return '${_monEn[d.month - 1]} ${d.year}';
    case Lang.fr:
      return '${_monFr[d.month - 1]} ${d.year}';
    case Lang.zh:
    case Lang.ja:
      return '${d.year}年${d.month}月';
  }
}

/// '2026년 10월 30일' / 'Oct 30, 2026' / '30 oct. 2026' / '2026年10月30日'
String ymdText(DateTime d) {
  switch (L10n.lang) {
    case Lang.ko:
      return '${d.year}년 ${d.month}월 ${d.day}일';
    case Lang.en:
      return '${_monEn[d.month - 1]} ${d.day}, ${d.year}';
    case Lang.fr:
      return '${d.day} ${_monFr[d.month - 1]} ${d.year}';
    case Lang.zh:
    case Lang.ja:
      return '${d.year}年${d.month}月${d.day}日';
  }
}

String two(int n) => n.toString().padLeft(2, '0');

/// '14:30'
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// '1시간 30분', '30분', '2시간'
String durText(Duration d) {
  final m = d.inMinutes;
  if (m <= 0) return tl('0분');
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return tl('{0}분', [r]);
  if (r == 0) return tl('{0}시간', [h]);
  return tl('{0}시간 {1}분', [h, r]);
}

/// 한 줄 입력 칸에 넣을 길이 글. 다시 읽어도 같은 길이가 나오게 써요.
/// (프랑스어는 "2 h" 가 시각으로 읽히니 "2 heures" 로 써요.)
String durInput(Duration d) {
  if (L10n.lang != Lang.fr) return durText(d);
  final m = d.inMinutes;
  if (m <= 0) return '0 min';
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$r min';
  final hw = h > 1 ? '$h heures' : '$h heure';
  return r == 0 ? hw : '$hw $r min';
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

/// '10월 27일 화' / 'Tue, Oct 27' / 'mar. 27 oct.' / '10月27日 周二' / '10月27日(火)'
String dateChip(DateTime d) {
  switch (L10n.lang) {
    case Lang.ko:
      return '${mdText(d)} ${wd(d)}';
    case Lang.en:
      return '${wd(d)}, ${mdText(d)}';
    case Lang.fr:
      return '${wd(d)} ${mdText(d)}';
    case Lang.zh:
      return '${mdText(d)} ${wd(d)}';
    case Lang.ja:
      return '${mdText(d)}(${wd(d)})';
  }
}

/// '10월 27일 화요일' / 'Tuesday, Oct 27' / 'mardi 27 oct.' / '10月27日 星期二' / '10月27日 火曜日'
String dateFull(DateTime d) {
  switch (L10n.lang) {
    case Lang.ko:
    case Lang.zh:
    case Lang.ja:
      return '${mdText(d)} ${wdFull(d)}';
    case Lang.en:
      return '${wdFull(d)}, ${mdText(d)}';
    case Lang.fr:
      return '${wdFull(d)} ${mdText(d)}';
  }
}

/// '오후 3:00' / '3:00 PM' / '15:00' / '下午3:00' / '午後3:00'
String ampm(DateTime d) {
  final h = d.hour;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final m = two(d.minute);
  switch (L10n.lang) {
    case Lang.ko:
      return '${h < 12 ? '오전' : '오후'} $h12:$m';
    case Lang.en:
      return '$h12:$m ${h < 12 ? 'AM' : 'PM'}';
    case Lang.fr:
      return hm(d);
    case Lang.zh:
      return '${h < 12 ? '上午' : '下午'}$h12:$m';
    case Lang.ja:
      return '${h < 12 ? '午前' : '午後'}$h12:$m';
  }
}

/// a 날짜부터 b 날짜까지 며칠 차이인지 (시각·서머타임과 상관없이 날짜만 비교)
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// '여유 없음' 또는 '1시간 30분'
String freeText(int minutes) =>
    minutes <= 0 ? tl('여유 없음') : durText(Duration(minutes: minutes));

/// '오늘', '내일', '어제', 그 외 '10월 27일'
String relDay(DateTime d, DateTime today) {
  final n = daysBetween(today, d);
  if (n == 0) return tl('오늘');
  if (n == 1) return tl('내일');
  if (n == -1) return tl('어제');
  return mdText(d);
}

/// '오후 3:00–3:30' (같은 오전/오후면 뒤쪽은 시각만)
String rangeText(DateTime s, DateTime e) {
  final sameHalf = sameDay(s, e) && (s.hour < 12) == (e.hour < 12);
  if (!sameHalf || L10n.lang == Lang.fr) return '${ampm(s)}–${ampm(e)}';
  final h12 = e.hour % 12 == 0 ? 12 : e.hour % 12;
  if (L10n.lang == Lang.en) {
    final sh = s.hour % 12 == 0 ? 12 : s.hour % 12;
    return '$sh:${two(s.minute)}–$h12:${two(e.minute)} ${s.hour < 12 ? 'AM' : 'PM'}';
  }
  return '${ampm(s)}–$h12:${two(e.minute)}';
}

/// 남은 분을 '20분', '1시간 30분' 으로. 하루 넘으면 '2일'.
String leftText(int minutes) {
  if (minutes >= 48 * 60) return tl('{0}일', [minutes ~/ (24 * 60)]);
  return durText(Duration(minutes: minutes));
}

/// day 날짜 안에서 t 가 몇 분째인지(0~1440). day 를 벗어나면 처음/끝으로 맞춰요.
int minOfDay(DateTime t, DateTime day) {
  final d0 = dayOnly(day);
  if (t.isBefore(d0)) return 0;
  if (!t.isBefore(addDays(d0, 1))) return 1440;
  return t.hour * 60 + t.minute;
}

/// '오후 3시', '오전 9시 30분' / '3 PM', '9:30 AM' / '15 h', '9 h 30' / '下午3点', '上午9点30分' / '午後3時', '午前9時30分'
String timeWords(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final am = hour < 12;
  switch (L10n.lang) {
    case Lang.ko:
      final lk = am ? '오전' : '오후';
      return minute == 0 ? '$lk $h12시' : '$lk $h12시 $minute분';
    case Lang.en:
      return minute == 0 ? '$h12 ${am ? 'AM' : 'PM'}' : '$h12:${two(minute)} ${am ? 'AM' : 'PM'}';
    case Lang.fr:
      return minute == 0 ? '$hour h' : '$hour h ${two(minute)}';
    case Lang.zh:
      final lz = am ? '上午' : '下午';
      return minute == 0 ? '$lz$h12点' : '$lz$h12点$minute分';
    case Lang.ja:
      final lj = am ? '午前' : '午後';
      return minute == 0 ? '$lj$h12時' : '$lj$h12時$minute分';
  }
}

/// 요일 번호(월=1 … 일=7)로 긴 요일 이름
String wdHeadFull(int weekday) => wdFull(DateTime(2026, 10, 25 + weekday));
