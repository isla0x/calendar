import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 여백에서 따로 정한 것들(색 · 프로젝트 · 할 일 · 이동시간 · 메모)을 한 파일로 묶고 되돌려요.
/// 일정 자체는 기기 캘린더(iCloud)에 있어서 여기에 들어가지 않아요.
class Backup {
  Backup._();

  /// 백업에 들어가는 저장 칸 이름 (기기 저장소의 키)
  static const Map<String, String> keys = <String, String>{
    'event_colors_v1': 'colors',
    'projects_v1': 'projects',
    'todos_v1': 'todos',
    'event_travel_v1': 'travel',
    'place_travel_v1': 'places',
    'memos_v1': 'memos',
  };

  static const String app = 'yeobaek';
  static const int version = 1;

  /// 지금 기기에 있는 값들을 JSON 글자로 묶어요.
  static Future<String> export(SharedPreferences prefs, {DateTime? now}) async {
    final data = <String, Object?>{};
    keys.forEach((k, name) {
      final raw = prefs.getString(k);
      if (raw != null) data[name] = raw;
    });
    return const JsonEncoder.withIndent('  ').convert({
      'app': app,
      'v': version,
      'at': (now ?? DateTime.now()).toIso8601String(),
      'data': data,
    });
  }

  /// 백업에 들어 있는 개수 (안내 화면에 보여줘요)
  static BackupSummary summarize(SharedPreferences prefs) {
    int count(String key) {
      final raw = prefs.getString(key);
      if (raw == null) return 0;
      try {
        final j = jsonDecode(raw);
        if (j is List) return j.length;
        if (j is Map) return j.length;
      } catch (_) {}
      return 0;
    }

    return BackupSummary(
      colors: count('event_colors_v1'),
      projects: count('projects_v1'),
      todos: count('todos_v1'),
      travel: count('event_travel_v1'),
      memos: count('memos_v1'),
    );
  }

  /// 백업 글자를 읽어 기기에 덮어써요. 올바른 백업이 아니면 null (아무것도 안 바뀌어요).
  static Future<BackupSummary?> import(SharedPreferences prefs, String text) async {
    final Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (j is! Map || j['app'] != app) return null;
    final data = j['data'];
    if (data is! Map) return null;
    // 먼저 전부 읽어 보고, 문제가 없을 때만 씁니다.
    final next = <String, String>{};
    for (final e in keys.entries) {
      final v = data[e.value];
      if (v == null) continue;
      if (v is! String) return null;
      try {
        jsonDecode(v);
      } catch (_) {
        return null;
      }
      next[e.key] = v;
    }
    if (next.isEmpty) return null;
    for (final e in next.entries) {
      await prefs.setString(e.key, e.value);
    }
    return summarize(prefs);
  }
}

class BackupSummary {
  const BackupSummary({this.colors = 0, this.projects = 0, this.todos = 0, this.travel = 0, this.memos = 0});

  final int colors;
  final int projects;
  final int todos;
  final int travel;
  final int memos;

  bool get isEmpty => colors + projects + todos + travel + memos == 0;
}
