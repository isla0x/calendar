import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 일정마다 따로 고른 색을 기억해 두는 곳.
/// (기기 캘린더에는 일정별 색이 없어서, 앱 안에 일정 id → 색으로 저장해요.)
abstract class ColorBook {
  Color? of(String eventId);
  Future<void> set(String eventId, Color? color);
}

/// 저장 없이 메모리에만 (테스트·샘플용)
class MemoryColorBook implements ColorBook {
  final Map<String, Color> _m = <String, Color>{};

  @override
  Color? of(String eventId) => _m[eventId];

  @override
  Future<void> set(String eventId, Color? color) async {
    if (color == null) {
      _m.remove(eventId);
    } else {
      _m[eventId] = color;
    }
  }
}

/// 기기에 저장 (앱을 껐다 켜도 남아요)
class PrefsColorBook implements ColorBook {
  PrefsColorBook._(this._prefs, this._m);

  static const String _key = 'event_colors_v1';

  final SharedPreferences _prefs;
  final Map<String, int> _m;

  static Future<ColorBook> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final m = <String, int>{};
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          j.forEach((k, v) {
            if (k is String && v is int) m[k] = v;
          });
        }
      }
      return PrefsColorBook._(prefs, m);
    } catch (_) {
      return MemoryColorBook();
    }
  }

  @override
  Color? of(String eventId) {
    final v = _m[eventId];
    return v == null ? null : Color(v);
  }

  @override
  Future<void> set(String eventId, Color? color) async {
    if (color == null) {
      _m.remove(eventId);
    } else {
      _m[eventId] = color.toARGB32();
    }
    try {
      await _prefs.setString(_key, jsonEncode(_m));
    } catch (_) {}
  }
}
