import 'package:shared_preferences/shared_preferences.dart';

/// 한 번만 보여주는 안내 같은 작은 표시들을 기억해 둬요.
abstract class AppFlags {
  /// 처음 열 때 나오는 "여백은 이렇게 써요" 안내를 이미 봤는지
  bool get welcomeSeen;
  Future<void> setWelcomeSeen(bool v);
}

/// 저장 없이 메모리에만 (테스트·샘플용). 기본은 "이미 봤어요" 라서 안내가 안 떠요.
class MemoryFlags implements AppFlags {
  MemoryFlags({bool welcomeSeen = true}) : _welcome = welcomeSeen;

  bool _welcome;

  @override
  bool get welcomeSeen => _welcome;

  @override
  Future<void> setWelcomeSeen(bool v) async {
    _welcome = v;
  }
}

class PrefsFlags implements AppFlags {
  PrefsFlags._(this._prefs, this._welcome);

  static const String _kWelcome = 'welcome_seen_v1';

  final SharedPreferences _prefs;
  bool _welcome;

  static Future<AppFlags> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PrefsFlags._(prefs, prefs.getBool(_kWelcome) ?? false);
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
}
