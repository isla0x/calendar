import 'package:flutter/material.dart';

import '../theme.dart';

/// 눌리는 곳. 아이콘만 있는 버튼은 label 을 꼭 넣어요(화면 읽기용).
class Tap extends StatelessWidget {
  const Tap({super.key, required this.onTap, required this.child, this.label});

  final VoidCallback? onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget w = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
    if (label != null) {
      w = Semantics(button: true, label: label, excludeSemantics: true, child: w);
    }
    return w;
  }
}

/// 둥근 알약 모양 (칩). child 는 가운데 정렬돼요.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    this.height = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.color,
    this.ring = false,
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? color;

  /// 얇은 테두리
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: ring ? Border.all(color: p.line) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [child],
      ),
    );
  }
}

/// 점선 테두리 상자 (비는 시간, 비어 있는 칩)
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.radius, this.child});

  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(Pal.of(context).dash, radius),
      child: child,
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.75);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final next = d + 5 > m.length ? m.length : d + 5;
        canvas.drawPath(m.extractPath(d, next), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.radius != radius;
}

/// 반짝이 아이콘 (한 줄 입력 막대)
class SparkleIcon extends StatelessWidget {
  const SparkleIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(color ?? Pal.of(context).ink),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    Offset o(double x, double y) => Offset(x * k, y * k);
    final path = Path()
      ..moveTo(12 * k, 3 * k)
      ..lineTo(o(14, 9).dx, o(14, 9).dy)
      ..lineTo(o(20, 11).dx, o(20, 11).dy)
      ..lineTo(o(14, 13).dx, o(14, 13).dy)
      ..lineTo(o(12, 19).dx, o(12, 19).dy)
      ..lineTo(o(10, 13).dx, o(10, 13).dy)
      ..lineTo(o(4, 11).dx, o(4, 11).dy)
      ..lineTo(o(10, 9).dx, o(10, 9).dy)
      ..close();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * k
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// 색 점
class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 켜고 끄는 스위치 (앱 색에 맞춘 알약 모양)
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: () => onChanged(!value),
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? p.ink : p.line,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: value ? p.bg : p.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
