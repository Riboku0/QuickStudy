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

// أدوات لوحة القلم: قلم، رصاص، ممحاة، مذكرة لاصقة، نص
enum InkTool { pen, pencil, eraser, note, text }

class InkStroke {
  InkStroke({
    required this.id,
    required this.page,
    this.marker = false,
    this.pencil = false,
    required this.color,
    required this.width,
    required this.points,
  });

  final String id;
  final int page; // يبدأ من 0
  final bool marker; // قلم تظليل: عريض وشفاف
  final bool pencil; // رصاص: أنحف وأخف
  final int color;
  final double width; // نسبة من عرض الصفحة
  final List<Offset> points; // نسبة من الصفحة

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'marker': marker,
    'pencil': pencil,
    'color': color,
    'width': width,
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
    );
  }

  // هل تمر الضربة قرب نقطة؟ (للممحاة)
  bool near(Offset point, double tolerance) {
    final t = tolerance + width / 2;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = i + 1 < points.length ? points[i + 1] : a;
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
    // منحنى ناعم عبر منتصفات النقاط
    final path = Path()..moveTo(at(s.points.first).dx, at(s.points.first).dy);
    for (var i = 1; i < s.points.length - 1; i++) {
      final c = at(s.points[i]);
      final next = at(s.points[i + 1]);
      final mid = Offset((c.dx + next.dx) / 2, (c.dy + next.dy) / 2);
      path.quadraticBezierTo(c.dx, c.dy, mid.dx, mid.dy);
    }
    final last = at(s.points.last);
    path.lineTo(last.dx, last.dy);
    canvas.drawPath(path, paint);
  }
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
