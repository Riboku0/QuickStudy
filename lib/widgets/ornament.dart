import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// زخرفة هندسية (نجمة ثمانية داخل دائرة) مرسومة بالكود، بدون صور
// ---------------------------------------------------------------------------

void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
  // مربعان متداخلان بزاوية 45° = نجمة ثمانية
  for (final start in const [0.0, math.pi / 4]) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = start + math.pi / 4 + i * math.pi / 2;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}

// نقش متكرر يغطي الخلفية
class OrnamentPainter extends CustomPainter {
  const OrnamentPainter({required this.color, this.cell = 84});

  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    var row = 0;
    for (double y = 0; y < size.height + cell; y += cell, row++) {
      final shift = row.isOdd ? cell / 2 : 0.0;
      for (double x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + shift, y);
        _drawStar(canvas, c, cell * 0.34, paint);
        canvas.drawCircle(c, cell * 0.15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(OrnamentPainter old) =>
      old.color != color || old.cell != cell;
}

// وردة كبيرة واحدة (لزوايا البطاقات)
class RosettePainter extends CustomPainter {
  const RosettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;

    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas.drawCircle(center, r * 0.98, paint);
    for (final f in const [0.92, 0.66, 0.4]) {
      _drawStar(canvas, center, r * f, paint);
    }
    canvas.drawCircle(center, r * 0.22, paint);
  }

  @override
  bool shouldRepaint(RosettePainter old) => old.color != color;
}

// خلفية الصفحات الرئيسية
class OrnamentBackground extends StatelessWidget {
  const OrnamentBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: OrnamentPainter(
            color: AppColors.gold.withValues(alpha: 0.07),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

// وردة شفافة تُوضع في زاوية بطاقة (داخل Stack مع clip)
class CornerRosette extends StatelessWidget {
  const CornerRosette({
    super.key,
    this.size = 170,
    this.opacity = 0.13,
    this.color,
  });

  final double size;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: -size * 0.35,
      start: -size * 0.35,
      width: size,
      height: size,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: RosettePainter(
              color: (color ?? AppColors.gold).withValues(alpha: opacity),
            ),
          ),
        ),
      ),
    );
  }
}