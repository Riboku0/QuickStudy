import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'text_marks.dart';

// تحديدات كتاب واحد في العارض الجديد.
// نفس ملف العارض القديم: quickstudy_notes/{id}_marks.json، فالتحديدات القديمة تظهر هنا.
// المواضع نسبة من الصفحة (0..1)، ورقم الصفحة يبدأ من 0 كما في العارض القديم.
// start/end هنا مواضع أحرف من pdfrx (في القديم أرقام كلمات)، والرسم يعتمد على rects فقط.
class PdfMarks extends ChangeNotifier {
  PdfMarks(this.lectureId);

  final int lectureId;
  final Map<int, List<TextMark>> _byPage = {};

  List<TextMark> forPage(int pageIndex) => _byPage[pageIndex] ?? const [];

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quickstudy_notes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '${lectureId}_marks.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      for (final item in list) {
        final mark = TextMark.fromJson(item as Map<String, dynamic>);
        _byPage.putIfAbsent(mark.page, () => []).add(mark);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load marks: $e');
    }
  }

  // يرجع false إن فشل الحفظ (الواجهة تعرض رسالة)
  Future<bool> save() async {
    try {
      final all = _byPage.values.expand((l) => l).map((m) => m.toJson());
      final file = await _file();
      await file.writeAsString(jsonEncode(all.toList()), flush: true);
      return true;
    } catch (e) {
      debugPrint('Could not save marks: $e');
      return false;
    }
  }

  // تحديد جديد من نص محدد في pdfrx (قد يمتد على أكثر من صفحة: تحديد لكل صفحة)
  List<TextMark> addFromRanges(
    List<PdfPageTextRange> ranges, {
    required List<PdfPage> pages,
    required MarkStyle style,
    required int color,
  }) {
    final created = <TextMark>[];
    var n = 0;
    for (final range in ranges) {
      if (range.end <= range.start) continue;
      final pageIndex = range.pageNumber - 1;
      final mark = TextMark(
        id: '${DateTime.now().microsecondsSinceEpoch}_${n++}',
        page: pageIndex,
        start: range.start,
        end: range.end,
        style: style,
        color: color,
        text: range.text.trim(),
        rects: lineRects(range, pages[pageIndex]),
      );
      if (mark.rects.isEmpty) continue;
      _byPage.putIfAbsent(pageIndex, () => []).add(mark);
      created.add(mark);
    }
    notifyListeners();
    return created;
  }

  // تحديد من صفحة ممسوحة (start/end أرقام كلمات OCR كما في العارض القديم)
  void add(TextMark mark) {
    _byPage.putIfAbsent(mark.page, () => []).add(mark);
    notifyListeners();
  }

  void update(TextMark mark, {MarkStyle? style, int? color, String? note}) {
    if (style != null) mark.style = style;
    if (color != null) mark.color = color;
    if (note != null) mark.note = note.isEmpty ? null : note;
    notifyListeners();
  }

  void remove(TextMark mark) {
    _byPage[mark.page]?.removeWhere((m) => m.id == mark.id);
    notifyListeners();
  }

  // التحديد تحت نقطة (نسبة من الصفحة)، الأحدث أولًا
  TextMark? hit(int pageIndex, Offset point) {
    final marks = forPage(pageIndex);
    for (var i = marks.length - 1; i >= 0; i--) {
      if (marks[i].contains(point)) return marks[i];
    }
    return null;
  }

  // مستطيل لكل سطر: نجمع أجزاء النص التي تتقاطع عموديًا
  static List<Rect> lineRects(PdfPageTextRange range, PdfPage page) {
    const unit = Rect.fromLTWH(0, 0, 1, 1);
    final lines = <Rect>[];
    for (final f in range.enumerateFragmentBoundingRects()) {
      final r = f.bounds.toRectInDocument(page: page, pageRect: unit);
      final i = lines.indexWhere(
        (l) =>
            (l.center.dy - r.center.dy).abs() <
            math.min(l.height, r.height) * 0.5,
      );
      if (i < 0) {
        lines.add(r);
      } else {
        lines[i] = lines[i].expandToInclude(r);
      }
    }
    lines.sort((a, b) => a.top.compareTo(b.top));
    return lines;
  }
}
