import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// الرسم الحر على الصفحات (العارض الجديد).
// ملف لكل كتاب: quickstudy_notes/{id}_ink.json، بجانب الملاحظات والتحديدات.
// النقاط والسماكة نسبة من الصفحة، فيبقى الرسم في مكانه مع أي زوم.

// أدوات لوحة القلم: قلم، رصاص، ممحاة، أشكال، مذكرة لاصقة، نص، صوت، صورة
enum InkTool { pen, pencil, eraser, shape, note, text, audio, image }

// نوع الخط: متصل، متقطع، منقط، أو متصل بسهم في نهايته
enum InkLine { solid, dashed, dotted, arrow }

// الأشكال: تختارها ثم تسحب من نقطة إلى نقطة (points = البداية والنهاية)
enum InkShape { line, arrow, rect, circle }

class InkStroke {
  InkStroke({
    required this.id,
    required this.page,
    this.marker = false,
    this.pencil = false,
    required this.color,
    required this.width,
    required this.points,
    this.line = InkLine.solid,
    this.shape,
  });

  final String id;
  final int page; // يبدأ من 0
  final bool marker; // قلم تظليل: عريض وشفاف
  final bool pencil; // رصاص: أنحف وأخف
  final int color;
  final double width; // نسبة من عرض الصفحة
  final List<Offset> points; // نسبة من الصفحة
  final InkLine line;
  final InkShape? shape; // null = رسم حر

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'marker': marker,
    'pencil': pencil,
    'color': color,
    'width': width,
    if (line != InkLine.solid) 'line': line.name,
    if (shape != null) 'shape': shape!.name,
    // أرقام مختصرة لتصغير الملف
    'points': [
      for (final pt in points) ...[
        double.parse(pt.dx.toStringAsFixed(4)),
        double.parse(pt.dy.toStringAsFixed(4)),
      ],
    ],
  };

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    final raw = (json['points'] as List).cast<num>();
    return InkStroke(
      id: json['id'] as String,
      page: json['page'] as int,
      marker: json['marker'] == true,
      pencil: json['pencil'] == true,
      color: json['color'] as int,
      width: (json['width'] as num).toDouble(),
      points: [
        for (var i = 0; i + 1 < raw.length; i += 2)
          Offset(raw[i].toDouble(), raw[i + 1].toDouble()),
      ],
      line: InkLine.values.firstWhere(
        (v) => v.name == json['line'],
        orElse: () => InkLine.solid,
      ),
      shape: InkShape.values.where((v) => v.name == json['shape']).firstOrNull,
    );
  }

  // النقاط التي يمر بها الخط فعلًا (للأشكال: حدودها)، للممحاة
  List<Offset> get outline {
    final s = shape;
    if (s == null || points.length < 2) return points;
    final a = points.first;
    final b = points.last;
    switch (s) {
      case InkShape.line:
      case InkShape.arrow:
        return [a, b];
      case InkShape.rect:
        return [a, Offset(b.dx, a.dy), b, Offset(a.dx, b.dy), a];
      case InkShape.circle:
        final c = (a + b) / 2;
        final rx = (b.dx - a.dx).abs() / 2;
        final ry = (b.dy - a.dy).abs() / 2;
        return [
          for (var i = 0; i <= 48; i++)
            c +
                Offset(
                  rx * math.cos(i * math.pi / 24),
                  ry * math.sin(i * math.pi / 24),
                ),
        ];
    }
  }

  // هل تمر الضربة قرب نقطة؟ (للممحاة)
  bool near(Offset point, double tolerance) {
    final t = tolerance + width / 2;
    final pts = outline;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = i + 1 < pts.length ? pts[i + 1] : a;
      if (_distanceToSegment(point, a, b) <= t) return true;
    }
    return false;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}

// رسم الضربات على صفحة بحجمها الحالي
void paintStrokes(Canvas canvas, Size size, Iterable<InkStroke> strokes) {
  for (final s in strokes) {
    if (s.points.isEmpty) continue;
    final w = math.max(1.0, s.width * size.width);
    final paint = Paint()
      ..color = Color(s.color)
          .withValues(alpha: s.marker ? 0.38 : (s.pencil ? 0.7 : 1))
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = s.marker ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset at(Offset n) => Offset(n.dx * size.width, n.dy * size.height);

    if (s.points.length == 1) {
      canvas.drawCircle(
        at(s.points.first),
        w / 2,
        paint..style = PaintingStyle.fill,
      );
      continue;
    }
    final path = _pathFor(s, at);
    final dashed = s.line == InkLine.dashed || s.line == InkLine.dotted;
    canvas.drawPath(dashed ? _dash(path, s.line, w) : path, paint);
    if (s.line == InkLine.arrow || s.shape == InkShape.arrow) {
      _arrowHead(canvas, path, w, paint);
    }
  }
}

Path _pathFor(InkStroke s, Offset Function(Offset) at) {
  final a = at(s.points.first);
  final b = at(s.points.last);
  switch (s.shape) {
    case InkShape.line:
    case InkShape.arrow:
      return Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    case InkShape.rect:
      return Path()..addRect(Rect.fromPoints(a, b));
    case InkShape.circle:
      return Path()..addOval(Rect.fromPoints(a, b));
    case null:
      // منحنى ناعم عبر منتصفات النقاط
      final path = Path()..moveTo(a.dx, a.dy);
      for (var i = 1; i < s.points.length - 1; i++) {
        final c = at(s.points[i]);
        final next = at(s.points[i + 1]);
        final mid = Offset((c.dx + next.dx) / 2, (c.dy + next.dy) / 2);
        path.quadraticBezierTo(c.dx, c.dy, mid.dx, mid.dy);
      }
      return path..lineTo(b.dx, b.dy);
  }
}

// تقطيع المسار: المتقطع شرطات بطول 3 أضعاف السماكة، والمنقط نقاط مستديرة
Path _dash(Path source, InkLine line, double w) {
  final dotted = line == InkLine.dotted;
  final on = dotted ? 0.01 : w * 3;
  final off = dotted ? w * 2 : w * 2.2;
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      out.addPath(
        metric.extractPath(d, math.min(d + on, metric.length)),
        Offset.zero,
      );
      d += on + off;
    }
  }
  return out;
}

// رأس السهم في نهاية المسار باتجاه آخر جزء منه
void _arrowHead(Canvas canvas, Path path, double w, Paint paint) {
  final metrics = path.computeMetrics().toList();
  if (metrics.isEmpty) return;
  final m = metrics.last;
  if (m.length < 2) return;
  final end = m.getTangentForOffset(m.length);
  // الاتجاه من نقطة قبل النهاية بقليل حتى لا يتأثر برجفة الإصبع الأخيرة
  final back = m.getTangentForOffset(
    math.max(0, m.length - math.max(8, w * 3)),
  );
  if (end == null || back == null) return;
  final dir = end.position - back.position;
  if (dir.distance == 0) return;
  final angle = math.atan2(dir.dy, dir.dx);
  final len = math.max(10.0, w * 4);
  final head = Path()
    ..moveTo(
      end.position.dx - len * math.cos(angle - 0.5),
      end.position.dy - len * math.sin(angle - 0.5),
    )
    ..lineTo(end.position.dx, end.position.dy)
    ..lineTo(
      end.position.dx - len * math.cos(angle + 0.5),
      end.position.dy - len * math.sin(angle + 0.5),
    );
  canvas.drawPath(head, paint);
}

// ضربات كتاب واحد + التراجع والإعادة
class PdfInk extends ChangeNotifier {
  PdfInk(this.lectureId);

  final int lectureId;
  final Map<int, List<InkStroke>> _byPage = {};

  // كل خطوة: إضافة أو حذف ضربات (الممحاة قد تحذف عدة ضربات بحركة واحدة)
  final List<({bool added, List<InkStroke> strokes})> _undo = [];
  final List<({bool added, List<InkStroke> strokes})> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  List<InkStroke> forPage(int page) => _byPage[page] ?? const [];

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quickstudy_notes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '${lectureId}_ink.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      for (final item in list) {
        final s = InkStroke.fromJson(item as Map<String, dynamic>);
        _byPage.putIfAbsent(s.page, () => []).add(s);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load ink: $e');
    }
  }

  Future<bool> save() async {
    try {
      final all = _byPage.values.expand((l) => l).map((s) => s.toJson());
      await (await _file()).writeAsString(
        jsonEncode(all.toList()),
        flush: true,
      );
      return true;
    } catch (e) {
      debugPrint('Could not save ink: $e');
      return false;
    }
  }

  void add(InkStroke stroke) {
    _put([stroke]);
    _undo.add((added: true, strokes: [stroke]));
    _redo.clear();
    notifyListeners();
  }

  // الممحاة: حذف الضربات القريبة من النقطة، كخطوة واحدة في التراجع
  bool eraseAt(int page, Offset point, double tolerance) {
    final hit = forPage(page).where((s) => s.near(point, tolerance)).toList();
    if (hit.isEmpty) return false;
    _take(hit);
    _undo.add((added: false, strokes: hit));
    _redo.clear();
    notifyListeners();
    return true;
  }

  void undo() {
    if (_undo.isEmpty) return;
    final step = _undo.removeLast();
    step.added ? _take(step.strokes) : _put(step.strokes);
    _redo.add(step);
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final step = _redo.removeLast();
    step.added ? _put(step.strokes) : _take(step.strokes);
    _undo.add(step);
    notifyListeners();
  }

  void _put(List<InkStroke> strokes) {
    for (final s in strokes) {
      _byPage.putIfAbsent(s.page, () => []).add(s);
    }
  }

  void _take(List<InkStroke> strokes) {
    final ids = {for (final s in strokes) s.id};
    for (final s in strokes) {
      _byPage[s.page]?.removeWhere((x) => ids.contains(x.id));
    }
  }
}
