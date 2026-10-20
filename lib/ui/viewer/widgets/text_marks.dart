import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/core_ui.dart' show AppIcon, AppIcons, AppIconData;

import 'package:syncfusion_flutter_pdf/pdf.dart'
    show PdfDocument, PdfTextExtractor;

// ---------------------------------------------------------------------------
// تحديد النص وتلوينه في العارض
// الصفحات تُعرض كصور، فنستخرج مواضع الكلمات من ملف PDF ونرسم التحديد فوقها.
// ملفات PDF الممسوحة (صور فقط) لا تحتوي نصًا، فلا يمكن التحديد فيها.
// ---------------------------------------------------------------------------

enum MarkStyle { highlight, underline, strike, squiggly }

// ألوان التحديد (ثابتة: العارض فاتح دائمًا)
const List<int> markColors = [
  0xFFFFD84D, // أصفر
  0xFF9ACD6E, // أخضر
  0xFFFF9F43, // برتقالي
  0xFFE29BD8, // وردي
  0xFF6CC4F2, // أزرق
];

final RegExp _rtlChars = RegExp(r'[֐-ࣿﭐ-﷿ﹰ-﻿]');

// كلمة في الصفحة، وموضعها نسبة من حجم الصفحة (0..1)
class PageWord {
  const PageWord(this.text, this.rect, this.line, this.rtl);

  final String text;
  final Rect rect;
  final int line;
  final bool rtl;
}

// يستخرج كلمات كل صفحة مرة واحدة في Isolate منفصل (لا يجمّد الواجهة)
// كلمة من OCR قبل ترتيبها (النص، الموضع نسبة من الصفحة، رقم السطر)
typedef RawWord = ({String text, Rect rect, int line});

class PageTextCache {
  PageTextCache(this._bytes, {this.ocr});

  final List<int> _bytes;
  final Map<int, Future<List<PageWord>>> _pages = {};

  // التعرف الضوئي للصفحات الممسوحة (اختياري)
  final Future<List<RawWord>> Function(int page)? ocr;

  // أقل من هذا العدد = الصفحة صورة غالبًا (أو فيها علامة مائية فقط)
  static const int minTextWords = 25;

  Future<List<PageWord>> words(int page) => _pages[page] ??= _load(page);

  // تجهيز مسبق في الخلفية (بلا انتظار): الصفحة الممسوحة تُقرأ قبل أن
  // يضغط المستخدم عليها، فيكون التحديد فوريًا. الصفحة المجهزة لا تتكرر.
  void prefetch(int page) {
    if (page < 0 || _pages.containsKey(page)) return;
    words(page).ignore();
  }

  // صفحة تحتاج OCR ولم تُعالج بعد؟ (لإظهار رسالة "جارٍ قراءة الصفحة")
  bool isReady(int page) => _ready.contains(page);
  final Set<int> _ready = {};

  Future<List<PageWord>> _load(int page) async {
    var text = const <PageWord>[];
    try {
      text = await _extractInIsolate(_bytes, page);
    } catch (e) {
      debugPrint('[Marks] text extraction failed on page $page: $e');
    }

    final ocr = this.ocr;
    if (ocr == null || text.length >= minTextWords) {
      _ready.add(page);
      return text;
    }

    try {
      final scanned = orderWords(await ocr(page));
      _ready.add(page);
      return scanned.length > text.length ? scanned : text;
    } catch (e) {
      debugPrint('[Marks] OCR failed on page $page: $e');
      _pages.remove(page); // محاولة أخرى في الضغطة القادمة
      return text;
    }
  }
}

// ترتيب كلمات OCR للقراءة: الأسطر من الأعلى، والكلمات حسب اتجاه السطر
List<PageWord> orderWords(List<RawWord> raw) {
  final byLine = <int, List<RawWord>>{};
  for (final w in raw) {
    byLine.putIfAbsent(w.line, () => []).add(w);
  }

  final lines = byLine.values.toList()
    ..sort((a, b) => a.first.rect.top.compareTo(b.first.rect.top));

  final result = <PageWord>[];
  for (var li = 0; li < lines.length; li++) {
    final words = lines[li];
    final rtl = words.any((w) => _rtlChars.hasMatch(w.text));
    words.sort(
      (a, b) => rtl
          ? b.rect.left.compareTo(a.rect.left)
          : a.rect.left.compareTo(b.rect.left),
    );
    for (final w in words) {
      result.add(PageWord(w.text, w.rect, li, rtl));
    }
  }
  return result;
}

// دالة عليا (ليست داخل الكلاس): الدالة المرسلة للـ Isolate تحمل كل ما حولها،
// فلو أُنشئت داخل الكلاس لحملت _pages وفيها Future لا يمكن إرسالها.
Future<List<PageWord>> _extractInIsolate(List<int> bytes, int page) =>
    Isolate.run(() => _extractWords(bytes, page));

List<PageWord> _extractWords(List<int> bytes, int page) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    final size = doc.pages[page].size;
    if (size.width <= 0 || size.height <= 0) return const [];

    final lines = PdfTextExtractor(doc)
        .extractTextLines(startPageIndex: page, endPageIndex: page);

    // ترتيب القراءة: الأسطر من الأعلى، والكلمات حسب اتجاه السطر
    lines.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    final result = <PageWord>[];
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final rtl = _rtlChars.hasMatch(line.text);
      final words =
          line.wordCollection
              .where((w) => w.text.trim().isNotEmpty && w.bounds.width > 0)
              .toList()
            ..sort(
              (a, b) => rtl
                  ? b.bounds.left.compareTo(a.bounds.left)
                  : a.bounds.left.compareTo(b.bounds.left),
            );

      for (final w in words) {
        final b = w.bounds;
        result.add(
          PageWord(
            w.text.trim(),
            Rect.fromLTRB(
              b.left / size.width,
              b.top / size.height,
              b.right / size.width,
              b.bottom / size.height,
            ),
            li,
            rtl,
          ),
        );
      }
    }
    return result;
  } finally {
    doc.dispose();
  }
}

// أقرب كلمة لنقطة (نسبة من الصفحة). exact = داخل الكلمة أو قريبًا جدًا منها.
int? wordAt(List<PageWord> words, Offset p, {bool exact = false}) {
  int? best;
  var bestDistance = double.infinity;

  for (var i = 0; i < words.length; i++) {
    final r = words[i].rect;
    final dx = p.dx < r.left
        ? r.left - p.dx
        : (p.dx > r.right ? p.dx - r.right : 0.0);
    final dy = p.dy < r.top
        ? r.top - p.dy
        : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
    // المسافة العمودية أهم: نفضّل كلمات السطر نفسه
    final d = dx + dy * 3;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }

  if (exact && bestDistance > 0.02) return null;
  return best;
}

// مستطيل واحد لكل سطر داخل المدى [start, end]
List<Rect> rectsFor(List<PageWord> words, int start, int end) {
  final s = math.min(start, end);
  final e = math.max(start, end);
  final byLine = <int, Rect>{};

  for (var i = s; i <= e && i < words.length; i++) {
    final w = words[i];
    final r = byLine[w.line];
    byLine[w.line] = r == null ? w.rect : r.expandToInclude(w.rect);
  }
  return byLine.values.toList();
}

String textFor(List<PageWord> words, int start, int end) {
  final s = math.min(start, end);
  final e = math.max(start, end);
  final buffer = StringBuffer();
  int? line;

  for (var i = s; i <= e && i < words.length; i++) {
    if (buffer.isNotEmpty) buffer.write(words[i].line == line ? ' ' : '\n');
    buffer.write(words[i].text);
    line = words[i].line;
  }
  return buffer.toString();
}

// تحديد محفوظ على صفحة
class TextMark {
  TextMark({
    required this.id,
    required this.page,
    required this.start,
    required this.end,
    required this.style,
    required this.color,
    required this.text,
    required this.rects,
    this.note,
  });

  final String id;
  final int page;
  int start;
  int end;
  MarkStyle style;
  int color;
  String text;
  List<Rect> rects; // نسبة من الصفحة، للرسم بدون استخراج النص
  String? note;

  bool contains(Offset p) => rects.any((r) => r.inflate(0.004).contains(p));

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'start': start,
    'end': end,
    'style': style.name,
    'color': color,
    'text': text,
    'note': note,
    'rects': [
      for (final r in rects) [r.left, r.top, r.right, r.bottom],
    ],
  };

  factory TextMark.fromJson(Map<String, dynamic> json) {
    return TextMark(
      id: json['id'] as String,
      page: json['page'] as int,
      start: json['start'] as int,
      end: json['end'] as int,
      style: MarkStyle.values.firstWhere(
        (s) => s.name == json['style'],
        orElse: () => MarkStyle.highlight,
      ),
      color: json['color'] as int,
      text: (json['text'] as String?) ?? '',
      note: json['note'] as String?,
      rects: [
        for (final r in (json['rects'] as List? ?? const []))
          Rect.fromLTRB(
            (r[0] as num).toDouble(),
            (r[1] as num).toDouble(),
            (r[2] as num).toDouble(),
            (r[3] as num).toDouble(),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// الرسم فوق الصفحة
// ---------------------------------------------------------------------------

class MarksPainter extends CustomPainter {
  MarksPainter({required this.marks, this.selection, this.selectionColor});

  final List<TextMark> marks;
  final List<Rect>? selection;
  // لون التحديد (لون الثيم في العارض الجديد)، والافتراضي أزرق
  final Color? selectionColor;

  static const Color _selectionColor = Color(0x553B82F6);

  @override
  void paint(Canvas canvas, Size size) {
    Rect toPx(Rect r) => Rect.fromLTRB(
      r.left * size.width,
      r.top * size.height,
      r.right * size.width,
      r.bottom * size.height,
    );

    for (final mark in marks) {
      final color = Color(mark.color);
      for (final nr in mark.rects) {
        final r = toPx(nr);
        final stroke = math.max(1.6, r.height * 0.09);

        switch (mark.style) {
          case MarkStyle.highlight:
            canvas.drawRRect(
              RRect.fromRectAndRadius(r.inflate(1), const Radius.circular(3)),
              Paint()..color = color.withValues(alpha: 0.42),
            );
          case MarkStyle.underline:
            _line(
              canvas,
              r.left,
              r.right,
              r.bottom + stroke / 2,
              color,
              stroke,
            );
          case MarkStyle.strike:
            _line(canvas, r.left, r.right, r.center.dy, color, stroke);
          case MarkStyle.squiggly:
            _wave(canvas, r, color, stroke);
        }
      }

      // نقطة صغيرة تدل على وجود ملاحظة
      if ((mark.note ?? '').isNotEmpty && mark.rects.isNotEmpty) {
        final last = toPx(mark.rects.last);
        final radius = math.max(3.5, last.height * 0.18);
        canvas.drawCircle(
          Offset(last.right + radius, last.top),
          radius,
          Paint()..color = color.withValues(alpha: 1),
        );
      }
    }

    final sel = selection;
    if (sel != null) {
      final paint = Paint()..color = selectionColor ?? _selectionColor;
      for (final nr in sel) {
        canvas.drawRect(toPx(nr).inflate(1), paint);
      }
    }
  }

  static void _line(
    Canvas c,
    double x1,
    double x2,
    double y,
    Color color,
    double w,
  ) {
    c.drawLine(
      Offset(x1, y),
      Offset(x2, y),
      Paint()
        ..color = color
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _wave(Canvas c, Rect r, Color color, double w) {
    final amp = math.max(1.5, r.height * 0.08);
    final step = amp * 2.2;
    final y = r.bottom + amp;
    final path = Path()..moveTo(r.left, y);
    var up = true;
    for (var x = r.left; x < r.right; x += step) {
      path.quadraticBezierTo(
        x + step / 2,
        up ? y - amp * 2 : y + amp * 2,
        math.min(x + step, r.right),
        y,
      );
      up = !up;
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.85,
    );
  }

  @override
  bool shouldRepaint(MarksPainter old) =>
      old.marks != marks || old.selection != selection;
}

// مقبض لتوسيع التحديد (قطرة زرقاء)
class SelectionHandle extends StatelessWidget {
  const SelectionHandle({super.key, this.color});

  final Color? color;

  static const double size = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF2F7CF6),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(size),
          bottomRight: Radius.circular(size),
          topRight: Radius.circular(size),
        ),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// قائمة التحديد: الأنواع الأربعة + الألوان + مسح / نسخ / ملاحظة / مشاركة
// ---------------------------------------------------------------------------

class SelectionMenu extends StatelessWidget {
  const SelectionMenu({
    super.key,
    required this.style,
    required this.color,
    required this.hasMark,
    required this.note,
    required this.labels,
    required this.onStyle,
    required this.onColor,
    required this.onDelete,
    required this.onCopy,
    required this.onNote,
    required this.onShare,
    required this.onBookmark,
    required this.onMore,
    this.dark = false,
    this.surface,
    this.accent,
  });

  static const double height = 168;

  final MarkStyle style;
  final int color;
  final bool hasMark; // التحديد محفوظ (يظهر زر المسح)
  final String? note;
  final SelectionLabels labels;
  final ValueChanged<MarkStyle> onStyle;
  final ValueChanged<int> onColor;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onNote;
  final VoidCallback onShare;
  final VoidCallback onBookmark;
  final VoidCallback onMore; // الترجمة والمشاركة
  final bool dark; // ليلي: ألوان كحلية هادئة
  // لون اللوحة (درجة من لون الورق) ولون الثيم للاختيار؛ null = الافتراضي
  final Color? surface;
  final Color? accent;

  Color get _ink => dark ? const Color(0xFFE3E6EC) : const Color(0xFF202020);
  Color get _line => dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  Color get _muted => dark ? const Color(0x99E3E6EC) : const Color(0x8A000000);
  Color get _surface =>
      surface ?? (dark ? const Color(0xFF262B36) : Colors.white);
  Color get _accent => accent ?? const Color(0xFF7259DA);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الأنواع
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final s in MarkStyle.values)
                    _StyleButton(
                      style: s,
                      color: Color(color),
                      selected: hasMark && s == style,
                      tooltip: labels.styleNames[s.index],
                      onTap: () => onStyle(s),
                      ink: _ink,
                      accent: _accent,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // الألوان: دوائر، والمختار بحلقة بلون الثيم
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (i, c) in markColors.indexed)
                    Semantics(
                      button: true,
                      selected: hasMark && c == color,
                      label: labels.colorNames[i],
                      child: InkResponse(
                        onTap: () => onColor(c),
                        radius: 22,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 30,
                          height: 30,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasMark && c == color
                                  ? _accent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if ((note ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
              const SizedBox(height: 8),
              Divider(height: 1, color: _line),
              const SizedBox(height: 2),
              // الإجراءات: أيقونة + اسم صغير
              Row(
                children: [
                  if (hasMark)
                    Expanded(
                      child: _Action(
                        AppIcons.trash,
                        labels.delete,
                        onDelete,
                        _ink,
                      ),
                    ),
                  Expanded(
                    child: _Action(AppIcons.copy, labels.copy, onCopy, _ink),
                  ),
                  Expanded(
                    child: _Action(
                      AppIcons.stickyNote,
                      labels.note,
                      onNote,
                      _ink,
                    ),
                  ),
                  Expanded(
                    child: _Action(
                      AppIcons.bookmarkAdd,
                      labels.bookmark,
                      onBookmark,
                      _ink,
                    ),
                  ),
                  // المشاركة صارت داخل "المزيد" مع الترجمة
                  Expanded(
                    child: _Action(
                      AppIcons.moreHorizontal,
                      labels.more,
                      onMore,
                      _ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// النصوص تأتي من AppStrings (الملف لا يعتمد على اللغة)
class SelectionLabels {
  const SelectionLabels({
    required this.styleNames,
    required this.colorNames,
    required this.delete,
    required this.copy,
    required this.note,
    required this.share,
    required this.bookmark,
    required this.more,
  });

  final List<String> styleNames;
  final List<String> colorNames;
  final String delete;
  final String copy;
  final String note;
  final String share;
  final String bookmark;
  final String more;
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap, this.ink);

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 21, color: ink),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// زر "T" يعرض شكل النوع نفسه
class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.style,
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.ink,
    required this.accent,
  });

  final MarkStyle style;
  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.1,
    );

    final glyph = switch (style) {
      MarkStyle.highlight => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        color: color.withValues(alpha: 0.5),
        child: Text('T', style: base),
      ),
      MarkStyle.underline => Text(
        'T',
        style: base.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: color,
          decorationThickness: 2.5,
        ),
      ),
      MarkStyle.strike => Text(
        'T',
        style: base.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: color,
          decorationThickness: 2.5,
        ),
      ),
      MarkStyle.squiggly => Text(
        'T',
        style: base.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: color,
          decorationThickness: 2,
        ),
      ),
    };

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 50,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: glyph,
        ),
      ),
    );
  }
}
