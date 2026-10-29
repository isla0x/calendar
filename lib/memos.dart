import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';

/// 날짜에 붙는 한 줄 메모. 시간은 없고, 끝낸 건 줄을 그어요.
class Memo {
  const Memo({required this.id, required this.day, required this.text, this.done = false});

  final String id;

  /// 어느 날의 메모인지 (날짜만)
  final DateTime day;
  final String text;
  final bool done;

  Memo copyWith({DateTime? day, String? text, bool? done}) => Memo(
        id: id,
        day: day ?? this.day,
        text: text ?? this.text,
        done: done ?? this.done,
      );

  Map<String, Object> toJson() => <String, Object>{
        'i': id,
        'd': '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        't': text,
        if (done) 'x': 1,
      };

  static Memo? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['i'];
    final d = j['d'];
    final t = j['t'];
    if (id is! String || d is! String || t is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(d);
    if (m == null) return null;
    final day = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (t.trim().isEmpty) return null;
    return Memo(id: id, day: dayOnly(day), text: t, done: j['x'] == 1);
  }
}

/// 한 번에 적은 글을 줄 단위로 나눠요. 빈 줄은 버리고, 앞의 점(·, -, •)은 지워요.
List<String> splitMemoLines(String text) {
  final out = <String>[];
  for (final raw in text.split(RegExp(r'[\r\n]+'))) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^[·•\-]\s+'), '').trim();
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

abstract class MemoBook {
  List<Memo> load();
  Future<void> save(List<Memo> all);
}

class MemoryMemoBook implements MemoBook {
  MemoryMemoBook([List<Memo>? initial]) : _all = List<Memo>.of(initial ?? const <Memo>[]);

  List<Memo> _all;

  @override
  List<Memo> load() => List<Memo>.of(_all);

  @override
  Future<void> save(List<Memo> all) async {
    _all = List<Memo>.of(all);
  }
}

/// 기기에 저장 (앱을 껐다 켜도 남아요). 일정처럼 캘린더에 들어가지 않고 여백 안에만 있어요.
class PrefsMemoBook implements MemoBook {
  PrefsMemoBook._(this._prefs, this._all);

  static const String key = 'memos_v1';

  final SharedPreferences _prefs;
  List<Memo> _all;

  static Future<MemoBook> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final all = <Memo>[];
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is List) {
          for (final x in j) {
            final m = Memo.fromJson(x);
            if (m != null) all.add(m);
          }
        }
      }
      return PrefsMemoBook._(prefs, all);
    } catch (_) {
      return MemoryMemoBook();
    }
  }

  @override
  List<Memo> load() => List<Memo>.of(_all);

  @override
  Future<void> save(List<Memo> all) async {
    _all = List<Memo>.of(all);
    try {
      await _prefs.setString(key, jsonEncode([for (final m in all) m.toJson()]));
    } catch (_) {}
  }
}
