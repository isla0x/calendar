import 'package:flutter/painting.dart';

import 'theme.dart';

/// 앱 전체 색 조합 하나. 바탕·글자·포인트색과 일정 색 5개(업무·개인·약속·운동·공부)를 한 묶음으로 가져요.
class Skin {
  Skin({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    required this.events,
    required this.holiday,
  });

  final String id;
  final String name;
  final Pal light;
  final Pal dark;

  /// 업무 · 개인 · 약속 · 운동 · 공부 순서
  final List<Color> events;
  final Color holiday;

  /// 지금 앱이 쓰는 조합
  static Skin current = pastel;

  /// 파스텔: 남색·초록·분홍·노랑·보라 계열은 그대로, 전부 부드러운 파스텔로
  static final Skin pastel = Skin(
    id: 'pastel',
    name: '파스텔',
    light: const Pal(
      dark: false,
      bg: Color(0xFFFAF7F2),
      surface: Color(0xFFFFFFFF),
      ink: Color(0xFF2B2D42),
      muted: Color(0xFF7D7F92),
      line: Color(0xFFEDE8E0),
      soft: Color(0xFFF2EEE7),
      dash: Color(0xFFD2CCC0),
      red: Color(0xFFD67171),
      blue: Color(0xFF798CD8),
      now: Color(0xFFF3A086),
      nowFg: Color(0xFF3B1F18),
      shadow: Color(0x242B2D42),
      busy1: Color(0x0A2B2D42),
      busy2: Color(0x142B2D42),
      busy3: Color(0x212B2D42),
      good: Color(0xFF3A8F70),
      sheet: Color(0xFFFFFFFF),
      pastel: true,
    ),
    dark: _dark(
      235,
      red: const Color(0xFFF2A0A0),
      blue: const Color(0xFFA9B6F2),
      now: const Color(0xFFF4A58F),
    ),
    events: const [
      Color(0xFF909FEA),
      Color(0xFF79CDB1),
      Color(0xFFEF9ABC),
      Color(0xFFF6CC6A),
      Color(0xFFBBA0E9),
    ],
    holiday: const Color(0xFFE99895),
  );

  /// 이전에 쓰던 진한 조합 (비교용)
  static final Skin classic = Skin(
    id: 'classic',
    name: '이전 색',
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
