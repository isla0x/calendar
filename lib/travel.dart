import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 일정 하나에 붙은 이동시간 (분). 갈 때 = 시작 전, 올 때 = 끝난 뒤.
class Travel {
  const Travel({this.before = 0, this.after = 0});

  static const Travel none = Travel();

  /// 고를 수 있는 길이 (분)
  static const List<int> choices = <int>[0, 10, 20, 30, 45, 60, 90, 120];

  final int before;
  final int after;

  bool get isNone => before <= 0 && after <= 0;

  Travel copyWith({int? before, int? after}) =>
      Travel(before: before ?? this.before, after: after ?? this.after);

  @override
  bool operator ==(Object other) =>
      other is Travel && other.before == before && other.after == after;

  @override
  int get hashCode => Object.hash(before, after);

  /// '30분', '1시간', '1시간 30분'
  static String minText(int m) {
    if (m < 60) return '$m분';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h시간' : '$h시간 $r분';
  }

  /// 한 줄 설명. 같으면 '왕복 30분씩', 다르면 '갈 때 30분 · 올 때 10분'
  String get label {
    if (isNone) return '없음';
    if (before == after) return '갈 때·올 때 ${minText(before)}씩';
    final parts = <String>[
      if (before > 0) '갈 때 ${minText(before)}',
      if (after > 0) '올 때 ${minText(after)}',
    ];
    return parts.join(' · ');
  }

  /// 칩에 넣을 짧은 글자
  String get shortLabel {
    if (isNone) return '이동시간';
    if (before == after) return '이동 ${minText(before)}씩';
    if (after == 0) return '이동 ${minText(before)}';
    if (before == 0) return '귀가 ${minText(after)}';
    return '이동 ${minText(before)}+${minText(after)}';
  }
}

/// 이동시간을 기억해 두는 곳 (일정 id → 이동시간)
abstract class TravelBook {
  Travel of(String eventId);
  Future<void> set(String eventId, Travel travel);

  /// 장소별로 기억해 둔 이동시간 (없으면 Travel.none)
  Travel ofPlace(String place);
  Future<void> setPlace(String place, Travel? travel);

  /// 기억해 둔 장소들 (이름, 이동시간) — 최근에 쓴 순서
  List<(String, Travel)> places();
}

/// 장소 글자를 비교하기 좋게 다듬어요 (공백·대소문자 무시)
String placeKey(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 저장 없이 메모리에만 (테스트·샘플용)
class MemoryTravelBook implements TravelBook {
  final Map<String, Travel> _m = <String, Travel>{};
  final Map<String, (String, Travel)> _p = <String, (String, Travel)>{};

  @override
  Travel ofPlace(String place) => _p[placeKey(place)]?.$2 ?? Travel.none;

  @override
  Future<void> setPlace(String place, Travel? travel) async {
    final k = placeKey(place);
    if (k.isEmpty) return;
    _p.remove(k);
    if (travel != null && !travel.isNone) _p[k] = (place.trim(), travel);
  }

  @override
  List<(String, Travel)> places() => _p.values.toList().reversed.toList();

  @override
  Travel of(String eventId) => _m[eventId] ?? Travel.none;

  @override
  Future<void> set(String eventId, Travel travel) async {
    if (travel.isNone) {
      _m.remove(eventId);
    } else {
      _m[eventId] = travel;
    }
  }
}

/// 기기에 저장 (앱을 껐다 켜도 남아요)
class PrefsTravelBook implements TravelBook {
  PrefsTravelBook._(this._prefs, this._m);

  static const String _key = 'event_travel_v1';
  static const String _keyPlaces = 'place_travel_v1';

  final SharedPreferences _prefs;
  final Map<String, Travel> _m;

  /// 장소 키 → (보이는 이름, 이동시간). 넣은 순서가 곧 오래된 순서예요.
  final Map<String, (String, Travel)> _p = <String, (String, Travel)>{};

  void _loadPlaces() {
    try {
      final raw = _prefs.getString(_keyPlaces);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! List) return;
      for (final x in j) {
        if (x is List && x.length == 3 && x[0] is String && x[1] is int && x[2] is int) {
          final t = Travel(before: x[1] as int, after: x[2] as int);
          final k = placeKey(x[0] as String);
          if (k.isNotEmpty && !t.isNone) _p[k] = (x[0] as String, t);
        }
      }
    } catch (_) {}
  }

  @override
  Travel ofPlace(String place) => _p[placeKey(place)]?.$2 ?? Travel.none;

  @override
  Future<void> setPlace(String place, Travel? travel) async {
    final k = placeKey(place);
    if (k.isEmpty) return;
    _p.remove(k);
    if (travel != null && !travel.isNone) _p[k] = (place.trim(), travel);
    try {
      await _prefs.setString(
        _keyPlaces,
        jsonEncode([for (final v in _p.values) [v.$1, v.$2.before, v.$2.after]]),
      );
    } catch (_) {}
  }

  @override
  List<(String, Travel)> places() => _p.values.toList().reversed.toList();

  static Future<TravelBook> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final m = <String, Travel>{};
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          j.forEach((k, v) {
            if (k is String && v is List && v.length == 2 && v[0] is int && v[1] is int) {
              final t = Travel(before: v[0] as int, after: v[1] as int);
              if (!t.isNone) m[k] = t;
            }
          });
        }
      }
      final b = PrefsTravelBook._(prefs, m);
      b._loadPlaces();
      return b;
    } catch (_) {
      return MemoryTravelBook();
    }
  }

  @override
  Travel of(String eventId) => _m[eventId] ?? Travel.none;

  @override
  Future<void> set(String eventId, Travel travel) async {
    if (travel.isNone) {
      _m.remove(eventId);
    } else {
      _m[eventId] = travel;
    }
    try {
      await _prefs.setString(
        _key,
        jsonEncode({for (final e in _m.entries) e.key: [e.value.before, e.value.after]}),
      );
    } catch (_) {}
  }
}
