import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/themes/app_theme.dart';
import '../../core/themes/study_tone.dart';
import '../../home/view_models/home_view_model.dart' show DayPart;

// مشهد الرئيسية: نافذة وجبال ومكتب ومصباح وكتب ونباتات، وبومة تحتسي القهوة.
// - الخلفية تأخذ ألوانها من الثيم الحالي (StudyTone) وتتبدل بين النهار والليل،
//   والبومة بألوانها الثابتة.
// - طبقتان: خلفية ثابتة تُرسم مرة واحدة (RepaintBoundary)، وطبقة حية خفيفة
//   (البومة، البخار، النجوم، ضوء المصباح) يحركها AnimationController واحد.
// - الحركة تتوقف تلقائيًا حين لا تظهر الصفحة (TickerMode في IndexedStack
//   وتحت الشاشات المفتوحة)، وتتوقف تمامًا إن طلب النظام تقليل الحركة.
// الرسم في مساحة افتراضية 400×240 تُكبَّر لتناسب أي عرض.
class HomeScene extends StatefulWidget {
  const HomeScene({super.key, required this.dayPart, required this.height});

  final DayPart dayPart;
  final double height;

  @override
  State<HomeScene> createState() => _HomeSceneState();
}

class _HomeSceneState extends State<HomeScene>
    with SingleTickerProviderStateMixin {
  // دورة واحدة 10 ثوانٍ: تنفس ×3، رمشتان، رشفة قهوة، بخار ×5
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop
        ..stop()
        ..value = 0.1;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ScenePalette.of(
      main: StudyTone.tone.main,
      part: widget.dayPart,
      dark: AppColors.isDark,
    );
    final background = StudyTone.background;

    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ClipPath(
          clipper: _WaveTopClipper(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: _BackdropPainter(palette)),
              ),
              RepaintBoundary(
                child: CustomPaint(painter: _LifePainter(_loop, palette)),
              ),
              // يذوب أسفل المشهد في لون الصفحة
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.height * 0.16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [background.withValues(alpha: 0), background],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// الحافة العليا موجة ناعمة (مثل المرجع)
class _WaveTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, h * 0.10)
      ..cubicTo(w * 0.32, h * 0.22, w * 0.58, -h * 0.02, w, h * 0.07)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(_WaveTopClipper oldClipper) => false;
}

// ---------------------------------------------------------------------------
// الألوان: مشتقة من لون الثيم، ومختلفة صباحًا وظهرًا وليلًا
// ---------------------------------------------------------------------------

@immutable
class _ScenePalette {
  const _ScenePalette({
    required this.night,
    required this.morning,
    required this.skyTop,
    required this.skyBottom,
    required this.far,
    required this.near,
    required this.city,
    required this.wall,
    required this.frame,
    required this.deskTop,
    required this.deskFront,
    required this.leaf,
    required this.leafDark,
    required this.pot,
    required this.lamp,
    required this.mug,
    required this.books,
    required this.sun,
  });

  final bool night;
  final bool morning;
  final Color skyTop;
  final Color skyBottom;
  final Color far;
  final Color near;
  final Color city;
  final Color wall;
  final Color frame;
  final Color deskTop;
  final Color deskFront;
  final Color leaf;
  final Color leafDark;
  final Color pot;
  final Color lamp;
  final Color mug;
  final List<Color> books;
  final Color sun;

  static const _ink = Color(0xFF2B2546);
  static const _white = Color(0xFFFFFFFF);

  factory _ScenePalette.of({
    required Color main,
    required DayPart part,
    required bool dark,
  }) {
    final night = part == DayPart.evening;
    final morning = part == DayPart.morning;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    // في مظهر التطبيق الداكن يخفت المشهد كله قليلًا
    Color dim(Color c) => dark ? mix(c, const Color(0xFF14121A), 0.28) : c;

    final Color skyTop;
    final Color skyBottom;
    if (night) {
      skyTop = mix(mix(main, _ink, 0.30), _white, 0.10);
      skyBottom = mix(main, _white, 0.55);
    } else if (morning) {
      skyTop = mix(main, _white, 0.62);
      skyBottom = mix(const Color(0xFFFFD2AE), _white, 0.25);
    } else {
      skyTop = mix(main, _white, 0.55);
      skyBottom = mix(mix(main, _white, 0.85), const Color(0xFFFFF4E2), 0.5);
    }

    return _ScenePalette(
      night: night,
      morning: morning,
      skyTop: dim(skyTop),
      skyBottom: dim(skyBottom),
      far: dim(night ? mix(main, _white, 0.38) : mix(main, _white, 0.58)),
      near: dim(night ? mix(main, _ink, 0.18) : mix(main, _white, 0.30)),
      city: dim(night ? mix(main, _ink, 0.42) : mix(main, _white, 0.22)),
      wall: dim(night
          ? mix(mix(main, _ink, 0.35), const Color(0xFFF2CFA0), 0.30)
          : mix(mix(main, _white, 0.75), const Color(0xFFF6E3CF), 0.5)),
      frame: dim(mix(main, _white, night ? 0.55 : 0.82)),
      deskTop: dim(mix(main, const Color(0xFFEDE5DC), night ? 0.55 : 0.78)),
      deskFront: dim(mix(main, const Color(0xFFB9AEB8), night ? 0.45 : 0.6)),
      leaf: dim(mix(const Color(0xFF6F8F7A), main, night ? 0.45 : 0.18)),
      leafDark: dim(mix(const Color(0xFF4C6656), main, night ? 0.5 : 0.22)),
      pot: dim(mix(main, const Color(0xFFD9CBBE), 0.55)),
      lamp: dim(mix(main, _ink, 0.45)),
      mug: dim(mix(main, _ink, 0.50)),
      books: [
        dim(mix(main, _white, 0.55)),
        dim(mix(const Color(0xFFE6D3BC), main, 0.15)),
        dim(mix(main, _ink, 0.20)),
        dim(mix(const Color(0xFFF1E6DA), main, 0.10)),
        dim(mix(main, _white, 0.30)),
      ],
      sun: morning ? const Color(0xFFFFB86B) : const Color(0xFFFFD45E),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _ScenePalette &&
      other.skyTop == skyTop &&
      other.skyBottom == skyBottom &&
      other.near == near &&
      other.night == night &&
      other.morning == morning;

  @override
  int get hashCode => Object.hash(skyTop, skyBottom, near, night, morning);
}

// ---------------------------------------------------------------------------
// المساحة الافتراضية 400×240: تُكبَّر بالعرض، وعلى الشاشات العريضة بالارتفاع
// مع التوسيط (السماء والجبال والمكتب تمتد للأطراف)
// ---------------------------------------------------------------------------

const double _vw = 400;
const double _vh = 240;
const double _deskY = 198; // سطح المكتب

class _Frame {
  _Frame(Size size)
      : scale = math.min(size.width / _vw, size.height / _vh),
        size = size {
    dx = (size.width - _vw * scale) / 2;
    dy = size.height - _vh * scale;
  }

  final double scale;
  final Size size;
  late final double dx;
  late final double dy;

  // حدود الشاشة بالإحداثيات الافتراضية
  double get left => -dx / scale;
  double get right => _vw + dx / scale;
  double get top => -dy / scale;

  void apply(Canvas canvas) {
    canvas
      ..translate(dx, dy)
      ..scale(scale);
  }
}

// ---------------------------------------------------------------------------
// الطبقة الثابتة
// ---------------------------------------------------------------------------

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.p);

  final _ScenePalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final f = _Frame(size);
    canvas.save();
    f.apply(canvas);
    final l = f.left;
    final r = f.right;

    // السماء
    final sky = Rect.fromLTRB(l, f.top, r, _deskY);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, f.top),
          const Offset(0, _deskY),
          [p.skyTop, p.skyBottom],
        ),
    );

    // الشمس أو القمر
    if (p.night) {
      _moon(canvas, const Offset(262, 52), 20);
    } else {
      final c = p.morning ? const Offset(300, 112) : const Offset(292, 58);
      canvas.drawCircle(
        c,
        46,
        Paint()
          ..shader = ui.Gradient.radial(c, 46, [
            p.sun.withValues(alpha: 0.45),
            p.sun.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(c, 17, Paint()..color = p.sun);
    }

    // الجبال: بعيدة ثم قريبة
    final far = Path()..moveTo(l, 150);
    far
      ..lineTo(150, 128)
      ..quadraticBezierTo(205, 96, 240, 112)
      ..quadraticBezierTo(270, 86, 300, 98)
      ..quadraticBezierTo(340, 112, r, 120)
      ..lineTo(r, _deskY)
      ..lineTo(l, _deskY)
      ..close();
    canvas.drawPath(far, Paint()..color = p.far);

    final near = Path()..moveTo(l, 170);
    near
      ..quadraticBezierTo(170, 140, 230, 150)
      ..quadraticBezierTo(300, 124, 340, 146)
      ..quadraticBezierTo(370, 154, r, 150)
      ..lineTo(r, _deskY)
      ..lineTo(l, _deskY)
      ..close();
    canvas.drawPath(near, Paint()..color = p.near);

    // مدينة صغيرة يمين الأسفل، نوافذها مضاءة ليلًا
    final city = Paint()..color = p.city;
    const blocks = [
      (292.0, 172.0, 14.0),
      (307.0, 164.0, 12.0),
      (320.0, 176.0, 16.0),
      (337.0, 168.0, 10.0),
      (348.0, 160.0, 14.0),
      (363.0, 174.0, 18.0),
    ];
    for (final (x, y, w) in blocks) {
      canvas.drawRect(Rect.fromLTRB(x, y, x + w, _deskY), city);
    }
    if (p.night) {
      final lit = Paint()..color = const Color(0xFFFFD98A);
      final rnd = math.Random(7);
      for (final (x, y, w) in blocks) {
        for (var yy = y + 4; yy < _deskY - 4; yy += 6) {
          for (var xx = x + 2; xx < x + w - 2; xx += 4) {
            if (rnd.nextDouble() < 0.35) {
              canvas.drawRect(Rect.fromLTWH(xx, yy, 1.6, 2), lit);
            }
          }
        }
      }
    }

    // إطار النافذة: قائمان رفيعان وعارضة علوية
    final frame = Paint()..color = p.frame.withValues(alpha: 0.75);
    canvas
      ..drawRect(Rect.fromLTRB(150, f.top, 154, _deskY), frame)
      ..drawRect(Rect.fromLTRB(318, f.top, 322, _deskY), frame);

    // جدار يسار تضيئه المصباح، وطرف جدار يمين
    canvas.drawRect(
      Rect.fromLTRB(l, f.top, 112, _deskY),
      Paint()..color = p.wall,
    );
    canvas.drawRect(Rect.fromLTRB(108, f.top, 114, _deskY), frame);
    canvas.drawRect(
      Rect.fromLTRB(386, f.top, r, _deskY),
      Paint()..color = p.wall,
    );

    // النباتات خلف المكتب
    _plant(canvas, const Offset(22, _deskY), 1.0, flip: false);
    _plant(canvas, const Offset(392, _deskY), 0.9, flip: true);

    // المكتب
    canvas.drawRect(
      Rect.fromLTRB(l, _deskY + 6, r, _vh + 2),
      Paint()..color = p.deskFront,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(l, _deskY - 2, r, _deskY + 8, const Radius.circular(3)),
      Paint()..color = p.deskTop,
    );

    // كتب مكدسة يسار ويمين، وكتب واقفة في الطرف الأيمن
    _stack(canvas, const Offset(96, _deskY), [64, 58, 70], 0);
    _stack(canvas, const Offset(296, _deskY), [56, 62], 2);
    final b = p.books;
    for (var i = 0; i < 4; i++) {
      final x = 344.0 + i * 9;
      final h = 34.0 + (i.isEven ? 6 : 0) - i * 2;
      canvas.drawRRect(
        RRect.fromLTRBR(x, _deskY - h, x + 8, _deskY, const Radius.circular(1.5)),
        Paint()..color = b[(i + 1) % b.length],
      );
    }

    // قاعدة المصباح وذراعه (الرأس والضوء في الطبقة الحية)
    final lamp = Paint()
      ..color = p.lamp
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(58, _deskY - 3), width: 40, height: 9),
        Paint()..color = p.lamp,
      )
      ..drawLine(const Offset(58, _deskY - 5), const Offset(44, 128), lamp)
      ..drawLine(const Offset(44, 128), const Offset(84, 92), lamp)
      ..drawCircle(const Offset(44, 128), 4, Paint()..color = p.lamp);

    canvas.restore();
  }

  // قمر هلال بهالة
  void _moon(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 2.4,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 2.4, [
          const Color(0x55FFFFFF),
          const Color(0x00FFFFFF),
        ]),
    );
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()
        ..addOval(
          Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.35), radius: r * 0.9),
        ),
    );
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFF7E6));
  }

  void _stack(Canvas canvas, Offset bottom, List<double> widths, int shift) {
    var y = bottom.dy;
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i];
      const h = 10.0;
      final x = bottom.dx - w / 2 + (i.isOdd ? 3 : -2);
      final rect = RRect.fromLTRBR(x, y - h, x + w, y, const Radius.circular(2));
      canvas.drawRRect(rect, Paint()..color = p.books[(i + shift) % p.books.length]);
      // صفحات الكتاب من الجانب
      canvas.drawRect(
        Rect.fromLTRB(x + w - 7, y - h + 2, x + w - 1, y - 2),
        Paint()..color = const Color(0xFFF8F3EA),
      );
      y -= h;
    }
  }

  void _plant(Canvas canvas, Offset base, double s, {required bool flip}) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(flip ? -s : s, s);
    // أوراق طويلة مائلة
    const leaves = [
      (-0.9, 46.0),
      (-0.45, 58.0),
      (0.0, 64.0),
      (0.4, 56.0),
      (0.85, 44.0),
      (-0.2, 40.0),
      (0.65, 34.0),
    ];
    for (final (i, (angle, len)) in leaves.indexed) {
      canvas.save();
      canvas.translate(4, -22);
      canvas.rotate(angle);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(9, -len * 0.5, 0, -len)
        ..quadraticBezierTo(-9, -len * 0.5, 0, 0)
        ..close();
      canvas.drawPath(leaf, Paint()..color = i.isEven ? p.leaf : p.leafDark);
      canvas.restore();
    }
    // الأصيص
    final pot = Path()
      ..moveTo(-12, -24)
      ..lineTo(20, -24)
      ..lineTo(16, 0)
      ..lineTo(-8, 0)
      ..close();
    canvas.drawPath(pot, Paint()..color = p.pot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.p != p;
}

// ---------------------------------------------------------------------------
// الطبقة الحية: النجوم أو السحب، ضوء المصباح، البومة، الكوب والبخار
// ---------------------------------------------------------------------------

class _LifePainter extends CustomPainter {
  _LifePainter(this.anim, this.p) : super(repaint: anim);

  final Animation<double> anim;
  final _ScenePalette p;

  static const double _tau = math.pi * 2;

  // نجوم ثابتة المواضع داخل النافذة: (x, y, حجم، طور)
  static const _stars = [
    (176.0, 30.0, 1.6, 0.1),
    (214.0, 58.0, 1.2, 0.5),
    (300.0, 26.0, 1.8, 0.3),
    (338.0, 66.0, 1.3, 0.8),
    (372.0, 38.0, 1.5, 0.6),
    (232.0, 22.0, 1.1, 0.9),
    (196.0, 84.0, 1.0, 0.2),
    (356.0, 92.0, 1.2, 0.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = anim.value;
    final f = _Frame(size);
    canvas.save();
    f.apply(canvas);

    if (p.night) {
      _twinkle(canvas, v);
    } else {
      _clouds(canvas, v);
    }
    _lampHead(canvas, v);
    _owl(canvas, v);

    canvas.restore();
  }

  void _twinkle(Canvas canvas, double v) {
    for (final (i, (x, y, r, phase)) in _stars.indexed) {
      final k = (i % 3) + 1; // عدد ومضات النجمة في الدورة
      final glow = 0.5 + 0.5 * math.sin(_tau * (k * v + phase));
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 + 0.6 * glow);
      final s = r * (0.8 + 0.5 * glow);
      // نجمة رباعية صغيرة
      final star = Path()
        ..moveTo(x, y - s * 2)
        ..quadraticBezierTo(x, y, x + s * 2, y)
        ..quadraticBezierTo(x, y, x, y + s * 2)
        ..quadraticBezierTo(x, y, x - s * 2, y)
        ..quadraticBezierTo(x, y, x, y - s * 2)
        ..close();
      canvas.drawPath(star, paint);
    }
  }

  void _clouds(Canvas canvas, double v) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    void cloud(double x, double y, double s) {
      canvas
        ..drawOval(Rect.fromCenter(center: Offset(x, y), width: 34 * s, height: 12 * s), paint)
        ..drawCircle(Offset(x - 6 * s, y - 5 * s), 7 * s, paint)
        ..drawCircle(Offset(x + 5 * s, y - 6 * s), 9 * s, paint);
    }

    final drift = math.sin(_tau * v) * 4;
    cloud(200 + drift, 46, 1.0);
    cloud(352 - drift, 72, 0.8);
  }

  void _lampHead(Canvas canvas, double v) {
    const tip = Offset(84, 92);
    // ضوء دافئ: أوضح ليلًا، وخفيف نهارًا
    final pulse = 0.94 + 0.06 * math.sin(_tau * 2 * v);
    final strength = (p.night ? 0.55 : 0.18) * pulse;
    final cone = Path()
      ..moveTo(96, 104)
      ..lineTo(150, _deskY)
      ..lineTo(48, _deskY)
      ..lineTo(84, 110)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(90, 104),
          const Offset(100, _deskY),
          [
            const Color(0xFFFFE2A8).withValues(alpha: strength),
            const Color(0xFFFFE2A8).withValues(alpha: 0),
          ],
        ),
    );
    canvas.drawCircle(
      const Offset(92, 108),
      44,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(92, 108), 44, [
          const Color(0xFFFFD796).withValues(alpha: strength * 0.9),
          const Color(0xFFFFD796).withValues(alpha: 0),
        ]),
    );

    // رأس المصباح: مخروط مائل
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(0.55);
    final shade = Path()
      ..moveTo(-8, -6)
      ..lineTo(8, -6)
      ..lineTo(20, 22)
      ..quadraticBezierTo(0, 28, -20, 22)
      ..close();
    canvas.drawPath(shade, Paint()..color = p.lamp);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 23), width: 36, height: 7),
      Paint()..color = const Color(0xFFFFE8B8).withValues(alpha: p.night ? 0.95 : 0.6),
    );
    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // البومة: ألوانها ثابتة لا تتبع الثيم
  // -------------------------------------------------------------------------

  static const _body = Color(0xFFE6E0EC);
  static const _bodyShade = Color(0xFFCEC5DA);
  static const _face = Color(0xFFF8F5FA);
  static const _belly = Color(0xFFF4F0F7);
  static const _wing = Color(0xFFD3CADF);
  static const _feather = Color(0xFFD8CFE2);
  static const _eye = Color(0xFF2D2838);
  static const _beak = Color(0xFFE9A15A);
  static const _cheek = Color(0xFFF2A9B4);
  static const _feet = Color(0xFFE3A867);

  // منحنى صعود وهبوط ناعم بين a وb (0 خارج المدى)
  static double _bump(double v, double a, double b) {
    if (v <= a || v >= b) return 0;
    return math.sin(math.pi * (v - a) / (b - a));
  }

  // 0→1 بين a وb مع تسهيل
  static double _ease(double v, double a, double b) {
    final t = ((v - a) / (b - a)).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(t);
  }

  void _owl(Canvas canvas, double v) {
    // رشفة القهوة: صعود (0.74–0.80)، ثبات، نزول (0.88–0.94)
    final sip = _ease(v, 0.74, 0.80) - _ease(v, 0.88, 0.94);
    // النشاط: صباحًا نشيطة جدًا، ظهرًا يقظة، ليلًا هادئة نعسانة
    final energy = p.night ? 0.0 : (p.morning ? 1.0 : 0.6);
    // التنفس ليلًا ثلاث دورات بطيئة، ونهارًا قفزات خفيفة أسرع
    final breath =
        p.night ? math.sin(_tau * 3 * v) : math.sin(_tau * 4 * v);
    final hop = energy * (0.5 - 0.5 * math.cos(_tau * 4 * v));
    final sway = energy * 0.045 * math.sin(_tau * 2 * v);
    // تلويح بالجناح الأيسر نهارًا (0.10–0.38) مع اهتزاز سريع
    final wave =
        energy == 0 ? 0.0 : _ease(v, 0.10, 0.15) - _ease(v, 0.33, 0.38);
    final waggle = 0.35 * wave * math.sin(_tau * 14 * v);
    // الرمش: رمشتان سريعتان، والعينان مغمضتان أثناء الرشفة
    final blink = math.max(_bump(v, 0.30, 0.33), _bump(v, 0.56, 0.59));
    final lidBase = p.night ? 0.42 : 0.0; // نعسانة ليلًا
    final lid = math.max(lidBase + (1 - lidBase) * blink, sip);

    canvas.save();
    canvas.translate(200, _deskY + 1);
    // ظل خفيف على المكتب
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 96, height: 9),
      Paint()..color = const Color(0x22000000),
    );
    canvas
      ..translate(0, -3.5 * hop)
      ..rotate(sway);
    if (p.morning) _sparkles(canvas, v);
    canvas.save();
    canvas.scale(1 - 0.008 * breath, 1 + 0.018 * breath);

    // الجسم
    final body = Path()
      ..moveTo(0, -98)
      ..cubicTo(30, -98, 46, -80, 46, -52)
      ..cubicTo(48, -22, 36, 0, 0, 0)
      ..cubicTo(-36, 0, -48, -22, -46, -52)
      ..cubicTo(-46, -80, -30, -98, 0, -98)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -98),
          Offset.zero,
          const [_body, _bodyShade],
        ),
    );

    // خصلتا الأذنين
    final tuftPaint = Paint()..color = _bodyShade;
    for (final side in const [-1.0, 1.0]) {
      final tuft = Path()
        ..moveTo(side * 36, -82)
        ..quadraticBezierTo(side * 46, -100, side * 42, -110)
        ..quadraticBezierTo(side * 30, -98, side * 18, -94)
        ..close();
      canvas.drawPath(tuft, tuftPaint);
    }

    // البطن بريش صغير
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -24), width: 58, height: 44),
      Paint()..color = _belly,
    );
    final feather = Paint()
      ..color = _feather
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final (x, y) in const [
      (-12.0, -32.0),
      (0.0, -34.0),
      (12.0, -32.0),
      (-6.0, -22.0),
      (6.0, -22.0),
      (0.0, -12.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 3.5, y)
          ..quadraticBezierTo(x, y + 3.5, x + 3.5, y),
        feather,
      );
    }

    // قرص الوجه
    final face = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: const Offset(-17, -64), radius: 20)),
      Path()..addOval(Rect.fromCircle(center: const Offset(17, -64), radius: 20)),
    );
    canvas.drawPath(face, Paint()..color = _face);

    // العينان
    for (final x in const [-17.0, 17.0]) {
      _eyeAt(canvas, Offset(x, -64), lid, wide: energy > 0);
    }

    // الخدان والمنقار
    final cheek = Paint()..color = _cheek.withValues(alpha: 0.55);
    canvas
      ..drawOval(Rect.fromCenter(center: const Offset(-28, -51), width: 11, height: 6), cheek)
      ..drawOval(Rect.fromCenter(center: const Offset(28, -51), width: 11, height: 6), cheek);
    final beak = Path()
      ..moveTo(-4.5, -56)
      ..quadraticBezierTo(0, -58, 4.5, -56)
      ..quadraticBezierTo(1, -48, 0, -47)
      ..quadraticBezierTo(-1, -48, -4.5, -56)
      ..close();
    canvas.drawPath(beak, Paint()..color = _beak);

    // الجناح الأيسر: مرتاح على الجانب، ويرتفع للتلويح نهارًا (المحور عند الكتف)
    canvas.save();
    canvas.translate(-38, -50);
    canvas.rotate(0.28 + 2.4 * wave + waggle);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 22), width: 20, height: 46),
      Paint()..color = _wing,
    );
    canvas.restore();

    // القدمان
    final feet = Paint()..color = _feet;
    canvas
      ..drawOval(Rect.fromCenter(center: const Offset(-12, -1), width: 13, height: 5), feet)
      ..drawOval(Rect.fromCenter(center: const Offset(12, -1), width: 13, height: 5), feet);

    canvas.restore(); // نهاية التنفس

    // الكوب والجناح الذي يمسكه: من المكتب إلى المنقار
    final mug = Offset.lerp(const Offset(40, -15), const Offset(16, -44), sip)!;
    final tilt = -0.65 * sip;

    canvas.save();
    canvas.translate(
      Offset.lerp(const Offset(38, -26), const Offset(30, -42), sip)!.dx,
      Offset.lerp(const Offset(38, -26), const Offset(30, -42), sip)!.dy,
    );
    canvas.rotate(-0.35 - 0.6 * sip);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 20, height: 40),
      Paint()..color = _wing,
    );
    canvas.restore();

    _mug(canvas, mug, tilt, v, sip);
    canvas.restore();
  }

  // بريق صغير يظهر ويختفي حول الرأس صباحًا
  void _sparkles(Canvas canvas, double v) {
    const spots = [
      (-56.0, -100.0, 0.05),
      (58.0, -92.0, 0.38),
      (-4.0, -126.0, 0.70),
    ];
    for (final (x, y, start) in spots) {
      final k = _bump(v, start, start + 0.16);
      if (k == 0) continue;
      final s = 2.6 * k;
      canvas.drawPath(
        Path()
          ..moveTo(x, y - s * 2)
          ..quadraticBezierTo(x, y, x + s * 2, y)
          ..quadraticBezierTo(x, y, x, y + s * 2)
          ..quadraticBezierTo(x, y, x - s * 2, y)
          ..quadraticBezierTo(x, y, x, y - s * 2)
          ..close(),
        Paint()..color = const Color(0xFFFFC83D).withValues(alpha: k),
      );
    }
  }

  // wide: عينان أوسع ولامعتان (نهارًا)
  void _eyeAt(Canvas canvas, Offset c, double lid, {bool wide = false}) {
    final w = wide ? 13.0 : 11.0;
    final h = wide ? 14.0 : 12.0;
    final top = c.dy - h / 2;
    final lidY = top + h * lid.clamp(0.0, 1.0);
    if (lid < 0.98) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(c.dx - w, lidY, c.dx + w, c.dy + h));
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: h),
        Paint()..color = _eye,
      );
      canvas.drawCircle(
        c + const Offset(-1.8, -2.2),
        wide ? 2.8 : 2.2,
        Paint()..color = Colors.white,
      );
      if (wide) {
        canvas.drawCircle(
          c + const Offset(2.4, 2.6),
          1.2,
          Paint()..color = Colors.white,
        );
      }
      canvas.restore();
    }
    if (lid > 0.04) {
      // حافة الجفن: تنحني لتصير عينًا مغمضة هادئة
      final y = math.min(lidY, c.dy + h / 2 - 1);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - w / 2 - 0.5, y)
          ..quadraticBezierTo(c.dx, y + 3.2 * lid, c.dx + w / 2 + 0.5, y),
        Paint()
          ..color = _eye
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _mug(Canvas canvas, Offset c, double tilt, double v, double sip) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final body = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 26),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(7),
      bottomRight: const Radius.circular(7),
    );
    // المقبض جهة البومة
    canvas.drawCircle(
      const Offset(-12, 0),
      6.5,
      Paint()
        ..color = p.mug
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawRRect(body, Paint()..color = p.mug);
    canvas.drawRect(
      const Rect.fromLTRB(-12, -13, 12, -10),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    // هلال صغير على الكوب
    final mark = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: const Offset(1, 2), radius: 6)),
      Path()..addOval(Rect.fromCircle(center: const Offset(4, -1), radius: 5.2)),
    );
    canvas.drawPath(mark, Paint()..color = const Color(0xFFFFE3A3));
    canvas.restore();

    // البخار: ثلاثة خيوط تصعد وتتلاشى، وتخفت أثناء الرشفة
    final fade = 1 - sip;
    if (fade <= 0.02) return;
    final top = c + Offset(0, -15 + 4 * sip);
    // أبيض ليلًا، ورمادي بنفسجي نهارًا حتى يظهر على السماء الفاتحة
    final steam = p.night ? Colors.white : const Color(0xFFAFA4C2);
    for (var i = 0; i < 3; i++) {
      final phase = _tau * (5 * v) + i * 2.1;
      final path = Path();
      for (var k = 0; k <= 12; k++) {
        final y = top.dy - k * 2.6;
        final x = top.dx - 6 + i * 6 + 2.4 * math.sin(k * 0.65 - phase);
        k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            top,
            top - const Offset(0, 32),
            [
              steam.withValues(alpha: 0.75 * fade),
              steam.withValues(alpha: 0),
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_LifePainter old) => old.p != p || old.anim != anim;
}
