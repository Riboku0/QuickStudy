import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/ui/core_ui.dart';
import 'pdf_text_tools.dart';
import 'styled_text.dart';

// الملاحظات النصية على الصفحات (العارض الجديد).
// نفس ملف العارض القديم: quickstudy_notes/{id}_notes.json، فالملاحظات القديمة
// تظهر هنا والجديدة تظهر هناك. المواضع نسبة من الصفحة، والخط نسبة من عرضها.
class PageNote {
  PageNote({
    required this.id,
    required this.page,
    required this.x,
    required this.y,
    required this.w,
    required this.size,
    required this.text,
    this.h,
    this.bg,
    this.color = 0xFF202020,
    this.font = 'default',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = 0,
    this.rot = 0,
    this.opacity = 1,
    this.runs,
    Map<String, dynamic>? raw,
  }) : _raw = raw ?? {};

  final String id;
  final int page; // يبدأ من 0
  double x; // الزاوية العلوية (نسبة من عرض الصفحة)
  double y; // نسبة من ارتفاع الصفحة
  double w; // عرض الصندوق نسبة من عرض الصفحة
  double? h; // null = حسب النص
  double size; // حجم الخط نسبة من عرض الصفحة
  String text;
  int? bg; // خلفية (مذكرة لاصقة)، null = شفاف
  int color;
  String font;
  bool bold;
  bool italic;
  bool underline;
  int align; // 0 تلقائي، 1 يسار، 2 وسط، 3 يمين
  double rot; // بالراديان
  double opacity;
  // تنسيق على مقاطع (لون، عريض، مائل، تحته خط، حجم) فوق نمط الصندوق؛
  // null = ملاحظة قديمة أو بلا تنسيق (النص كله بنمط الصندوق)
  List<StyledRun>? runs;
  // حقول لا يعرفها هذا العارض تبقى كما هي عند الحفظ
  final Map<String, dynamic> _raw;

  Map<String, dynamic> toJson() => {
    ..._raw,
    'id': id,
    'page': page,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'size': size,
    'text': text,
    'bg': bg,
    'cover': bg != null,
    'color': color,
    'font': font,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    'align': align,
    'rot': rot,
    'opacity': opacity,
    'runs': runs == null ? null : Runs.toJson(runs!),
  };

  factory PageNote.fromJson(Map<String, dynamic> json) => PageNote(
    id: json['id'] as String,
    page: json['page'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    size: (json['size'] as num).toDouble(),
    text: json['text'] as String,
    h: (json['h'] as num?)?.toDouble(),
    bg:
        (json['bg'] as int?) ??
        ((json['cover'] as bool?) == true ? 0xFFFFFFFF : null),
    color: (json['color'] as int?) ?? 0xFF202020,
    font: (json['font'] as String?) ?? 'default',
    bold: (json['bold'] as bool?) ?? false,
    italic: (json['italic'] as bool?) ?? false,
    underline: (json['underline'] as bool?) ?? false,
    align: (json['align'] as int?) ?? 0,
    rot: (json['rot'] as num?)?.toDouble() ?? 0,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    runs: Runs.fromJson(json['runs']),
    raw: Map<String, dynamic>.of(json),
  );
}

// خطوط الملاحظات: نفس قائمة شريط النص (noteFonts)، ومنها خطوط العارض القديم
final Map<String, String> _googleFonts = {
  for (final f in noteFonts)
    if (f.google != null) f.id: f.google!,
};

TextStyle noteStyle(PageNote note, double fontSize) {
  final color = Color(note.color);
  final base = TextStyle(
    fontSize: fontSize,
    height: 1.4,
    color: color.withValues(alpha: color.a * note.opacity),
    fontWeight: note.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: note.italic ? FontStyle.italic : FontStyle.normal,
    decoration: note.underline ? TextDecoration.underline : TextDecoration.none,
    decorationColor: color,
  );
  final google = _googleFonts[note.font];
  if (google != null) {
    try {
      return GoogleFonts.getFont(google, textStyle: base);
    } catch (_) {}
  }
  if (note.font == 'serif') return base.copyWith(fontFamily: 'serif');
  if (note.font == 'mono') return base.copyWith(fontFamily: 'monospace');
  return base;
}

TextAlign noteAlign(PageNote note) => switch (note.align) {
  1 => TextAlign.left,
  2 => TextAlign.center,
  3 => TextAlign.right,
  // تلقائي: بداية السطر حسب اتجاه النص (يُمرر معه textDirection دائمًا)
  _ => TextAlign.start,
};

// اتجاه النص بقاعدة أول حرف قوي (textDirectionFor) لكل اللغات
TextDirection noteDirection(String text) => textDirectionFor(text);

// الهامش الداخلي للصندوق (نفس العارض القديم)
double notePadding(double fontSize) => fontSize * 0.15;

// صندوق الملاحظة على صفحة بحجم size (للمس والرسم)
Rect noteBox(PageNote note, Size size) {
  final fontSize = note.size * size.width;
  final pad = notePadding(fontSize);
  final width = note.w * size.width;
  double height;
  if (note.h != null) {
    height = note.h! * size.height;
  } else {
    final tp = TextPainter(
      text: note.text.isEmpty
          ? TextSpan(text: ' ', style: noteStyle(note, fontSize))
          : noteSpan(note, noteStyle(note, fontSize)),
      textDirection: noteDirection(note.text),
      textAlign: noteAlign(note),
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: math.max(1, width - pad * 2));
    height = tp.height + pad * 2;
  }
  return Rect.fromLTWH(
    note.x * size.width,
    note.y * size.height,
    width,
    height,
  );
}

// رسم الملاحظات على صفحة (skipId = الملاحظة التي تُكتب الآن)
void paintNotes(
  Canvas canvas,
  Size size,
  Iterable<PageNote> notes, {
  String? skipId,
  bool darkPaper = false,
}) {
  for (final note in notes) {
    if (note.id == skipId || note.text.trim().isEmpty) continue;
    final fontSize = note.size * size.width;
    final pad = notePadding(fontSize);
    final box = noteBox(note, size);

    canvas.save();
    if (note.rot != 0) {
      canvas.translate(box.center.dx, box.center.dy);
      canvas.rotate(note.rot);
      canvas.translate(-box.center.dx, -box.center.dy);
    }
    if (note.bg != null) {
      final bg = Color(note.bg!);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(fontSize * 0.3)),
        Paint()..color = bg.withValues(alpha: bg.a * note.opacity),
      );
    }
    final tp = TextPainter(
      text: noteSpan(
        note,
        _onPaper(noteStyle(note, fontSize), note, darkPaper),
        darkPaper: darkPaper,
      ),
      textDirection: noteDirection(note.text),
      textAlign: noteAlign(note),
      textScaler: TextScaler.noScaling,
    )..layout(minWidth: box.width - pad * 2, maxWidth: box.width - pad * 2);
    tp.paint(canvas, box.topLeft + Offset(pad, pad));
    canvas.restore();
  }
}

class PdfNotes extends ChangeNotifier {
  PdfNotes(this.lectureId);

  final int lectureId;
  final Map<int, List<PageNote>> _byPage = {};

  List<PageNote> forPage(int page) => _byPage[page] ?? const [];

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quickstudy_notes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '${lectureId}_notes.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      for (final item in list) {
        final n = PageNote.fromJson(item as Map<String, dynamic>);
        _byPage.putIfAbsent(n.page, () => []).add(n);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load notes: $e');
    }
  }

  Future<bool> save() async {
    try {
      final all = _byPage.values.expand((l) => l).map((n) => n.toJson());
      await (await _file()).writeAsString(
        jsonEncode(all.toList()),
        flush: true,
      );
      return true;
    } catch (e) {
      debugPrint('Could not save notes: $e');
      return false;
    }
  }

  void add(PageNote note) {
    _byPage.putIfAbsent(note.page, () => []).add(note);
    notifyListeners();
  }

  void remove(PageNote note) {
    _byPage[note.page]?.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }

  void changed() => notifyListeners();

  // الملاحظة تحت نقطة (نسبة من الصفحة)، الأحدث أولًا
  PageNote? hit(int page, Offset point, Size pageSize) {
    final list = forPage(page);
    final at = Offset(point.dx * pageSize.width, point.dy * pageSize.height);
    for (var i = list.length - 1; i >= 0; i--) {
      if (noteBox(list[i], pageSize).inflate(6).contains(at)) return list[i];
    }
    return null;
  }
}

// على الورق الداكن: النص الداكن بلا خلفية يظهر فاتحًا (كالعارض القديم)
// نص الملاحظة بمقاطعه فوق نمط الصندوق (القياس والرسم معًا فيتطابقان). على
// الورق الداكن بلا خلفية تُعرض الألوان الداكنة في المقاطع فاتحة كالنص الأساسي
TextSpan noteSpan(PageNote note, TextStyle base, {bool darkPaper = false}) {
  final runs = note.runs;
  if (runs == null) return TextSpan(text: note.text, style: base);
  final readable = !darkPaper || note.bg != null
      ? runs
      : [
          for (final r in runs)
            r.style.color != null &&
                    Color(r.style.color!).computeLuminance() <= 0.3
                ? StyledRun(r.length, r.style.copyWith(color: 0xFFE6E0D4))
                : r,
        ];
  return Runs.span(note.text, readable, base);
}

TextStyle _onPaper(TextStyle style, PageNote note, bool darkPaper) {
  if (!darkPaper || note.bg != null) return style;
  if (Color(note.color).computeLuminance() > 0.3) return style;
  return style.copyWith(color: const Color(0xFFE6E0D4));
}
