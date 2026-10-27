import 'package:shared_preferences/shared_preferences.dart';

/// 한 번만 보여주는 안내 같은 작은 표시들을 기억해 둬요.
abstract class AppFlags {
  /// 처음 열 때 나오는 "여백은 이렇게 써요" 안내를 이미 봤는지
  bool get welcomeSeen;
  Future<void> setWelcomeSeen(bool v);

  /// 완료 표시한 일정들 ("일정id@날짜" 모양). 프로젝트 화면의 "오늘 일정"에서 눌러 긋는 취소선이에요.
  Set<String> get doneKeys;
  Future<void> setDone(String key, bool done);
}

/// 저장 없이 메모리에만 (테스트·샘플용). 기본은 "이미 봤어요" 라서 안내가 안 떠요.
class MemoryFlags implements AppFlags {
  MemoryFlags({bool welcomeSeen = true}) : _welcome = welcomeSeen;

  bool _welcome;
  final Set<String> _done = <String>{};

  @override
  bool get welcomeSeen => _welcome;

  @override
  Future<void> setWelcomeSeen(bool v) async {
    _welcome = v;
  }

  @override
  Set<String> get doneKeys => _done;

  @override
  Future<void> setDone(String key, bool done) async {
    if (done) {
      _done.add(key);
    } else {
      _done.remove(key);
    }
  }
}

class PrefsFlags implements AppFlags {
  PrefsFlags._(this._prefs, this._welcome, List<String> done) : _done = done;

  static const String _kWelcome = 'welcome_seen_v1';
  static const String _kDone = 'done_events_v1';

  /// 너무 오래 쌓이지 않게 가장 최근 것만 남겨요
  static const int _maxDone = 800;

  final SharedPreferences _prefs;
  bool _welcome;
  final List<String> _done;

  static Future<AppFlags> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PrefsFlags._(prefs, prefs.getBool(_kWelcome) ?? false, prefs.getStringList(_kDone) ?? <String>[]);
    } catch (_) {
      return MemoryFlags();
    }
  }

  @override
  bool get welcomeSeen => _welcome;

  @override
  Future<void> setWelcomeSeen(bool v) async {
    _welcome = v;
    try {
      await _prefs.setBool(_kWelcome, v);
    } catch (_) {}
  }

  @override
  Set<String> get doneKeys => _done.toSet();

  @override
  Future<void> setDone(String key, bool done) async {
    _done.remove(key);
    if (done) _done.add(key);
    if (_done.length > _maxDone) _done.removeRange(0, _done.length - _maxDone);
    try {
      await _prefs.setStringList(_kDone, _done);
    } catch (_) {}
  }
}
