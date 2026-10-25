import 'package:flutter/painting.dart';

import 'theme.dart';

/// 앱 전체 색 조합 하나. 바탕·글자·포인트색과 일정 색 5개(업무·개인·약속·운동·공부)를 한 묶음으로 가져요.
class Skin {
  Skin({
    required this.id,
    required this.name,
    required this.desc,
    required this.light,
    required this.dark,
    required this.events,
    required this.holiday,
  });

  final String id;
  final String name;
  final String desc;
  final Pal light;
  final Pal dark;

  /// 업무 · 개인 · 약속 · 운동 · 공부 순서
  final List<Color> events;
  final Color holiday;

  /// 지금 앱이 쓰는 조합. 고르면 여기만 바꾸면 돼요.
  static Skin current = classic;

  /// 지금까지 쓰던 색 (비교용)
  static final Skin classic = Skin(
    id: 'classic',
    name: '지금 색',
    desc: '지금까지 쓰던 조합',
    light: Pal.light,
    dark: Pal.darkPal,
    events: const [
      Color(0xFF5E71D4),
      Color(0xFF3F9777),
      Color(0xFFCA688F),
      Color(0xFFBF9533),
      Color(0xFF8361D1),
    ],
    holiday: const Color(0xFFA64A4A),
  );

  static final Skin fog = Skin(
    id: 'fog',
    name: '안개',
    desc: '차분한 회청색 바탕에 산호빛 포인트',
    light: _light(
      bg: const Color(0xFFF2F4F8),
      surface: const Color(0xFFFFFFFF),
      ink: const Color(0xFF131A28),
      muted: const Color(0xFF667186),
      line: const Color(0xFFE0E5EC),
      soft: const Color(0xFFE7EBF1),
      dash: const Color(0xFFB5BFCE),
      red: const Color(0xFFC0626B),
      blue: const Color(0xFF4A66A8),
      now: const Color(0xFFD26A57),
      good: const Color(0xFF237A62),
    ),
    dark: _dark(
      215,
      red: const Color(0xFFF0A0A8),
      blue: const Color(0xFF9DB5EA),
      now: const Color(0xFFE88B78),
    ),
    events: const [
      Color(0xFF5F7FAE),
      Color(0xFF6FA391),
      Color(0xFFC98493),
      Color(0xFFCDA862),
      Color(0xFF9087BC),
    ],
    holiday: const Color(0xFFC0626B),
  );

  static final Skin forest = Skin(
    id: 'forest',
    name: '숲',
    desc: '크림 바탕에 깊은 초록, 풀과 흙 색 일정',
    light: _light(
      bg: const Color(0xFFF3F3EC),
      surface: const Color(0xFFFFFFFF),
      ink: const Color(0xFF16201A),
      muted: const Color(0xFF667068),
      line: const Color(0xFFE0E2D6),
      soft: const Color(0xFFE8EADF),
      dash: const Color(0xFFB8BDA9),
      red: const Color(0xFFB65B4E),
      blue: const Color(0xFF4F6D8C),
      now: const Color(0xFF2F6F57),
      good: const Color(0xFF2F7A5B),
    ),
    dark: _dark(
      150,
      red: const Color(0xFFF0A398),
      blue: const Color(0xFF9DB8D2),
      now: const Color(0xFF7FCFA9),
    ),
    events: const [
      Color(0xFF4F7F6C),
      Color(0xFF8E9D5E),
      Color(0xFFC98A68),
      Color(0xFFD1AB52),
      Color(0xFF6D8EA6),
    ],
    holiday: const Color(0xFFB65B4E),
  );

  static final Skin earth = Skin(
    id: 'earth',
    name: '흙',
    desc: '따뜻한 베이지에 테라코타, 흙 계열 일정',
    light: _light(
      bg: const Color(0xFFF7F1E8),
      surface: const Color(0xFFFFFDFA),
      ink: const Color(0xFF2B211B),
      muted: const Color(0xFF7B6E64),
      line: const Color(0xFFEADFD1),
      soft: const Color(0xFFF0E6D9),
      dash: const Color(0xFFC8B8A5),
      red: const Color(0xFFB24A3E),
      blue: const Color(0xFF5B6F8E),
      now: const Color(0xFFC45F3F),
      good: const Color(0xFF4A7A52),
    ),
    dark: _dark(
      28,
      red: const Color(0xFFF2A090),
      blue: const Color(0xFFA5B4D2),
      now: const Color(0xFFF2866B),
    ),
    events: const [
      Color(0xFF5E8C8A),
      Color(0xFF8D9352),
      Color(0xFFC86A52),
      Color(0xFFD2A24C),
      Color(0xFF96637F),
    ],
    holiday: const Color(0xFFA94B40),
  );

  static final Skin inkSeal = Skin(
    id: 'ink',
    name: '먹과 인주',
    desc: '한지 같은 흰색과 먹색, 붉은 도장 한 점',
    light: _light(
      bg: const Color(0xFFF6F5F1),
      surface: const Color(0xFFFFFFFF),
      ink: const Color(0xFF111114),
      muted: const Color(0xFF6B6B70),
      line: const Color(0xFFE4E2DC),
      soft: const Color(0xFFEBE9E3),
      dash: const Color(0xFFBBB8AE),
      red: const Color(0xFFC8442F),
      blue: const Color(0xFF3F4D66),
      now: const Color(0xFFD4482F),
      good: const Color(0xFF2E6B50),
    ),
    dark: _dark(
      40,
      red: const Color(0xFFF2998A),
      blue: const Color(0xFFA9B3C7),
      now: const Color(0xFFF06A50),
    ),
    events: const [
      Color(0xFF3F4756),
      Color(0xFF9EA3AB),
      Color(0xFFD4573D),
      Color(0xFFA99E8A),
      Color(0xFF6D7686),
    ],
    holiday: const Color(0xFFC8442F),
  );

  static final Skin lilac = Skin(
    id: 'lilac',
    name: '라일락',
    desc: '연보라 바탕에 보라 포인트',
    light: _light(
      bg: const Color(0xFFF5F3F9),
      surface: const Color(0xFFFFFFFF),
      ink: const Color(0xFF1B1730),
      muted: const Color(0xFF6E6A86),
      line: const Color(0xFFE5E1EE),
      soft: const Color(0xFFECE8F4),
      dash: const Color(0xFFBBB5D0),
      red: const Color(0xFFC05A7C),
      blue: const Color(0xFF5667B5),
      now: const Color(0xFF7A58C2),
      good: const Color(0xFF2E7A66),
    ),
    dark: _dark(
      255,
      red: const Color(0xFFF29ABB),
      blue: const Color(0xFFAEB8F2),
      now: const Color(0xFFB79CF2),
    ),
    events: const [
      Color(0xFF7E76BC),
      Color(0xFF5F9E98),
      Color(0xFFD083A3),
      Color(0xFFD3A862),
      Color(0xFF5F8BBD),
    ],
    holiday: const Color(0xFFC05A7C),
  );

  /// 고를 수 있는 후보들
  static final List<Skin> candidates = [fog, forest, earth, inkSeal, lilac];

  static Pal _light({
    required Color bg,
    required Color surface,
    required Color ink,
    required Color muted,
    required Color line,
    required Color soft,
    required Color dash,
    required Color red,
    required Color blue,
    required Color now,
    required Color good,
  }) {
    return Pal(
      dark: false,
      bg: bg,
      surface: surface,
      ink: ink,
      muted: muted,
      line: line,
      soft: soft,
      dash: dash,
      red: red,
      blue: blue,
      now: now,
      nowFg: const Color(0xFFFFFFFF),
      shadow: ink.withAlpha(0x24),
      busy1: ink.withAlpha(0x09),
      busy2: ink.withAlpha(0x12),
      busy3: ink.withAlpha(0x1F),
      good: good,
      sheet: surface,
    );
  }

  static Color _hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, h, s, l).toColor();

  /// 다크 모드: 같은 색상(hue)으로 살짝 물들인 어두운 바탕
  static Pal _dark(
    double hue, {
    required Color red,
    required Color blue,
    required Color now,
  }) {
    final surface = _hsl(hue, 0.12, 0.09);
    return Pal(
      dark: true,
      bg: _hsl(hue, 0.14, 0.06),
      surface: surface,
      ink: _hsl(hue, 0.20, 0.96),
      muted: _hsl(hue, 0.08, 0.64),
      line: _hsl(hue, 0.10, 0.17),
      soft: _hsl(hue, 0.10, 0.12),
      dash: _hsl(hue, 0.08, 0.30),
      red: red,
      blue: blue,
      now: now,
      nowFg: const Color(0xFF1A0B07),
      shadow: const Color(0x80000000),
      busy1: const Color(0x0AFFFFFF),
      busy2: const Color(0x14FFFFFF),
      busy3: const Color(0x21FFFFFF),
      good: const Color(0xFF86E3BB),
      sheet: surface,
    );
  }
}
