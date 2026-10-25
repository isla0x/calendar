import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 앱에 넣어 둔 글꼴(IBM Plex Sans KR)을 쓸지 여부. 테스트에서는 false 로 둬요.
bool useWebFont = true;

/// 앱 전체 색. 목업의 라이트 / 다크 값 그대로예요.
class Pal {
  const Pal({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.soft,
    required this.dash,
    required this.red,
    required this.blue,
    required this.now,
    required this.nowFg,
    required this.shadow,
    required this.busy1,
    required this.busy2,
    required this.busy3,
    required this.good,
    required this.sheet,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color soft;
  final Color dash;
  final Color red;
  final Color blue;
  final Color now;
  final Color nowFg;
  final Color shadow;
  final Color busy1;
  final Color busy2;
  final Color busy3;
  final Color good;

  /// 하단 시트 배경
  final Color sheet;

  static const Pal light = Pal(
    dark: false,
    bg: Color(0xFFF6F5F1),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF16161A),
    muted: Color(0xFF6A6A72),
    line: Color(0xFFE6E3DC),
    soft: Color(0xFFECEAE3),
    dash: Color(0xFFBDB8AB),
    red: Color(0xFFB84B4B),
    blue: Color(0xFF4A62B5),
    now: Color(0xFFC0563C),
    nowFg: Color(0xFFFFFFFF),
    shadow: Color(0x2416161A),
    busy1: Color(0x0916161A),
    busy2: Color(0x1216161A),
    busy3: Color(0x1F16161A),
    good: Color(0xFF0F6B4A),
    sheet: Color(0xFFFFFFFF),
  );

  static const Pal darkPal = Pal(
    dark: true,
    bg: Color(0xFF0E0E11),
    surface: Color(0xFF17171B),
    ink: Color(0xFFF3F3F5),
    muted: Color(0xFF9A9AA4),
    line: Color(0xFF2A2A31),
    soft: Color(0xFF1F1F25),
    dash: Color(0xFF4A4A54),
    red: Color(0xFFF29A9A),
    blue: Color(0xFFA5B4F2),
    now: Color(0xFFF2866B),
    nowFg: Color(0xFF1A0B07),
    shadow: Color(0x80000000),
    busy1: Color(0x0AFFFFFF),
    busy2: Color(0x14FFFFFF),
    busy3: Color(0x21FFFFFF),
    good: Color(0xFF86E3BB),
    sheet: Color(0xFF17171B),
  );

  static Pal of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPal : light;
}

/// 일정 색 하나로부터 만드는 색 묶음
class EvColors {
  const EvColors({
    required this.strong,
    required this.tint,
    required this.text,
    required this.solid,
    required this.onSolid,
  });

  /// 점·막대
  final Color strong;

  /// 일정 블록 배경
  final Color tint;

  /// 블록 안 글자
  final Color text;

  /// "다음 일정" 강조 배경
  final Color solid;
  final Color onSolid;
}

/// 기기 캘린더 색은 대체로 쨍해서, 채도를 낮추고 밝기를 고르게 맞춘 차분한 색으로 바꿔요.
Color calmColor(Color c) {
  final h = HSLColor.fromColor(c);
  return h
      .withSaturation((h.saturation * 0.62).clamp(0.0, 0.58))
      .withLightness(h.lightness.clamp(0.42, 0.60))
      .toColor();
}

EvColors evColors(Color base, Pal p) {
  final hsl = HSLColor.fromColor(base);
  if (p.dark) {
    return EvColors(
      strong: base,
      tint: Color.alphaBlend(base.withAlpha(60), p.surface),
      text: hsl
          .withLightness(0.80)
          .withSaturation(math.min(hsl.saturation, 0.9))
          .toColor(),
      solid: hsl.withLightness(0.90).toColor(),
      onSolid: hsl.withLightness(0.20).toColor(),
    );
  }
  return EvColors(
    strong: base,
    tint: Color.alphaBlend(base.withAlpha(38), Colors.white),
    text: hsl.withLightness(0.30).toColor(),
    solid: hsl.withLightness(0.36).withSaturation(hsl.saturation * 0.85).toColor(),
    onSolid: Colors.white,
  );
}

/// 글자 스타일 한 줄로 만들기
TextStyle ts(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w500,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  final style = TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color ?? Pal.of(context).ink,
    height: height,
    letterSpacing: letterSpacing ?? (size >= 24 ? -size * 0.03 : -0.15),
    fontFeatures: const [FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
  );
  if (useWebFont) return style.copyWith(fontFamily: 'IBMPlexSansKR');
  return style;
}

ThemeData buildTheme(Pal p) {
  final brightness = p.dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.ink,
    brightness: brightness,
  ).copyWith(
    surface: p.surface,
    onSurface: p.ink,
    primary: p.ink,
    onPrimary: p.bg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.line,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
