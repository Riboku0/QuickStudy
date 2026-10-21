import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/themes/app_theme.dart';
import '../../core/themes/study_tone.dart';
import '../../home/view_models/home_view_model.dart' show DayPart;

// مشهد الرئيسية: رسمة الغرفة (من المستخدم) في الخلفية، والبومة المرسومة
// بالكود جالسة على المكتب.
// - صورتان للنهار والليل (assets/scene) تُمزجان بالتدريج حسب الساعة، وشيدر
//   (shaders/scene_tint.frag) يحوّل درجاتهما البنفسجية والكحلية إلى لون
//   الثيم، فيبقى ضوء المصباح والخشب والنباتات دافئة.
// - فوق الصورة حركة هادئة: نجوم الرسمة تومض بخفة، سحب ناعمة قليلة، ضوء
//   المصباح يتنفس، دفء الفجر والغروب على النافذة، وطائر أو شهاب مرة كل 3
//   دقائق فقط.
// - البومة هي الشخصية المتحركة الرئيسية.
// - AnimationController واحد (3 دقائق) يتوقف حين لا تظهر الصفحة (TickerMode)
//   ويثبت تمامًا إن طلب النظام تقليل الحركة. الصورة تُرسم مرة في الدقيقة فقط.
class HomeScene extends StatefulWidget {
  const HomeScene({
    super.key,
    required this.dayPart,
    required this.height,
    this.debugHour,
  });

  final DayPart dayPart;
  final double height;
  // للمعاينة في الاختبارات فقط: ساعة ثابتة بدل الساعة الحقيقية
  @visibleForTesting
  final double? debugHour;

  // نسبة العرض إلى الارتفاع المناسبة للمشهد (الصورة تُقص من الجانبين)
  static const double aspect = 2.2;

  @override
  State<HomeScene> createState() => _HomeSceneState();
}

class _HomeSceneState extends State<HomeScene>
    with SingleTickerProviderStateMixin {
  // دورة المشهد 3 دقائق، وفيها 18 دورة للبومة (10 ثوانٍ لكل منها)
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 3),
  );

  // الصورتان والشيدر يُحمَّلان مرة واحدة طوال عمر التطبيق
  static Future<_SceneArt>? _artFuture;
  _SceneArt? _art;

  // الألوان تتبع الساعة: تُعاد الصورة مرة في الدقيقة فقط
  Timer? _clock;
  int _minute = _minuteNow();

  static int _minuteNow() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  void initState() {
    super.initState();
    _artFuture ??= _SceneArt.load();
    _artFuture!.then((art) {
      if (mounted) setState(() => _art = art);
    });
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      final m = _minuteNow();
      if (m != _minute && mounted) setState(() => _minute = m);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // لقطة ثابتة هادئة: البومة مستيقظة بلا رشفة ولا تلويح
      _loop
        ..stop()
        ..value = 0.45 / 18;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _ScenePalette.at(
      main: StudyTone.tone.main,
      hour: widget.debugHour ?? _minute / 60,
      part: widget.dayPart,
      dark: AppColors.isDark,
    );
    final background = StudyTone.background;
    final art = _art;

    Widget still(CustomPainter painter) =>
        RepaintBoundary(child: CustomPaint(painter: painter));

    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ClipPath(
          clipper: _WaveTopClipper(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // تظهر الرسمة بهدوء بعد تحميلها (لحظة عند أول فتح)
              AnimatedOpacity(
                opacity: art == null ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                child: art == null
                    ? const SizedBox.expand()
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          still(_ArtPainter(art, p)),
                          still(_FxPainter(_loop, p)),
                        ],
                      ),
              ),
              still(_LifePainter(_loop, p)),
              // يذوب أسفل المشهد في لون الصفحة
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.height * 0.10,
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

const double _turn = math.pi * 2;

double _smooth(double t) => t * t * (3 - 2 * t);

// قيمة تتدرج بين محطات بالساعة (مزج ناعم بين كل محطتين)
double _byHour(double hour, List<(double, double)> stops) {
  for (var i = 0; i < stops.length - 1; i++) {
    final (h0, a) = stops[i];
    final (h1, b) = stops[i + 1];
    if (hour >= h0 && hour <= h1) {
      return a + (b - a) * _smooth((hour - h0) / (h1 - h0));
    }
  }
  return stops.last.$2;
}

// ---------------------------------------------------------------------------
// الصورتان والشيدر
// ---------------------------------------------------------------------------

class _SceneArt {
  _SceneArt(this.program, this.day, this.night, this.mask);

  final ui.FragmentProgram? program; // null إن تعذر الشيدر: الصور بلا تلوين
  final ui.Image day;
  final ui.Image night;
  // خريطة المناطق: R داخل النافذة، G جدار الغرفة وستائرها (ما يُلوَّن بالثيم)
  final ui.Image mask;

  static Future<_SceneArt> load() async {
    Future<ui.Image> image(String path) async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    ui.FragmentProgram? program;
    try {
      program = await ui.FragmentProgram.fromAsset('shaders/scene_tint.frag');
    } catch (_) {
      program = null;
    }
    return _SceneArt(
      program,
      await image('assets/scene/scene_day.jpg'),
      await image('assets/scene/scene_night.jpg'),
      await image('assets/scene/scene_mask.png'),
    );
  }
}

// ---------------------------------------------------------------------------
// قيم المشهد في هذه الدقيقة: الليل، دفء الفجر والغروب، تحويل لون الثيم
// ---------------------------------------------------------------------------

@immutable
class _ScenePalette {
  const _ScenePalette({
    required this.key,
    required this.night,
    required this.morning,
    required this.nightness,
    required this.warm,
    required this.hue,
    required this.satScale,
    required this.strength,
    required this.dim,
    required this.mug,
  });

  final int key; // يتغير مع الدقيقة والثيم والمظهر فقط
  // سلوك البومة (من DayPart كما كان)
  final bool night;
  final bool morning;
  final double nightness; // 0 نهار … 1 ليل (مزج الصورتين)
  final double warm; // دفء الفجر والغروب على النافذة 0..1
  final double hue; // لون الثيم الذي تُلوَّن به الدرجات البنفسجية (0..1)
  final double satScale;
  final double strength; // 0 للبنفسجي (الرسمة الأصلية كما هي)، 1 لغيره
  final double dim; // تعتيم المظهر الداكن
  final Color mug;

  static const _ink = Color(0xFF2B2546);
  // لون الرسمة الأصلي (بنفسجي) بدرجة HSV
  static const double _baseHue = 0.70;

  factory _ScenePalette.at({
    required Color main,
    required double hour,
    required DayPart part,
    required bool dark,
  }) {
    final hsv = HSVColor.fromColor(main);
    // التبديل بين صورتي الليل والنهار قصير (أقل من ساعة) حتى لا تظهر
    // الشمس والقمر معًا طويلًا، والغروب صورة النهار بدفء وردي برتقالي
    final nightness = _byHour(hour, const [
      (0, 1),
      (5.3, 1),
      (6.1, 0),
      (18.5, 0),
      (19.3, 1),
      (24, 1),
    ]);
    final warm = _byHour(hour, const [
      (0, 0),
      (5.2, 0),
      (5.9, 0.6),
      (7.6, 0),
      (16.6, 0),
      (17.8, 0.85),
      (18.7, 0.7),
      (19.5, 0),
      (24, 0),
    ]);
    final mug = Color.lerp(main, _ink, 0.50)!;
    return _ScenePalette(
      key: Object.hash(main, (hour * 60).round(), dark, part),
      night: part == DayPart.evening,
      morning: part == DayPart.morning,
      nightness: nightness,
      warm: warm,
      hue: hsv.hue / 360,
      // الرمادي (graphite) شبه بلا لون، وبقية الثيمات أهدأ قليلًا من لونها
      satScale: hsv.saturation < 0.3 ? 0.15 : 0.8,
      strength: (hsv.hue / 360 - _baseHue).abs() < 0.03 &&
              hsv.saturation >= 0.3
          ? 0
          : 1,
      dim: dark ? 0.22 : 0,
      mug: dark ? Color.lerp(mug, const Color(0xFF14121A), 0.28)! : mug,
    );
  }

  @override
  bool operator ==(Object other) => other is _ScenePalette && other.key == key;

  @override
  int get hashCode => key;
}

// ---------------------------------------------------------------------------
// موضع الصورة: تملأ المشهد وتُقص من الجانبين، والرسم فوقها بإحداثيات الصورة
// ---------------------------------------------------------------------------

const double _artW = 1586;
const double _artH = 493;
const double _deskY = 198; // سطح المكتب في إحداثيات رسم البومة الأصلية

class _ArtFrame {
  _ArtFrame(Size size) {
    scale = math.max(size.width / _artW, size.height / _artH);
    // مركز القص قليلًا يسار المنتصف حتى يبقى المصباح كاملًا
    dx = (size.width / 2 - 0.48 * _artW * scale)
        .clamp(size.width - _artW * scale, 0.0);
    dy = (size.height - _artH * scale) / 2;
  }

  late final double scale;
  late final double dx;
  late final double dy;

  Rect get rect => Rect.fromLTWH(dx, dy, _artW * scale, _artH * scale);

  void apply(Canvas canvas) {
    canvas
      ..translate(dx, dy)
      ..scale(scale);
  }
}

// ---------------------------------------------------------------------------
// 1) الرسمة: مزج النهار والليل وتلوينها بالثيم (مرة في الدقيقة)
// ---------------------------------------------------------------------------

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.p);

  final _SceneArt art;
  final _ScenePalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _ArtFrame(size).rect;
    final program = art.program;
    if (program != null) {
      final shader = program.fragmentShader()
        ..setFloat(0, rect.left)
        ..setFloat(1, rect.top)
        ..setFloat(2, rect.width)
        ..setFloat(3, rect.height)
        ..setFloat(4, p.nightness)
        ..setFloat(5, p.hue)
        ..setFloat(6, p.satScale)
        ..setFloat(7, p.strength)
        ..setFloat(8, p.dim)
        // صورة النهار أعلى من الليل ببضع بكسلات
        ..setFloat(9, 9 / _artH)
        ..setImageSampler(0, art.day)
        ..setImageSampler(1, art.night)
        ..setImageSampler(2, art.mask);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      return;
    }
    // بلا شيدر: الصورتان كما هما بالتدرج
    final src = Rect.fromLTWH(0, 0, _artW, _artH);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(art.day, src, rect, paint);
    if (p.nightness > 0) {
      canvas.drawImageRect(
        art.night,
        src,
        rect,
        paint..color = Colors.white.withValues(alpha: p.nightness),
      );
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.p != p || old.art != art;
}

// ---------------------------------------------------------------------------
// 2) الحركة الهادئة فوق الرسمة (بإحداثيات الصورة 1586×493)
// ---------------------------------------------------------------------------

class _FxPainter extends CustomPainter {
  _FxPainter(this.anim, this.p) : super(repaint: anim);

  final Animation<double> anim;
  final _ScenePalette p;

  // زجاج النافذة في الرسمة
  static const _window = Rect.fromLTRB(567, 0, 1333, 368);
  // القمر في رسمة الليل
  static const _moon = Offset(1108, 112);

  // نجوم الرسمة نفسها (تومض في أماكنها): (x, y, حجم، طور)
  static const _stars = [
    (655.0, 33.0, 4.0, 0.1),
    (717.0, 80.0, 4.5, 0.5),
    (826.0, 122.0, 4.0, 0.3),
    (860.0, 72.0, 3.0, 0.8),
    (1010.0, 122.0, 4.0, 0.6),
    (1233.0, 103.0, 4.5, 0.9),
    (1283.0, 62.0, 3.0, 0.2),
  ];

  // نوافذ القرية المضاءة في رسمة الليل (مقيسة من الصورة)
  static const _villageWindows = [
    Rect.fromLTRB(1214, 258, 1219, 267),
    Rect.fromLTRB(710, 309, 717, 312),
    Rect.fromLTRB(730, 310, 733, 313),
    Rect.fromLTRB(1091, 314, 1094, 316),
    Rect.fromLTRB(618, 316, 628, 332),
    Rect.fromLTRB(643, 316, 653, 332),
    Rect.fromLTRB(1156, 318, 1161, 329),
    Rect.fromLTRB(1172, 318, 1177, 329),
    Rect.fromLTRB(1054, 320, 1055, 324),
    Rect.fromLTRB(1064, 321, 1067, 324),
    Rect.fromLTRB(972, 338, 978, 344),
    Rect.fromLTRB(989, 338, 994, 344),
    Rect.fromLTRB(722, 347, 727, 358),
    Rect.fromLTRB(736, 347, 741, 357),
    Rect.fromLTRB(859, 351, 861, 354),
    Rect.fromLTRB(870, 351, 872, 355),
  ];

  // يراعات بين الأشجار أسفل المنظر: (x, y, طور)
  static const _fireflies = [
    (612.0, 300.0, 0.0),
    (705.0, 334.0, 0.31),
    (802.0, 290.0, 0.62),
    (905.0, 326.0, 0.17),
    (1012.0, 300.0, 0.83),
    (1118.0, 338.0, 0.45),
    (1262.0, 296.0, 0.71),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = anim.value;
    final f = _ArtFrame(size);
    canvas.save();
    f.apply(canvas);

    _lampGlow(canvas, v);

    canvas.save();
    canvas.clipRect(_window);
    final n = p.nightness;
    if (p.warm > 0.01) _warmth(canvas);
    if (n > 0.05) {
      _moonGlow(canvas, v, n);
      _nightClouds(canvas, v, n);
      _twinkle(canvas, v, n);
      _villageLights(canvas, v, n);
      _fireflyDots(canvas, v, n);
      _rareNight(canvas, v, n);
    }
    if (n < 0.95) {
      _clouds(canvas, v, 1 - n);
      _birds(canvas, v, 1 - n);
    }
    canvas.restore();

    if (n > 0.3) _moth(canvas, v, n);

    canvas.restore();
  }

  // ضوء المصباح يتنفس بهدوء (دورة 10 ثوانٍ)، أوضح ليلًا
  void _lampGlow(Canvas canvas, double v) {
    final pulse = 0.5 + 0.5 * math.sin(_turn * 18 * v);
    final strength = (0.05 + 0.09 * p.nightness) * (0.7 + 0.3 * pulse);
    const bulb = Offset(378, 212);
    canvas.drawCircle(
      bulb,
      150,
      Paint()
        ..shader = ui.Gradient.radial(bulb, 150, [
          const Color(0xFFFFD796).withValues(alpha: strength),
          const Color(0xFFFFD796).withValues(alpha: 0),
        ]),
    );
    const pool = Offset(372, 425);
    canvas.save();
    canvas.translate(pool.dx, pool.dy);
    canvas.scale(1, 0.2);
    canvas.drawCircle(
      Offset.zero,
      200,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 200, [
          const Color(0xFFFFE2A8).withValues(alpha: strength * 1.2),
          const Color(0xFFFFE2A8).withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  // دفء الفجر والغروب على السماء خلف النافذة
  void _warmth(Canvas canvas) {
    canvas.drawRect(
      _window,
      Paint()
        ..shader = ui.Gradient.linear(
          _window.topCenter,
          _window.bottomCenter,
          [
            const Color(0xFFFF8FA3).withValues(alpha: 0.22 * p.warm),
            const Color(0xFFFFB070).withValues(alpha: 0.5 * p.warm),
          ],
        ),
    );
  }

  // وهج القمر يتنفس ببطء (دورة 10 ثوانٍ)، وسحابة رقيقة تعبره كل 30 ثانية
  void _moonGlow(Canvas canvas, double v, double n) {
    final pulse = 0.5 + 0.5 * math.sin(_turn * 18 * v);
    canvas.drawCircle(
      _moon,
      125,
      Paint()
        ..shader = ui.Gradient.radial(_moon, 125, [
          const Color(0xFFFFF4D6).withValues(alpha: n * (0.08 + 0.09 * pulse)),
          const Color(0xFFFFF4D6).withValues(alpha: 0),
        ]),
    );
    final u = (v * 6) % 1;
    if (u > 0.45) return;
    final t = u / 0.45;
    final x = 960 + t * 300;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2 * n * math.sin(math.pi * t))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas
      ..drawOval(Rect.fromCenter(center: Offset(x, 120), width: 150, height: 14), paint)
      ..drawOval(Rect.fromCenter(center: Offset(x + 34, 112), width: 80, height: 10), paint);
  }

  // نجوم الرسمة تومض بخفة، كل نجمة بإيقاع 7–20 ثانية
  void _twinkle(Canvas canvas, double v, double n) {
    for (final (i, (x, y, r, phase)) in _stars.indexed) {
      final k = 9 * ((i % 3) + 1);
      final glow = 0.5 + 0.5 * math.sin(_turn * (k * v + phase));
      final s = r * (0.7 + 0.7 * glow);
      _sparkle(
        canvas,
        Offset(x, y),
        s,
        const Color(0xFFFFF4D6).withValues(alpha: n * 0.75 * glow),
      );
    }
  }

  static void _sparkle(Canvas canvas, Offset c, double s, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - s * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s * 2)
        ..close(),
      Paint()..color = color,
    );
  }

  // رقم شبه عشوائي ثابت لكل (نافذة، فترة)
  static double _hash(int a, int b) {
    final x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  // نوافذ القرية: بعضها يُطفأ ويُضاء كل 9 ثوانٍ كأن أهلها يذهبون للنوم
  void _villageLights(Canvas canvas, double v, double n) {
    final step = (v * 20).floor();
    // لون النافذة المطفأة: داكن من لون الثيم (أو كحلي الرسمة الأصلي)
    final off = p.strength > 0
        ? HSVColor.fromAHSV(1, p.hue * 360, 0.35, 0.2).toColor()
        : const Color(0xFF2B2840);
    for (final (i, w) in _villageWindows.indexed) {
      final r = _hash(i, step);
      if (r < 0.28) {
        canvas.drawRect(w.inflate(0.8), Paint()..color = off.withValues(alpha: 0.92 * n));
      } else if (r > 0.82) {
        // نافذة أُضيئت للتو: وهج دافئ صغير حولها
        canvas.drawCircle(
          w.center,
          w.longestSide * 1.6,
          Paint()
            ..shader = ui.Gradient.radial(w.center, w.longestSide * 1.6, [
              const Color(0xFFFFD98A).withValues(alpha: 0.45 * n),
              const Color(0xFFFFD98A).withValues(alpha: 0),
            ]),
        );
      }
    }
  }

  // يراعات تطفو ببطء بين الأشجار وتومض بهدوء
  void _fireflyDots(Canvas canvas, double v, double n) {
    for (final (i, (x, y, phase)) in _fireflies.indexed) {
      final dx = 14 * math.sin(_turn * (6 * v + phase));
      final dy = 7 * math.sin(_turn * (9 * v + phase * 2));
      final blink = 0.5 + 0.5 * math.sin(_turn * (36 + 9 * (i % 3)) * v + phase * 6);
      final a = n * blink * blink;
      if (a < 0.03) continue;
      final c = Offset(x + dx, y + dy);
      canvas.drawCircle(
        c,
        7,
        Paint()
          ..shader = ui.Gradient.radial(c, 7, [
            const Color(0xFFFFE9A0).withValues(alpha: 0.55 * a),
            const Color(0xFFFFE9A0).withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(c, 1.6, Paint()..color = const Color(0xFFFFF6CF).withValues(alpha: a));
    }
  }

  // لحظة نادرة كل 6 ثوانٍ: شهاب، ثم خفاش يعبر أمام القمر، بالتناوب
  void _rareNight(Canvas canvas, double v, double n) {
    if (n < 0.6) return;
    final idx = (v * 30).floor();
    final u = (v * 30) % 1;
    if (idx.isEven) {
      if (u < 0.1 || u > 0.55) return;
      final t = (u - 0.1) / 0.45;
      const paths = [
        (Offset(890, 24), Offset(640, 96)),
        (Offset(1300, 30), Offset(1180, 72)),
        (Offset(820, 60), Offset(610, 130)),
      ];
      final (from, to) = paths[(idx ~/ 2) % paths.length];
      final head = Offset.lerp(from, to, Curves.easeOut.transform(t))!;
      final dir = (to - from) / (to - from).distance;
      final tail = head - dir * 70;
      final alpha = math.sin(math.pi * t) * n;
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, head, [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.9 * alpha),
          ]),
      );
      canvas.drawCircle(head, 2.6, Paint()..color = Colors.white.withValues(alpha: alpha));
    } else {
      if (u < 0.05 || u > 0.75) return;
      final t = (u - 0.05) / 0.7;
      final x = 1300 - t * 380;
      final y = 60 + t * 95 + 10 * math.sin(t * math.pi * 3);
      final flap = math.sin(_turn * 14 * t);
      final alpha = math.min(1.0, math.sin(math.pi * t) * 3) * n;
      final paint = Paint()..color = const Color(0xFF1C1A2A).withValues(alpha: 0.85 * alpha);
      final c = Offset(x, y);
      canvas.drawOval(Rect.fromCenter(center: c, width: 6, height: 4), paint);
      for (final s in const [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..quadraticBezierTo(c.dx + s * 6, c.dy - 6 * flap - 2, c.dx + s * 13, c.dy - 3 * flap)
            ..quadraticBezierTo(c.dx + s * 8, c.dy + 1, c.dx + s * 4, c.dy + 2)
            ..close(),
          paint,
        );
      }
    }
  }

  // سحب ليلية خفيفة يضيئها القمر، تنجرف ببطء في الاتجاه المعاكس
  void _nightClouds(Canvas canvas, double v, double n) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13 * n)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    for (final (offset, y, s) in const [(0.2, 62.0, 1.1), (0.7, 168.0, 0.85)]) {
      final x = 1440 - ((v + offset) % 1) * 960;
      canvas
        ..drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 120 * s, height: 22 * s),
          paint,
        )
        ..drawOval(
          Rect.fromCenter(
            center: Offset(x + 30 * s, y - 9 * s),
            width: 70 * s,
            height: 18 * s,
          ),
          paint,
        );
    }
  }

  // سحابتان ناعمتان تعبران النافذة ببطء شديد (عبور كامل في 3 دقائق)
  void _clouds(Canvas canvas, double v, double day) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42 * day)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    void cloud(double x, double y, double s) {
      canvas
        ..drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 90 * s, height: 26 * s),
          paint,
        )
        ..drawCircle(Offset(x - 16 * s, y - 10 * s), 17 * s, paint)
        ..drawCircle(Offset(x + 14 * s, y - 14 * s), 22 * s, paint);
    }

    for (final (offset, y, s) in const [(0.0, 78.0, 1.0), (0.55, 150.0, 0.75)]) {
      cloud(480 + ((v + offset) % 1) * 960, y, s);
    }
  }

  // طائران صغيران يعبران كل 7.5 ثانية تقريبًا (نهارًا)
  void _birds(Canvas canvas, double v, double day) {
    if (day < 0.5) return;
    final idx = (v * 24).floor();
    final u = (v * 24) % 1;
    if (u < 0.15 || u > 0.8) return;
    final t = (u - 0.15) / 0.65;
    final alpha = math.min(1.0, math.sin(math.pi * t) * 3) * day;
    final paint = Paint()
      ..color = const Color(0xFF4B4A63).withValues(alpha: 0.65 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final baseY = 140.0 + 50 * _hash(idx, 7);
    final ltr = idx.isEven;
    for (final (lag, dy) in const [(0.0, 0.0), (0.05, 16.0)]) {
      final tt = (t - lag).clamp(0.0, 1.0);
      final x = ltr ? 600 + tt * 720 : 1320 - tt * 720;
      final y = baseY + dy + 18 * math.sin(tt * math.pi * 1.2) - tt * 26;
      final wing = 6.0 * math.sin(_turn * 30 * tt + lag * 9);
      canvas.drawPath(
        Path()
          ..moveTo(x - 9, y - wing)
          ..quadraticBezierTo(x - 4, y - 3, x, y)
          ..quadraticBezierTo(x + 4, y - 3, x + 9, y - wing),
        paint,
      );
    }
  }

  // فراشة ليلية صغيرة تدور حول ضوء المصباح لثوانٍ ثم تختفي وتعود (دورة 12 ثانية)
  void _moth(Canvas canvas, double v, double n) {
    final u = (v * 15) % 1;
    final vis = _visible(u, 0.05, 0.7);
    if (vis < 0.02) return;
    final angle = _turn * (v * 15 * 2.2);
    final c = Offset(
      392 + 48 * math.cos(angle) + 4 * math.sin(angle * 5),
      236 + 22 * math.sin(angle) + 3 * math.cos(angle * 7),
    );
    final flap = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(_turn * 140 * v));
    final paint = Paint()..color = const Color(0xFFF3E9D2).withValues(alpha: 0.9 * vis * n);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle + math.pi / 2);
    for (final s in const [-1.0, 1.0]) {
      canvas.save();
      canvas.scale(s * flap, 1);
      canvas.drawOval(const Rect.fromLTWH(0.5, -4, 6, 7), paint);
      canvas.restore();
    }
    canvas.drawOval(
      const Rect.fromLTWH(-1, -3, 2, 6),
      Paint()..color = const Color(0xFF8C7B66).withValues(alpha: 0.9 * vis * n),
    );
    canvas.restore();
  }

  // ظهور تدريجي بين a وb (يظهر ثم يختفي بنعومة)
  static double _visible(double u, double a, double b) {
    if (u <= a || u >= b) return 0;
    final t = (u - a) / (b - a);
    return math.min(1.0, math.min(t, 1 - t) * 6);
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.p != p || old.anim != anim;
}

// ---------------------------------------------------------------------------
// 3) البومة: مرسومة بالكود كما كانت، وتجلس على مكتب الرسمة
// ---------------------------------------------------------------------------

class _LifePainter extends CustomPainter {
  _LifePainter(this.anim, this.p) : super(repaint: anim);

  final Animation<double> anim;
  final _ScenePalette p;

  static const double _tau = math.pi * 2;

  // موضع قدمي البومة على مكتب الرسمة، وحجمها (بكسل صورة لكل وحدة رسم)
  static const Offset _seat = Offset(780, 428);
  static const double _size = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    // دورة البومة 10 ثوانٍ داخل دورة المشهد (18 دورة بالضبط فلا قفزة)
    final g = anim.value;
    final v = (g * 18) % 1;
    canvas.save();
    _ArtFrame(size).apply(canvas);
    canvas
      ..translate(_seat.dx, _seat.dy)
      ..scale(_size)
      ..translate(-200, -(_deskY + 1));
    _owl(canvas, v, g);
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

  void _owl(Canvas canvas, double v, double g) {
    final night = p.night;
    // القهوة مساءً وليلًا فقط: تخرج الكوب من تحت جناحها كأنه جيب (0.55–0.63)،
    // ترتشف (0.74–0.94)، ثم تعيده (0.94–1.0). نهارًا لا كوب.
    final take = night ? _ease(v, 0.55, 0.63) : 0.0;
    final putBack = night ? _ease(v, 0.94, 1.0) : 0.0;
    final mugVis = take - putBack;
    final sip = night ? _ease(v, 0.74, 0.80) - _ease(v, 0.88, 0.94) : 0.0;
    // النشاط: صباحًا نشيطة جدًا، ظهرًا يقظة، ليلًا هادئة نعسانة
    final energy = night ? 0.0 : (p.morning ? 1.0 : 0.6);
    // التنفس ليلًا ثلاث دورات بطيئة، ونهارًا قفزات خفيفة أسرع
    final breath = night ? math.sin(_tau * 3 * v) : math.sin(_tau * 4 * v);
    final hop = energy * (0.5 - 0.5 * math.cos(_tau * 4 * v));
    final sway = energy * 0.045 * math.sin(_tau * 2 * v);
    // تلويح بالجناح الأيسر نهارًا (0.10–0.38) مع اهتزاز سريع
    final wave =
        energy == 0 ? 0.0 : _ease(v, 0.10, 0.15) - _ease(v, 0.33, 0.38);
    final waggle = 0.35 * wave * math.sin(_tau * 14 * v);
    // ليلًا كل 20 ثانية: تغفو ببطء ثم تصحو فجأة بعينين مفتوحتين، وبعدها
    // تنظر إلى القمر لحظة
    final u = (g * 9) % 1;
    final doze = night ? _ease(u, 0.02, 0.12) - _ease(u, 0.14, 0.15) : 0.0;
    final wake = night ? _bump(u, 0.145, 0.21) : 0.0;
    final look = night ? _ease(u, 0.52, 0.55) - _ease(u, 0.65, 0.68) : 0.0;
    // الرمش: رمشتان سريعتان، والعينان مغمضتان أثناء الرشفة
    final blink = math.max(_bump(v, 0.30, 0.33), _bump(v, 0.56, 0.59));
    final lidBase = night ? 0.42 : 0.0; // نعسانة ليلًا
    final sleepy = (lidBase + (1 - lidBase) * doze) * (1 - wake) * (1 - 0.5 * look);
    final lid = math.max(math.max(sleepy, blink), sip);

    canvas.save();
    canvas.translate(200, _deskY + 1);
    // ظل خفيف على المكتب، وظل طويل يرسمه ضوء المصباح نحو اليمين
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 96, height: 9),
      Paint()..color = const Color(0x22000000),
    );
    final shade = 0.12 + 0.12 * p.nightness;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(44, 1.5), width: 120, height: 9),
      Paint()
        ..color = Colors.black.withValues(alpha: shade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas
      ..translate(0, -3.5 * hop - 2.5 * wake)
      ..rotate(sway);
    if (p.morning) _sparkles(canvas, v);

    // كل البومة في طبقة واحدة حتى يقع عليها ضوء المصباح وضوء القمر
    canvas.saveLayer(const Rect.fromLTRB(-150, -160, 170, 40), Paint());

    canvas.save();
    // تغفو: ينضغط جسمها قليلًا كأن رأسها ينحني
    canvas.scale(1 - 0.008 * breath, (1 + 0.018 * breath) * (1 - 0.035 * doze));

    final body = Path()
      ..moveTo(0, -98)
      ..cubicTo(30, -98, 46, -80, 46, -52)
      ..cubicTo(48, -22, 36, 0, 0, 0)
      ..cubicTo(-36, 0, -48, -22, -46, -52)
      ..cubicTo(-46, -80, -30, -98, 0, -98)
      ..close();

    // ظلها على الجدار خلفها: صورة ناعمة لجسمها مزاحة نحو اليمين بعيدًا عن المصباح
    canvas.save();
    canvas.translate(24, -3);
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.06 + 0.08 * p.nightness)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -98),
          Offset.zero,
          const [_body, _bodyShade],
        ),
    );

    // خصلتا الأذنين بلون الرأس نفسه فتخرجان منه كجسم واحد بلا خط عند القاعدة
    final tuftPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -98),
        Offset.zero,
        const [_body, _bodyShade],
      );
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

    // العينان (تنظران نحو القمر لحظة ليلًا)
    final gaze = Offset(2.2, -1.6) * look;
    for (final x in const [-17.0, 17.0]) {
      _eyeAt(canvas, Offset(x, -64), lid, wide: energy > 0 || wake > 0.3, gaze: gaze);
    }

    // المنقار (بلا احمرار خدود بطلب المستخدم)
    final beak = Path()
      ..moveTo(-4.5, -56)
      ..quadraticBezierTo(0, -58, 4.5, -56)
      ..quadraticBezierTo(1, -48, 0, -47)
      ..quadraticBezierTo(-1, -48, -4.5, -56)
      ..close();
    canvas.drawPath(beak, Paint()..color = _beak);

    // الجناح الأيسر: مرتاح على الجانب، ويرتفع للتلويح نهارًا (المحور عند الكتف)
    _blendWing(canvas, body, () {
      canvas
        ..translate(-38, -50)
        ..rotate(0.28 + 2.4 * wave + waggle);
    }, Rect.fromCenter(center: const Offset(0, 22), width: 20, height: 46));

    // القدمان
    final feet = Paint()..color = _feet;
    canvas
      ..drawOval(Rect.fromCenter(center: const Offset(-12, -1), width: 13, height: 5), feet)
      ..drawOval(Rect.fromCenter(center: const Offset(12, -1), width: 13, height: 5), feet);

    canvas.restore(); // نهاية التنفس

    // الكوب: يخرج من تحت الجناح (الجيب)، ثم إلى المنقار، ثم يعود
    const pocket = Offset(30, -24);
    const rest = Offset(40, -15);
    final base = Offset.lerp(pocket, rest, mugVis)!;
    final mug = Offset.lerp(base, const Offset(16, -44), sip)!;
    final tilt = -0.65 * sip;
    if (mugVis > 0.01) _mug(canvas, mug, tilt, v, sip, mugVis);

    // الجناح الأيمن: يتدلى على جانبها، ومع الكوب يمتد من الكتف إلى جانبه
    // كيد تمسكه حتى المنقار
    const shoulder = Offset(34, -46);
    final hold = mug +
        Offset(
          -10 * math.cos(tilt) - 4 * math.sin(tilt),
          -10 * math.sin(tilt) + 4 * math.cos(tilt),
        );
    final hand = Offset.lerp(const Offset(38, -8), hold, mugVis)!;
    final reach = hand - shoulder;
    final breathing = Matrix4.diagonal3Values(
      1 - 0.008 * breath,
      (1 + 0.018 * breath) * (1 - 0.035 * doze),
      1,
    );
    _blendWing(
      canvas,
      body.transform(breathing.storage),
      () {
        canvas
          ..translate(shoulder.dx, shoulder.dy)
          ..rotate(math.atan2(-reach.dx, reach.dy));
      },
      Rect.fromLTWH(-10, -3, 20, reach.distance + 6),
      front: mugVis > 0.05 ? _mugArea(mug, tilt) : null,
    );

    // ضوء المكان على البومة: أدفأ من جهة المصباح، وبارد من القمر ليلًا
    final warmA = 0.06 + 0.16 * p.nightness;
    final coolA = 0.2 * p.nightness;
    canvas.drawRect(
      const Rect.fromLTRB(-150, -160, 170, 40),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.linear(
          const Offset(-55, 0),
          const Offset(55, 0),
          [
            const Color(0xFFFFC98A).withValues(alpha: warmA),
            const Color(0xFFFFC98A).withValues(alpha: 0),
            const Color(0xFF9FB4FF).withValues(alpha: 0),
            const Color(0xFF9FB4FF).withValues(alpha: coolA),
          ],
          const [0, 0.45, 0.55, 1],
        ),
    );
    canvas.restore(); // نهاية طبقة البومة

    canvas.restore();
  }

  // جناح متصل بالجسم بلا حافة ظاهرة: ما يخرج من الجسم حاد بلونه، وما يقع
  // فوق الجسم يذوب فيه بنعومة. place يضع الجناح (إزاحة ودوران) بعد القص.
  // front: منطقة يبقى فيها الجناح حادًا وإن كانت فوق الجسم (الكوب الممسوك).
  void _blendWing(
    Canvas canvas,
    Path body,
    void Function() place,
    Rect oval, {
    Path? front,
  }) {
    final soft =
        front == null ? body : Path.combine(PathOperation.difference, body, front);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTRB(-300, -300, 300, 300)),
      soft,
    );
    canvas.save();
    canvas.clipPath(outside);
    place();
    canvas.drawOval(oval, Paint()..color = _wing);
    canvas.restore();

    canvas.save();
    canvas.clipPath(soft);
    place();
    canvas.drawOval(
      oval,
      Paint()
        ..color = _wing.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.restore();
  }

  // شكل الكوب (الجسم والمقبض) في مكانه، لتمييز ما يقع أمامه من الجناح
  Path _mugArea(Offset c, double tilt) {
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(tilt);
    return (Path()
          ..addRect(const Rect.fromLTRB(-12, -14, 12, 13))
          ..addOval(Rect.fromCircle(center: const Offset(12, 0), radius: 8.5)))
        .transform(m.storage);
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

  // wide: عينان أوسع ولامعتان (نهارًا وعند الاستيقاظ). gaze: اتجاه النظر.
  void _eyeAt(
    Canvas canvas,
    Offset c,
    double lid, {
    bool wide = false,
    Offset gaze = Offset.zero,
  }) {
    final w = wide ? 13.0 : 11.0;
    final h = wide ? 14.0 : 12.0;
    final top = c.dy - h / 2;
    final lidY = top + h * lid.clamp(0.0, 1.0);
    if (lid < 0.98) {
      final e = c + gaze;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(c.dx - w, lidY, c.dx + w, c.dy + h));
      canvas.drawOval(
        Rect.fromCenter(center: e, width: w, height: h),
        Paint()..color = _eye,
      );
      canvas.drawCircle(
        e + const Offset(-1.8, -2.2),
        wide ? 2.8 : 2.2,
        Paint()..color = Colors.white,
      );
      if (wide) {
        canvas.drawCircle(
          e + const Offset(2.4, 2.6),
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

  // الكوب بلون الثيم. vis: ظهوره وهو يخرج من الجيب أو يعود إليه (يكبر ويظهر)
  void _mug(Canvas canvas, Offset c, double tilt, double v, double sip, double vis) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    canvas.scale(0.55 + 0.45 * vis);
    final paintAlpha = vis.clamp(0.0, 1.0);
    final body = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 26),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(7),
      bottomRight: const Radius.circular(7),
    );
    // المقبض في الجهة الخارجية (بعيدًا عن البومة) كما يُمسك الكوب عادة
    canvas.drawCircle(
      const Offset(12, 0),
      6.5,
      Paint()
        ..color = p.mug.withValues(alpha: paintAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawRRect(body, Paint()..color = p.mug.withValues(alpha: paintAlpha));
    canvas.drawRect(
      const Rect.fromLTRB(-12, -13, 12, -10),
      Paint()..color = Colors.white.withValues(alpha: 0.12 * paintAlpha),
    );
    canvas.restore();

    // البخار: ثلاثة خيوط تصعد وتتلاشى، أبطأ وأطول ليلًا، وتخفت أثناء الرشفة
    final fade = (1 - sip) * vis;
    if (fade <= 0.02) return;
    final top = c + Offset(0, -15 + 4 * sip);
    final steam = p.night ? Colors.white : const Color(0xFFAFA4C2);
    final speed = p.night ? 3.0 : 5.0;
    final steps = p.night ? 15 : 12;
    final length = steps * 2.7;
    for (var i = 0; i < 3; i++) {
      final phase = _tau * (speed * v) + i * 2.1;
      final path = Path();
      for (var k = 0; k <= steps; k++) {
        final y = top.dy - k * 2.7;
        final x = top.dx - 6 + i * 6 + 2.4 * math.sin(k * 0.6 - phase);
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
            top - Offset(0, length),
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
