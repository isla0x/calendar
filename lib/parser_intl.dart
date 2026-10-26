import 'dates.dart';
import 'l10n.dart';

/// 영어·프랑스어·중국어·일본어로 쓴 한 줄 입력을, 한국어 파서가 읽을 수 있는 글로 바꿔요.
///
/// 날짜·시간·길이·반복 표현만 바꾸고 나머지 글자는 그대로 둬요. 바뀐 글자가 원래 글의
/// 어디였는지 기억해 두어서(칩 색칠·글 고치기에 쓰여요) [Normalized.mapStart] 로 되돌려요.
class _Seg {
  const _Seg(this.ns, this.ne, this.os, this.oe, this.same);
  final int ns;
  final int ne;
  final int os;
  final int oe;
  final bool same;
}

class Normalized {
  Normalized(this.text, this.original, this._segs);

  /// 한국어 파서가 읽을 글
  final String text;
  final String original;
  final List<_Seg> _segs;

  /// 바뀐 글의 [n] 번째 글자가 시작하는 자리를 원래 글의 자리로
  int mapStart(int n) {
    for (final s in _segs) {
      if (n >= s.ns && n < s.ne) return s.same ? s.os + (n - s.ns) : s.os;
    }
    return original.length;
  }

  /// 바뀐 글에서 [n] 에서 끝나는(끝 미포함) 부분이 원래 글에서 끝나는 자리
  int mapEnd(int n) {
    if (n <= 0) return 0;
    for (final s in _segs) {
      if (n - 1 >= s.ns && n - 1 < s.ne) return s.same ? s.os + (n - s.ns) : s.oe;
    }
    return original.length;
  }
}

class _Tok {
  _Tok(this.s, this.e, this.out, this.kind, this.pri);
  final int s;
  final int e;
  final String out;
  final String kind;
  final int pri;
}

class _Rule {
  _Rule(this.kind, this.re, this.fn, {this.pri = 0});
  final String kind;
  final RegExp re;
  final String? Function(Match m) fn;
  final int pri;
}

const String _lb = r'(?<![\p{L}\d])';
const String _rb = r'(?![\p{L}\d])';

RegExp _rx(String p, {bool ci = true}) => RegExp(p, caseSensitive: !ci, unicode: true);

String _two(int n) => n.toString().padLeft(2, '0');

/// 앞에 붙은 말에 따른 한국어 꼬리: "부터" / "까지" / 없음
String _sfx(String? w) {
  if (w == null) return '';
  final x = w.toLowerCase();
  const from = <String>['from', 'since', 'starting', 'du', 'de', 'dès', 'des', '从', '從'];
  const until = <String>[
    'until', 'till', 'through', 'thru', 'by', 'before', 'due', 'avant', 'pour', "jusqu'à", "jusqu'au",
    'jusqu’à', 'jusqu’au', 'jusquà', 'jusquau',
  ];
  if (from.contains(x)) return '부터';
  if (until.contains(x)) return '까지';
  return '';
}

String _ymd(String? y, int m, int d, String sfx) => '${y != null ? '$y년 ' : ''}$m월 $d일$sfx';

String? _weekPrefix(String? w) {
  if (w == null) return '';
  final x = w.toLowerCase();
  if (x == 'next' || x == 'prochain' || x == 'prochaine' || x == '下' || x == '来週' || x == '來週') return '다음 주 ';
  if (x == '再来週' || x == '下下') return '다다음 주 ';
  if (x == 'this' || x == 'coming' || x == 'upcoming' || x == '这' || x == '這' || x == '本' || x == '今週') return '이번 주 ';
  return '';
}

// ---------------------------------------------------------------------------
// 영어

const Map<String, int> _enMonth = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const String _enMonthRe =
    r'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?';
const String _enWdRe =
    r'mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?';
const String _enPre = r'(?:(on|from|until|till|through|thru|by|before|due|since|starting)\s+)?';

int _enWd(String w) {
  final x = w.toLowerCase().substring(0, 3);
  const l = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  return l.indexOf(x) + 1;
}

String _wdKo(int i) => '${kWeekdayKo[i - 1]}요일';

final RegExp _enFollow = RegExp(r'^\s*(?:\d|at\b|@|noon|midnight)', caseSensitive: false);

List<_Rule> _enRules() {
  return <_Rule>[
    // 매주 금요일
    _Rule('rep', _rx('${_lb}every\\s+($_enWdRe)$_rb'), (m) => '매주 ${_wdKo(_enWd(m.group(1)!))}', pri: 5),
    _Rule('rep', _rx('$_lb(?:every\\s+(?:day|morning|evening|night)|daily|everyday|each\\s+day)$_rb'), (m) => '매일', pri: 4),
    _Rule('rep', _rx('$_lb(?:every\\s+(?:work\\s*day|week\\s*day)|week\\s*days|mon(?:day)?\\s*(?:-|–|to|through)\\s*fri(?:day)?)$_rb'), (m) => '평일마다', pri: 4),
    _Rule('rep', _rx('$_lb(?:every\\s+week|weekly|each\\s+week)$_rb'), (m) => '매주', pri: 3),
    // 날짜
    _Rule('date', _rx('$_lb$_enPre(?:the\\s+)?($_enMonthRe)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?![\\d:])(?:,?\\s*(20\\d{2})(?!\\d))?'), (m) {
      final mo = _enMonth[m.group(2)!.toLowerCase().substring(0, 3)]!;
      return _ymd(m.group(4), mo, int.parse(m.group(3)!), _sfx(m.group(1)));
    }, pri: 3),
    _Rule('date', _rx('$_lb$_enPre(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($_enMonthRe)\\.?(?:,?\\s*(20\\d{2})(?!\\d))?$_rb'), (m) {
      final mo = _enMonth[m.group(3)!.toLowerCase().substring(0, 3)]!;
      return _ymd(m.group(4), mo, int.parse(m.group(2)!), _sfx(m.group(1)));
    }, pri: 3),
    _Rule('date', _rx('$_lb$_enPre(?:(next|this|coming|upcoming)\\s+)?($_enWdRe)$_rb'), (m) {
      final w = m.group(3)!;
      if (w.length <= 4 && m.group(1) == null && m.group(2) == null && !_enFollow.hasMatch(m.input.substring(m.end))) {
        return null;
      }
      return '${_weekPrefix(m.group(2))}${_wdKo(_enWd(w))}${_sfx(m.group(1))}';
    }, pri: 2),
    _Rule('date', _rx('$_lb$_enPre(the\\s+)?(\\d{1,2})(?:st|nd|rd|th)(?![\\p{L}\\d])'), (m) {
      if (m.group(2) == null) return null;
      return '${int.parse(m.group(3)!)}일${_sfx(m.group(1))}';
    }, pri: 1),
    _Rule('date', _rx('$_lb(?:(on|from|until|till|by|before|due)\\s+)?(day\\s+after\\s+tomorrow)$_rb'), (m) => '모레${_sfx(m.group(1))}', pri: 3),
    _Rule('date', _rx('$_lb(?:(on|from|until|till|by|before|due)\\s+)?(today|tonight|tomorrow|tmrw)$_rb'), (m) {
      final w = m.group(2)!.toLowerCase();
      return '${w == 'tomorrow' || w == 'tmrw' ? '내일' : '오늘'}${_sfx(m.group(1))}';
    }, pri: 2),
    _Rule('date', _rx('${_lb}in\\s+(\\d{1,3})\\s+(day|days|week|weeks)$_rb'), (m) {
      final n = m.group(1)!;
      return m.group(2)!.toLowerCase().startsWith('w') ? '$n주 후' : '$n일 후';
    }, pri: 3),
    _Rule('date', _rx('$_lb(\\d{1,3})\\s+(day|days|week|weeks)\\s+(?:from\\s+now|later)$_rb'), (m) {
      final n = m.group(1)!;
      return m.group(2)!.toLowerCase().startsWith('w') ? '$n주 후' : '$n일 후';
    }, pri: 3),
    _Rule('date', _rx('$_lb(?:(within|by(?:\\s+the\\s+end\\s+of)?|before(?:\\s+the\\s+end\\s+of)?)\\s+)?(next|this)\\s+week$_rb'), (m) {
      final next = m.group(2)!.toLowerCase() == 'next';
      return next ? '다음 주' : '이번 주';
    }, pri: 2),
    // 시각
    _Rule('time', _rx('$_lb(?:(?:at|around)\\s+)?noon$_rb'), (m) => '정오', pri: 2),
    _Rule('time', _rx('$_lb(?:(?:at|around)\\s+)?midnight$_rb'), (m) => '자정', pri: 2),
    _Rule('time', _rx('$_lb(?:(?:at|from|@)\\s+)?(\\d{1,2})\\s*(?:-|–|to)\\s*(\\d{1,2})\\s*(a\\.?m\\.?|p\\.?m\\.?)(?![\\p{L}])'), (m) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final pm = m.group(3)!.toLowerCase().startsWith('p');
      final aPm = pm ? ((a % 12) <= (b % 12) || a == 12) : false;
      return '$a${aPm ? 'pm' : 'am'}~$b${pm ? 'pm' : 'am'}';
    }, pri: 4),
    _Rule('time', _rx('$_lb(?:(?:at|from|@)\\s+)?(\\d{1,2})(?::(\\d{2}))?\\s*(a\\.?m\\.?|p\\.?m\\.?)(?![\\p{L}])'), (m) {
      final ap = m.group(3)!.toLowerCase().startsWith('p') ? 'pm' : 'am';
      final mm = m.group(2);
      return mm == null ? '${m.group(1)}$ap' : '${m.group(1)}:$mm$ap';
    }, pri: 3),
    _Rule('time', _rx('$_lb(?:at|@)\\s+(\\d{1,2})(?::(\\d{2}))?(?![\\d:])(?!\\s*(?:a\\.?m|p\\.?m))'), (m) {
      final mm = m.group(2);
      return mm == null ? '${m.group(1)}시' : '${m.group(1)}:$mm';
    }, pri: 2),
    _Rule('time', _rx('$_lb(\\d{1,2})\\s*o[\'’]?clock$_rb'), (m) => '${m.group(1)}시', pri: 2),
    // 길이
    _Rule('dur', _rx('$_lb(?:for\\s+)?(\\d+)\\s*(?:h|hr|hrs|hours?)\\s*(?:and\\s+)?(\\d{1,2})\\s*(?:m|min|mins|minutes?)$_rb'), (m) => '${m.group(1)}시간 ${m.group(2)}분', pri: 4),
    _Rule('dur', _rx('$_lb(?:for\\s+)?(\\d+(?:\\.\\d+)?)\\s*(?:h|hr|hrs|hours?)$_rb'), (m) => '${m.group(1)}시간', pri: 3),
    _Rule('dur', _rx('$_lb(?:for\\s+)?(\\d+)\\s*(?:m|min|mins|minutes?)$_rb'), (m) => '${m.group(1)}분', pri: 3),
    _Rule('dur', _rx('$_lb(?:for\\s+)?an?\\s+hour(\\s+and\\s+a\\s+half)?$_rb'), (m) => m.group(1) != null ? '1시간 반' : '1시간', pri: 3),
    _Rule('dur', _rx('$_lb(?:for\\s+)?half\\s+(?:an?\\s+)?hour$_rb'), (m) => '30분', pri: 3),
    _Rule('dur', _rx('$_lb(?:for\\s+)?(one|two|three|four|five|six)\\s+hours?$_rb'), (m) {
      const n = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6};
      return '${n[m.group(1)!.toLowerCase()]}시간';
    }, pri: 3),
    // 종일
    _Rule('time', _rx('$_lb(?:all[\\s-]*day|whole\\s+day|full\\s+day)$_rb'), (m) => '종일', pri: 3),
    // 할 일: 주 N번 / 언젠가 / 이번 주 안에
    _Rule('todo', _rx('$_lb(\\d)\\s*(?:x|times?)\\s*(?:a|per|each|/)\\s*week$_rb'), (m) => '주 ${m.group(1)}번', pri: 4),
    _Rule('todo', _rx('$_lb(once|twice|thrice)\\s+(?:a|per|each)\\s+week$_rb'), (m) {
      const n = {'once': 1, 'twice': 2, 'thrice': 3};
      return '주 ${n[m.group(1)!.toLowerCase()]}번';
    }, pri: 4),
    _Rule('todo', _rx('$_lb(?:someday|sometime)$_rb'), (m) => '언젠가', pri: 3),
  ];
}

// ---------------------------------------------------------------------------
// 프랑스어

const Map<String, int> _frMonth = {
  'janv': 1, 'janvier': 1, 'févr': 2, 'fevr': 2, 'février': 2, 'fevrier': 2, 'mars': 3, 'avr': 4, 'avril': 4, 'mai': 5,
  'juin': 6, 'juil': 7, 'juillet': 7, 'août': 8, 'aout': 8, 'sept': 9, 'septembre': 9, 'oct': 10, 'octobre': 10,
  'nov': 11, 'novembre': 11, 'déc': 12, 'dec': 12, 'décembre': 12, 'decembre': 12,
};
const String _frMonthRe =
    r'janvier|janv|février|fevrier|févr|fevr|mars|avril|avr|mai|juin|juillet|juil|août|aout|septembre|sept|octobre|oct|novembre|nov|décembre|decembre|déc|dec';
const String _frWdRe = r'lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|lun|mar|mer|jeu|ven|sam|dim';
const String _frPre = r"(?:(le|du|de|dès|des|jusqu['’]à|jusqu['’]au|avant|pour)\s+)?";

int _frWd(String w) {
  final x = w.toLowerCase().substring(0, 3);
  const l = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
  return l.indexOf(x) + 1;
}

final RegExp _frFollow = RegExp(r'^\s*(?:\d|à\b|a\b|midi|minuit)', caseSensitive: false);

List<_Rule> _frRules() {
  return <_Rule>[
    _Rule('rep', _rx('$_lb(?:tous\\s+les|chaque)\\s+($_frWdRe)s?$_rb'), (m) => '매주 ${_wdKo(_frWd(m.group(1)!))}', pri: 5),
    _Rule('rep', _rx("$_lb(?:tous\\s+les\\s+jours|chaque\\s+jour|quotidien(?:ne)?(?:ment)?)$_rb"), (m) => '매일', pri: 4),
    _Rule('rep', _rx("$_lb(?:en\\s+semaine|jours\\s+ouvr(?:é|e)s|les\\s+jours\\s+ouvr(?:é|e)s|du\\s+lundi\\s+au\\s+vendredi)$_rb"), (m) => '평일마다', pri: 4),
    _Rule('rep', _rx('$_lb(?:chaque\\s+semaine|toutes\\s+les\\s+semaines|hebdomadaire(?:ment)?)$_rb'), (m) => '매주', pri: 3),
    // 날짜 (프랑스어는 일/월 순서)
    _Rule('date', _rx('$_lb$_frPre(\\d{1,2})(?:er|e)?\\s+($_frMonthRe)\\.?(?:\\s+(20\\d{2})(?!\\d))?$_rb'), (m) {
      final mo = _frMonth[m.group(3)!.toLowerCase()]!;
      return _ymd(m.group(4), mo, int.parse(m.group(2)!), _sfx(m.group(1)));
    }, pri: 3),
    _Rule('date', _rx('$_lb$_frPre(?:(?:ce)\\s+)?($_frWdRe)(?:\\s+(prochain|dernier))?$_rb'), (m) {
      final w = m.group(2)!;
      if (w.length <= 3 && m.group(1) == null && m.group(3) == null && !_frFollow.hasMatch(m.input.substring(m.end))) {
        return null;
      }
      final next = m.group(3) != null && m.group(3)!.toLowerCase() == 'prochain' ? '다음 주 ' : '';
      return '$next${_wdKo(_frWd(w))}${_sfx(m.group(1))}';
    }, pri: 2),
    _Rule('date', _rx("$_lb(?:(jusqu['’]à|jusqu['’]au|avant|pour|le)\\s+)?apr(?:è|e)s-demain$_rb"), (m) => '모레${_sfx(m.group(1))}', pri: 3),
    _Rule('date', _rx("$_lb(?:(jusqu['’]à|jusqu['’]au|avant|pour)\\s+)?(aujourd['’]hui|demain)$_rb"), (m) {
      return '${m.group(2)!.toLowerCase() == 'demain' ? '내일' : '오늘'}${_sfx(m.group(1))}';
    }, pri: 2),
    _Rule('date', _rx('${_lb}dans\\s+(\\d{1,3})\\s+(jour|jours|semaine|semaines)$_rb'), (m) {
      return m.group(2)!.toLowerCase().startsWith('s') ? '${m.group(1)}주 후' : '${m.group(1)}일 후';
    }, pri: 3),
    _Rule('date', _rx('$_lb(?:la\\s+)?semaine\\s+(prochaine|dernière)$_rb'), (m) => '다음 주', pri: 3),
    _Rule('date', _rx('$_lb(?:cette\\s+semaine)$_rb'), (m) => '이번 주', pri: 3),
    // 시각 (24시간제: 8h = 오전 8시)
    _Rule('time', _rx('${_lb}midi$_rb'), (m) => '정오', pri: 2),
    _Rule('time', _rx('${_lb}minuit$_rb'), (m) => '자정', pri: 2),
    _Rule('time', _rx('$_lb(?:(?:à|a|de|dès)\\s+)?(\\d{1,2})\\s*h\\s*(\\d{2})?(?![\\p{L}\\d])'), (m) {
      final h = int.parse(m.group(1)!);
      if (h > 24) return null;
      final mm = m.group(2) == null ? 0 : int.parse(m.group(2)!);
      return '${_two(h)}:${_two(mm)}';
    }, pri: 2),
    _Rule('time', _rx('$_lb(?:(?:à|a|de|dès)\\s+)?(\\d{1,2}):(\\d{2})(?![\\d:])(?!\\s*(?:am|pm))'), (m) {
      final h = int.parse(m.group(1)!);
      if (h > 24) return null;
      return '${_two(h)}:${m.group(2)}';
    }, pri: 2),
    _Rule('time', _rx('$_lb(?:(?:à|a|de)\\s+)?(\\d{1,2})(?::(\\d{2}))?\\s*(a\\.?m\\.?|p\\.?m\\.?)(?![\\p{L}])'), (m) {
      final ap = m.group(3)!.toLowerCase().startsWith('p') ? 'pm' : 'am';
      return m.group(2) == null ? '${m.group(1)}$ap' : '${m.group(1)}:${m.group(2)}$ap';
    }, pri: 3),
    // 길이
    _Rule('dur', _rx('$_lb(?:(?:pendant|durant|pour|durée(?:\\s+de)?)\\s+)?(\\d+)\\s*(?:heures?|hrs?)\\s*(?:et\\s+)?(\\d{1,2})\\s*(?:min|mn|minutes?)$_rb'), (m) => '${m.group(1)}시간 ${m.group(2)}분', pri: 5),
    _Rule('dur', _rx('$_lb(?:pendant|durant|pour|durée(?:\\s+de)?)\\s+(\\d+)\\s*h\\s*(?:et\\s+)?(\\d{1,2})\\s*(?:min|mn|minutes?)$_rb'), (m) => '${m.group(1)}시간 ${m.group(2)}분', pri: 5),
    _Rule('dur', _rx('$_lb(?:(?:pendant|durant|pour|durée(?:\\s+de)?)\\s+)(\\d+(?:[.,]\\d+)?)\\s*(?:heures?|hrs?|h)$_rb'), (m) => '${m.group(1)!.replaceAll(',', '.')}시간', pri: 5),
    _Rule('dur', _rx('$_lb(\\d+(?:[.,]\\d+)?)\\s*(?:heures?|hrs?)$_rb'), (m) => '${m.group(1)!.replaceAll(',', '.')}시간', pri: 3),
    _Rule('dur', _rx('$_lb(?:(?:pendant|durant|pour|durée(?:\\s+de)?)\\s+)?(\\d+)\\s*(?:min|mn|minutes?)$_rb'), (m) => '${m.group(1)}분', pri: 3),
    _Rule('dur', _rx('$_lb(?:(?:pendant|durant|pour)\\s+)?une\\s+heure(\\s+et\\s+demie)?$_rb'), (m) => m.group(1) != null ? '1시간 반' : '1시간', pri: 3),
    _Rule('dur', _rx('$_lb(?:(?:pendant|durant|pour)\\s+)?(?:une\\s+)?demi-heure$_rb'), (m) => '30분', pri: 3),
    // 종일
    _Rule('time', _rx('$_lb(?:toute\\s+la\\s+journ(?:é|e)e|journ(?:é|e)e\\s+enti(?:è|e)re|jour\\s+entier)$_rb'), (m) => '종일', pri: 3),
    // 할 일
    _Rule('todo', _rx('$_lb(\\d)\\s*(?:x|fois)\\s*(?:par|/|la)\\s*semaine$_rb'), (m) => '주 ${m.group(1)}번', pri: 4),
    _Rule('todo', _rx('$_lb(?:un\\s+jour|quelque\\s+part|un\\s+de\\s+ces\\s+jours|plus\\s+tard)$_rb'), (m) => '언젠가', pri: 3),
    // 숫자만 쓴 날짜 d/m → m/d
    _Rule('date', _rx(r'(?<![\d/.:\-])(\d{1,2})/(\d{1,2})(?![\d/.:])'), (m) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      if (d < 1 || d > 31 || mo < 1 || mo > 12) return null;
      return '$mo/$d';
    }, pri: 1),
  ];
}

// ---------------------------------------------------------------------------
// 중국어

const Map<String, int> _zhDigit = {
  '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '兩': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
};

/// "三" → 3, "十二" → 12, "二十五" → 25 (아라비아 숫자도 그대로)
int? _zhNum(String s) {
  final d = int.tryParse(s);
  if (d != null) return d;
  if (s.isEmpty) return null;
  if (s == '十') return 10;
  if (s.startsWith('十') && s.length == 2) return 10 + (_zhDigit[s[1]] ?? 0);
  if (s.length == 2 && s[1] == '十') return (_zhDigit[s[0]] ?? 0) * 10;
  if (s.length == 3 && s[1] == '十') return (_zhDigit[s[0]] ?? 0) * 10 + (_zhDigit[s[2]] ?? 0);
  if (s.length == 1) return _zhDigit[s];
  return null;
}

const String _zhNumRe = r'\d{1,2}|[零〇一二两兩三四五六七八九十]{1,3}';
const String _zhWdChar = r'[一二三四五六日天1-7]';

int _zhWdIndex(String c) {
  const m = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7};
  return m[c] ?? 1;
}

String _zhPeriod(String? p) {
  switch (p) {
    case '凌晨':
      return '새벽 ';
    case '早上':
    case '早晨':
    case '清晨':
      return '아침 ';
    case '上午':
      return '오전 ';
    case '中午':
      return '점심 ';
    case '下午':
      return '오후 ';
    case '傍晚':
    case '晚上':
    case '晚间':
      return '저녁 ';
    case '夜里':
    case '夜晚':
      return '밤 ';
  }
  return '';
}

const String _zhPeriodRe = r'凌晨|早上|早晨|清晨|上午|中午|下午|傍晚|晚上|晚间|夜里|夜晚';
const String _zhUntil = r'(?:之前|以前|前|为止|截止|之内|内)?';

List<_Rule> _zhRules() {
  return <_Rule>[
    _Rule('rep', _rx('每(?:个)?(?:周|星期|礼拜|週)($_zhWdChar)', ci: false), (m) => '매주 ${_wdKo(_zhWdIndex(m.group(1)!))}', pri: 6),
    _Rule('rep', _rx('每天|每日|天天', ci: false), (m) => '매일', pri: 4),
    _Rule('rep', _rx('每个工作日|每个工作天|工作日|平日|每个周一至周五', ci: false), (m) => '평일마다', pri: 4),
    _Rule('rep', _rx('每(?:个)?(?:周|星期|礼拜|週)', ci: false), (m) => '매주', pri: 3),
    // 날짜
    _Rule('date', _rx('(?:(从|從)\\s*)?(?:(\\d{4})\\s*年\\s*)?(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*[日号號]?$_zhUntil', ci: false), (m) {
      final tail = m.group(0)!;
      final until = RegExp('(之前|以前|前|为止|截止|之内|内)\$').hasMatch(tail);
      return _ymd(m.group(2), int.parse(m.group(3)!), int.parse(m.group(4)!), until ? '까지' : (m.group(1) != null ? '부터' : ''));
    }, pri: 3),
    _Rule('date', _rx('(\\d{1,2})\\s*[日号號]$_zhUntil', ci: false), (m) {
      final until = RegExp('(之前|以前|前|为止|截止|之内|内)\$').hasMatch(m.group(0)!);
      return '${int.parse(m.group(1)!)}일${until ? '까지' : ''}';
    }, pri: 1),
    _Rule('date', _rx('(下下|下|这|這|本)?(?:个)?(?:周|星期|礼拜|週)($_zhWdChar)$_zhUntil', ci: false), (m) {
      final until = RegExp('(之前|以前|前|为止|截止|之内|内)\$').hasMatch(m.group(0)!);
      return '${_weekPrefix(m.group(1))}${_wdKo(_zhWdIndex(m.group(2)!))}${until ? '까지' : ''}';
    }, pri: 3),
    _Rule('date', _rx('大后天|大後天', ci: false), (m) => '글피', pri: 4),
    _Rule('date', _rx('(?:后天|後天)$_zhUntil', ci: false), (m) => '모레${RegExp('(之前|以前|前|为止|截止)\$').hasMatch(m.group(0)!) ? '까지' : ''}', pri: 3),
    _Rule('date', _rx('(?:今天|今日|今晚|明天|明日|明晚)$_zhUntil', ci: false), (m) {
      final t = m.group(0)!;
      final tomorrow = t.startsWith('明');
      final until = RegExp('(之前|以前|前|为止|截止|之内)\$').hasMatch(t);
      return '${tomorrow ? '내일' : '오늘'}${until ? '까지' : ''}';
    }, pri: 3),
    _Rule('date', _rx('(\\d{1,3})\\s*(?:个)?(天|日|周|星期|週)\\s*(?:以?后|之后|後)', ci: false), (m) {
      final u = m.group(2)!;
      return (u == '天' || u == '日') ? '${m.group(1)}일 후' : '${m.group(1)}주 후';
    }, pri: 4),
    _Rule('date', _rx('(下下|下|这|這|本)(?:个)?(?:周|星期|礼拜|週)(?!$_zhWdChar)(?:内|之内|以内)?', ci: false), (m) {
      final p = _weekPrefix(m.group(1)) ?? '';
      return p.trim();
    }, pri: 2),
    // 시각
    _Rule('time', _rx('(?:(从|從)\\s*)?($_zhPeriodRe)?\\s*($_zhNumRe)\\s*[点點时時]\\s*(?:(半)|(\\d{1,2}|[零〇一二两兩三四五六七八九十]{1,3})\\s*分|(整|钟|鐘))?', ci: false), (m) {
      final h = _zhNum(m.group(3)!);
      if (h == null || h > 24) return null;
      final p = _zhPeriod(m.group(2));
      final half = m.group(4) != null;
      final min = m.group(5) != null ? _zhNum(m.group(5)!) : null;
      final from = m.group(1) != null ? '부터' : '';
      if (half) return '$p$h시 반$from';
      if (min != null) return '$p$h시 $min분$from';
      return '$p$h시$from';
    }, pri: 4),
    _Rule('time', _rx('($_zhPeriodRe)?\\s*(\\d{1,2}):(\\d{2})', ci: false), (m) {
      final p = _zhPeriod(m.group(1));
      final h = int.parse(m.group(2)!);
      if (m.group(1) == null) return '${_two(h)}:${m.group(3)}';
      return '$p$h:${m.group(3)}';
    }, pri: 3),
    _Rule('time', _rx('中午|正午', ci: false), (m) => '정오', pri: 2),
    // 길이
    _Rule('dur', _rx('(\\d+(?:\\.\\d+)?|[一二两兩三四五六七八九十]{1,2})\\s*个?半\\s*(?:小时|小時|钟头|鐘頭)', ci: false), (m) {
      final h = _zhNum(m.group(1)!) ?? 1;
      return '$h시간 반';
    }, pri: 5),
    _Rule('dur', _rx('(\\d+(?:\\.\\d+)?|[一二两兩三四五六七八九十]{1,2})\\s*个?(?:小时|小時|钟头|鐘頭)\\s*(?:(\\d{1,2})\\s*分钟?)?', ci: false), (m) {
      final raw = m.group(1)!;
      final h = double.tryParse(raw) != null ? raw : '${_zhNum(raw) ?? 1}';
      return m.group(2) != null ? '$h시간 ${m.group(2)}분' : '$h시간';
    }, pri: 4),
    _Rule('dur', _rx('半个?(?:小时|小時|钟头|鐘頭)', ci: false), (m) => '30분', pri: 4),
    _Rule('dur', _rx('(\\d+)\\s*(?:分钟|分鐘|分)', ci: false), (m) => '${m.group(1)}분', pri: 3),
    // 종일
    _Rule('time', _rx('一整天|整天|全天|全日', ci: false), (m) => '종일', pri: 3),
    // 할 일
    _Rule('todo', _rx('每周\\s*(\\d)\\s*次|一周\\s*(\\d)\\s*次|每星期\\s*(\\d)\\s*次', ci: false), (m) => '주 ${m.group(1) ?? m.group(2) ?? m.group(3)}번', pri: 5),
    _Rule('todo', _rx('以后再说|有空的时候|改天', ci: false), (m) => '언젠가', pri: 3),
  ];
}

// ---------------------------------------------------------------------------
// 일본어

String _jaPeriod(String? p) {
  switch (p) {
    case '午前':
      return '오전 ';
    case '午後':
      return '오후 ';
    case '朝':
      return '아침 ';
    case '昼':
      return '점심 ';
    case '夕方':
      return '저녁 ';
    case '夜':
      return '밤 ';
  }
  return '';
}

const int _jaWdBase = 0;

int _jaWd(String c) {
  const l = '月火水木金土日';
  return l.indexOf(c) + 1 + _jaWdBase;
}

const String _jaWdChar = r'[月火水木金土日]';
const String _jaTail = r'(まで(?:に)?|から|に)?';

String _jaSfx(String? t) {
  if (t == null) return '';
  if (t.startsWith('まで')) return '까지';
  if (t == 'から') return '부터';
  if (t == 'に') return '에';
  return '';
}

List<_Rule> _jaRules() {
  return <_Rule>[
    _Rule('rep', _rx('毎週($_jaWdChar)曜(?:日)?', ci: false), (m) => '매주 ${_wdKo(_jaWd(m.group(1)!))}', pri: 6),
    _Rule('rep', _rx('毎日|毎朝|毎晩|毎夜', ci: false), (m) => '매일', pri: 4),
    _Rule('rep', _rx('毎平日|平日', ci: false), (m) => '평일마다', pri: 4),
    _Rule('rep', _rx('毎週', ci: false), (m) => '매주', pri: 3),
    // 날짜
    _Rule('date', _rx('(?:(\\d{4})\\s*年\\s*)?(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日(?!間|後|目)$_jaTail', ci: false), (m) {
      return _ymd(m.group(1), int.parse(m.group(2)!), int.parse(m.group(3)!), _jaSfx(m.group(4)));
    }, pri: 3),
    _Rule('date', _rx('(\\d{1,2})\\s*日(?!間|後|目|\\d)$_jaTail', ci: false), (m) => '${int.parse(m.group(1)!)}일${_jaSfx(m.group(2))}', pri: 1),
    _Rule('date', _rx('(再来週|来週|來週|今週)の?($_jaWdChar)曜(?:日)?$_jaTail', ci: false), (m) {
      return '${_weekPrefix(m.group(1))}${_wdKo(_jaWd(m.group(2)!))}${_jaSfx(m.group(3))}';
    }, pri: 4),
    _Rule('date', _rx('($_jaWdChar)曜(?:日)?$_jaTail', ci: false), (m) => '${_wdKo(_jaWd(m.group(1)!))}${_jaSfx(m.group(2))}', pri: 3),
    _Rule('date', _rx('明後日|あさって', ci: false), (m) => '모레', pri: 4),
    _Rule('date', _rx('(?:今日|本日|明日|あした|あす)$_jaTail', ci: false), (m) {
      final t = m.group(0)!;
      final tomorrow = t.startsWith('明日') || t.startsWith('あした') || t.startsWith('あす');
      return '${tomorrow ? '내일' : '오늘'}${_jaSfx(m.group(1))}';
    }, pri: 3),
    _Rule('date', _rx('(\\d{1,3})\\s*(日|週間|週)\\s*後', ci: false), (m) {
      return m.group(2) == '日' ? '${m.group(1)}일 후' : '${m.group(1)}주 후';
    }, pri: 4),
    _Rule('date', _rx('(今週中|今週内|今週)', ci: false), (m) => '이번 주', pri: 2),
    _Rule('date', _rx('(再来週)', ci: false), (m) => '다다음 주', pri: 3),
    _Rule('date', _rx('(来週|來週)', ci: false), (m) => '다음 주', pri: 2),
    // 시각
    _Rule('time', _rx('(午前|午後|朝|昼|夕方|夜)?\\s*(\\d{1,2})\\s*時(?!間)\\s*(?:(半)|(\\d{1,2})\\s*分)?$_jaTail', ci: false), (m) {
      final h = int.parse(m.group(2)!);
      if (h > 24) return null;
      final p = _jaPeriod(m.group(1));
      final sfx = _jaSfx(m.group(5));
      if (m.group(3) != null) return '$p$h시 반$sfx';
      if (m.group(4) != null) return '$p$h시 ${m.group(4)}분$sfx';
      return '$p$h시$sfx';
    }, pri: 4),
    _Rule('time', _rx('(午前|午後|朝|昼|夕方|夜)\\s*(\\d{1,2}):(\\d{2})', ci: false), (m) => '${_jaPeriod(m.group(1))}${int.parse(m.group(2)!)}:${m.group(3)}', pri: 3),
    _Rule('time', _rx('(?<![\\d:])(\\d{1,2}):(\\d{2})(?![\\d:])', ci: false), (m) {
      final h = int.parse(m.group(1)!);
      if (h > 24) return null;
      return '${_two(h)}:${m.group(2)}';
    }, pri: 2),
    _Rule('time', _rx('正午', ci: false), (m) => '정오', pri: 2),
    // 길이
    _Rule('dur', _rx('(\\d+(?:\\.\\d+)?)\\s*時間\\s*(?:(半)|(\\d{1,2})\\s*分)?', ci: false), (m) {
      if (m.group(2) != null) return '${m.group(1)}시간 반';
      if (m.group(3) != null) return '${m.group(1)}시간 ${m.group(3)}분';
      return '${m.group(1)}시간';
    }, pri: 4),
    _Rule('dur', _rx('(\\d+)\\s*分間?', ci: false), (m) => '${m.group(1)}분', pri: 3),
    // 종일
    _Rule('time', _rx('終日|一日中|丸一日|丸1日|1日中', ci: false), (m) => '종일', pri: 4),
    // 할 일
    _Rule('todo', _rx('週\\s*(\\d)\\s*(?:回|日)', ci: false), (m) => '주 ${m.group(1)}번', pri: 5),
    _Rule('todo', _rx('いつか', ci: false), (m) => '언젠가', pri: 3),
  ];
}

// ---------------------------------------------------------------------------

final Map<Lang, List<_Rule>> _ruleCache = <Lang, List<_Rule>>{};

List<_Rule> _rulesFor(Lang lang) {
  return _ruleCache.putIfAbsent(lang, () {
    switch (lang) {
      case Lang.en:
        return _enRules();
      case Lang.fr:
        return _frRules();
      case Lang.zh:
        return _zhRules();
      case Lang.ja:
        return _jaRules();
      case Lang.ko:
        return <_Rule>[];
    }
  });
}

final RegExp _sepRe = RegExp(
  r"^\s*(?:-|–|—|~|〜|～|to|until|till|through|thru|au|à|jusqu['’]à|jusqu['’]au|至|到|から|まで)\s*$",
  caseSensitive: false,
);

/// [input] 의 날짜·시간·길이·반복 표현을 한국어 글로 바꿔요.
Normalized normalizeIntl(String input, Lang lang) {
  final rules = _rulesFor(lang);
  if (rules.isEmpty || input.isEmpty) {
    return Normalized(input, input, <_Seg>[_Seg(0, input.length, 0, input.length, true)]);
  }
  final toks = <_Tok>[];
  for (final r in rules) {
    for (final m in r.re.allMatches(input)) {
      if (m.end == m.start) continue;
      final out = r.fn(m);
      if (out != null) toks.add(_Tok(m.start, m.end, out, r.kind, r.pri));
    }
  }
  toks.sort((a, b) {
    final c = a.s.compareTo(b.s);
    if (c != 0) return c;
    final l = (b.e - b.s).compareTo(a.e - a.s);
    if (l != 0) return l;
    return b.pri.compareTo(a.pri);
  });
  final chosen = <_Tok>[];
  for (final t in toks) {
    if (chosen.isNotEmpty && t.s < chosen.last.e) continue;
    chosen.add(t);
  }

  final buf = StringBuffer();
  final segs = <_Seg>[];
  var pos = 0;
  var outLen = 0;
  var last = ' ';

  void same(int a, int b) {
    if (b <= a) return;
    buf.write(input.substring(a, b));
    segs.add(_Seg(outLen, outLen + (b - a), a, b, true));
    outLen += b - a;
    last = input[b - 1];
  }

  // 바뀐 말은 앞뒤에 빈칸을 둬서 옆 글자와 붙어 읽히지 않게 해요. ("明天下午3点" → "내일 오후 3시")
  void rep(int a, int b, String out, {bool pad = true}) {
    var o = out;
    if (pad) {
      if (last != ' ' && last != '\n' && last != '\t') o = ' $o';
      if (b < input.length && input[b] != ' ' && input[b] != '\n' && input[b] != '\t') o = '$o ';
    }
    buf.write(o);
    segs.add(_Seg(outLen, outLen + o.length, a, b, false));
    outLen += o.length;
    last = o[o.length - 1];
  }

  for (var i = 0; i < chosen.length; i++) {
    final t = chosen[i];
    same(pos, t.s);
    rep(t.s, t.e, t.out);
    pos = t.e;
    if (i + 1 < chosen.length) {
      final n = chosen[i + 1];
      final sameKind = (t.kind == 'date' && n.kind == 'date') || (t.kind == 'time' && n.kind == 'time');
      if (sameKind && n.s > t.e && _sepRe.hasMatch(input.substring(t.e, n.s))) {
        rep(t.e, n.s, '~', pad: false);
        pos = n.s;
      }
    }
  }
  same(pos, input.length);
  return Normalized(buf.toString(), input, segs);
}
