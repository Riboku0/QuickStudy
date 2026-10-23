import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import 'reader_chrome.dart';

// عجلة الألوان في لوحة القلم: الزاوية = درجة اللون، والبعد عن المركز = التشبع،
// وشريط تحتها للسطوع. ترجع اللون المختار أو null عند الإلغاء.
Future<Color?> showInkColorWheel(
  BuildContext context, {
  required Color initial,
  required ReaderChrome chrome,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorWheelDialog(initial: initial, chrome: chrome),
  );
}

class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initial, required this.chrome});

  final Color initial;
  final ReaderChrome chrome;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  static const double _size = 230;

  void _pickAt(Offset local) {
    const r = _size / 2;
    final d = local - const Offset(r, r);
    final hue = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
    final sat = (d.distance / r).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withHue(hue).withSaturation(sat));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.chrome;
    final color = _hsv.toColor();
    // مكان المؤشر على العجلة
    const r = _size / 2;
    final angle = _hsv.hue * math.pi / 180;
    final at = Offset(
      r + math.cos(angle) * _hsv.saturation * r,
      r + math.sin(angle) * _hsv.saturation * r,
    );

    return AlertDialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(
        s.pickColor,
        style: TextStyle(
          color: c.ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onPanDown: (d) => _pickAt(d.localPosition),
            onPanUpdate: (d) => _pickAt(d.localPosition),
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(_size, _size),
                    painter: _WheelPainter(value: _hsv.value),
                  ),
                  Positioned(
                    left: at.dx - 13,
                    top: at.dy - 13,
                    child: IgnorePointer(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x55000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // السطوع: من الأسود إلى اللون بكامل سطوعه
          Row(
            children: [
              Icon(Icons.brightness_6_outlined, size: 20, color: c.muted),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 10,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: color,
                    overlayColor: c.accent,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: [Colors.black, _hsv.withValue(1).toColor()],
                          ),
                        ),
                      ),
                      Slider(
                        value: _hsv.value,
                        onChanged: (v) =>
                            setState(() => _hsv = _hsv.withValue(v)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // معاينة اللون
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: c.line),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel, style: TextStyle(color: c.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.strong,
            foregroundColor: c.onStrong,
          ),
          onPressed: () => Navigator.of(context).pop(color),
          child: Text(s.done),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // درجات اللون حول الدائرة (من الزاوية 0 مع عقارب الساعة كما في _pickAt)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            for (var h = 0; h <= 360; h += 60)
              HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    // التشبع: أبيض في المركز يتلاشى نحو الحافة
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    // السطوع الحالي: طبقة سوداء بقدر انخفاضه
    if (value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - value),
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.value != value;
}
