import 'package:flutter/painting.dart';

/// 일정 제목 속 "#태그" 를 다루는 도우미.
///
/// 기기 캘린더에는 태그 칸이 없어서, 태그는 제목 끝에 "#태그" 로 붙여서 저장해요.
/// (예: "치과 #건강")  앱에서는 제목과 태그를 나눠서 보여줘요.
final RegExp _tagRe = RegExp(r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)', unicode: true);

/// 태그에 쓸 수 있는 글자(글자·숫자·밑줄)만 남겨요.
final RegExp _notTagChar = RegExp(r'[^\p{L}\p{N}_]', unicode: true);

class TitleParts {
  const TitleParts(this.title, this.tags);

  /// 태그를 뗀 제목
  final String title;
  final List<String> tags;
}

/// "치과 #건강 #병원" → 제목 "치과", 태그 [건강, 병원]
TitleParts splitTags(String raw) {
  final tags = <String>[];
  for (final m in _tagRe.allMatches(raw)) {
    final t = m.group(1);
    if (t != null && !tags.contains(t)) tags.add(t);
  }
  if (tags.isEmpty) return TitleParts(raw, const <String>[]);
  final clean = raw.replaceAll(_tagRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // 태그만 있는 제목은 그대로 둬요.
  if (clean.isEmpty) return TitleParts(raw.trim(), const <String>[]);
  return TitleParts(clean, tags);
}

/// 제목 뒤에 태그를 "#태그" 로 붙여요.
String joinTags(String title, List<String> tags) {
  if (tags.isEmpty) return title;
  return '$title ${tags.map((t) => '#$t').join(' ')}';
}

/// 사람이 입력한 글("#회의 업무, 건강")을 태그 목록으로 바꿔요. 같은 태그는 한 번만.
List<String> tagsFromText(String text) {
  final out = <String>[];
  for (final part in text.split(RegExp(r'[\s,]+'))) {
    final t = part.replaceAll(_notTagChar, '');
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out;
}

/// 태그마다 정해진 색 (같은 태그는 항상 같은 색)
Color tagColor(String tag, {required bool dark}) {
  var h = 0;
  for (final u in tag.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), dark ? 0.55 : 0.50, dark ? 0.78 : 0.42)
      .toColor();
}
