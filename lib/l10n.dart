import 'dart:ui' show Locale;

import 'l10n/en.dart';
import 'l10n/fr.dart';
import 'l10n/ja.dart';
import 'l10n/zh.dart';

/// 앱이 지원하는 언어
enum Lang { ko, en, fr, zh, ja }

/// 지금 쓰는 언어. 폰 언어 설정을 따라가요. (지원하지 않는 언어는 영어)
class L10n {
  L10n._();

  static Lang lang = Lang.ko;

  static const List<Locale> supported = <Locale>[
    Locale('ko', 'KR'),
    Locale('en', 'US'),
    Locale('fr', 'FR'),
    Locale('zh', 'CN'),
    Locale('ja', 'JP'),
  ];

  /// 언어 코드(ko, en, …)로 [Lang] 을 골라요. 모르는 코드는 영어.
  static Lang fromCode(String? code) {
    switch (code) {
      case 'ko':
        return Lang.ko;
      case 'fr':
        return Lang.fr;
      case 'zh':
        return Lang.zh;
      case 'ja':
        return Lang.ja;
      default:
        return Lang.en;
    }
  }

  /// 폰이 알려 준 언어 목록(우선순위 순)에서 지원하는 첫 언어를 써요.
  static Lang pick(List<Locale> locales) {
    for (final l in locales) {
      final code = l.languageCode;
      if (code == 'ko' || code == 'en' || code == 'fr' || code == 'zh' || code == 'ja') {
        return fromCode(code);
      }
    }
    return Lang.en;
  }

  static Locale get locale => supported[lang.index];

  static Map<String, String>? _table(Lang l) {
    switch (l) {
      case Lang.ko:
        return null;
      case Lang.en:
        return kEn;
      case Lang.fr:
        return kFr;
      case Lang.zh:
        return kZh;
      case Lang.ja:
        return kJa;
    }
  }

  /// 번역된 글(없으면 한국어 원문)
  static String lookup(String ko) => _table(lang)?[ko] ?? ko;
}

/// 한국어 원문 [ko] 를 지금 언어로 바꿔요. `{0}`, `{1}` 자리에는 [args] 가 순서대로 들어가요.
String tl(String ko, [List<Object?> args = const <Object?>[]]) {
  final s = L10n.lookup(ko);
  if (args.isEmpty) return s;
  return s.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) {
    final i = int.parse(m.group(1)!);
    return i < args.length ? '${args[i]}' : m.group(0)!;
  });
}
