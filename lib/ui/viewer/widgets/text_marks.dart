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

// كلمات طبقة النص في صفحة (بلا OCR)، مرتبة للقراءة، في Isolate
Future<List<PageWord>> extractPageWords(List<int> bytes, int page) =>
    _extractInIsolate(bytes, page);

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
  MarksPainter({
    required this.marks,
    this.selection,
    this.selectionColor,
    this.focus,
    this.focusColor,
  });

  final List<TextMark> marks;
  final List<Rect>? selection;
  // لون التحديد (لون الثيم في العارض الجديد)، والافتراضي أزرق
  final Color? selectionColor;
  // تظليل محفوظ مختار: إطار رفيع حوله بدل طبقة فوقه (تُعكّر لونه)
  final List<Rect>? focus;
  final Color? focusColor;

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
            // حبة مستديرة لكل سطر، أقصر قليلًا من السطر حتى لا تتلاصق الأسطر
            // فتصير كتلة واحدة أغمق في التداخل
            canvas.drawRRect(
              _pill(r),
              Paint()..color = color.withValues(alpha: 0.40),
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

      // شارة الملاحظة: دائرة بدرجة أعمق من لون التحديد وحلقة بيضاء، فيها
      // ورقة بأسطر، على الزاوية العليا لآخر سطر (نفس مكان النقطة القديمة،
      // فاللمس عليها كما هو)
      if ((mark.note ?? '').isNotEmpty && mark.rects.isNotEmpty) {
        final last = toPx(mark.rects.last);
        _noteBadge(canvas, Offset(last.right, last.top), last.height, color);
      }
    }

    final sel = selection;
    if (sel != null) {
      final paint = Paint()..color = selectionColor ?? _selectionColor;
      for (final nr in sel) {
        canvas.drawRRect(_pill(toPx(nr)), paint);
      }
    }

    final focused = focus;
    if (focused != null) {
      for (final nr in focused) {
        final r = toPx(nr);
        canvas.drawRRect(
          _pill(r).inflate(1.5),
          Paint()
            ..color = focusColor ?? selectionColor ?? _selectionColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, r.height * 0.06),
        );
      }
    }
  }

  static RRect _pill(Rect r) {
    final pad = r.height * 0.06;
    final box = Rect.fromLTRB(
      r.left - r.height * 0.12,
      r.top + pad,
      r.right + r.height * 0.12,
      r.bottom - pad,
    );
    return RRect.fromRectAndRadius(box, Radius.circular(box.height * 0.32));
  }

  static void _noteBadge(Canvas c, Offset at, double lineHeight, Color color) {
    final radius = math.max(7.0, lineHeight * 0.42);
    final center = at.translate(radius * 0.35, -radius * 0.15);
    final deep = HSLColor.fromColor(color);
    final fill = deep
        .withLightness((deep.lightness * 0.72).clamp(0.28, 0.5))
        .withSaturation((deep.saturation * 1.05).clamp(0.0, 0.9))
        .toColor();

    c.drawCircle(
      center.translate(0, radius * 0.12),
      radius * 1.12,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3),
    );
    c.drawCircle(center, radius * 1.12, Paint()..color = Colors.white);
    c.drawCircle(center, radius * 0.92, Paint()..color = fill);

    // ورقة بزاوية مستديرة وثلاثة أسطر
    final w = radius * 0.9;
    final h = radius * 1.05;
    final sheet = Rect.fromCenter(center: center, width: w, height: h);
    c.drawRRect(
      RRect.fromRectAndRadius(sheet, Radius.circular(radius * 0.16)),
      Paint()..color = Colors.white,
    );
    final ink = Paint()
      ..color = fill
      ..strokeWidth = math.max(1.0, radius * 0.11)
      ..strokeCap = StrokeCap.round;
    for (final (i, f) in [0.62, 0.62, 0.38].indexed) {
      final y = sheet.top + h * (0.3 + i * 0.2);
      c.drawLine(
        Offset(sheet.left + w * 0.2, y),
        Offset(sheet.left + w * (0.2 + f), y),
        ink,
      );
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
// قائمة التحديد: الأنواع الأربعة + الألوان + مسح / نسخ / ملاحظة / علامة / المزيد
// شكلها من مرجع المستخدم (23 أكتوبر): بطاقة ناعمة بزوايا كبيرة وذيل يشير إلى
// النص، الأنواع في شريط مستدير والمختار رقاقة بلون التحديد، دوائر ألوان بحلقة
// بيضاء، والإجراءات في دوائر خفيفة بينها فواصل. الألوان من الورق والثيم.
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
    this.tailX,
    this.tailUp = false,
  });

  // ارتفاع البطاقة بلا الذيل، تقدير أول (العارض يقيسه بعد الرسم)
  static const double height = 222;
  static const double tail = 10;

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
  // لون اللوحة (درجة من لون الورق) ولون الثيم؛ null = الافتراضي
  final Color? surface;
  final Color? accent;
  // مكان الذيل أفقيًا داخل القائمة (null = بلا ذيل)، وtailUp = القائمة تحت النص
  final double? tailX;
  final bool tailUp;

  Color get _ink => dark ? const Color(0xFFE3E6EC) : const Color(0xFF2A2A2E);
  Color get _line => dark ? const Color(0x1FFFFFFF) : const Color(0x12000000);
  Color get _muted => dark ? const Color(0x99E3E6EC) : const Color(0x8A000000);
  Color get _surface =>
      surface ?? (dark ? const Color(0xFF262B36) : Colors.white);
  // خلفية الشريط والدوائر: أغمق قليلًا من اللوحة نهارًا وأفتح ليلًا
  Color get _well => dark ? const Color(0x12FFFFFF) : const Color(0x0A000000);

  @override
  Widget build(BuildContext context) {
    final selected = Color(color);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.40 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          // توهج خفيف بلون التحديد المختار
          BoxShadow(
            color: selected.withValues(alpha: dark ? 0.10 : 0.18),
            blurRadius: 36,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الأنواع في شريط مستدير، بينها فواصل رفيعة
              Container(
                height: 56,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _well,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    for (final (i, s) in MarkStyle.values.indexed) ...[
                      if (i > 0)
                        _Separator(
                          color: _line,
                          hidden:
                              hasMark &&
                              (s == style || MarkStyle.values[i - 1] == style),
                        ),
                      Expanded(
                        child: _StyleButton(
                          style: s,
                          color: selected,
                          selected: hasMark && s == style,
                          tooltip: labels.styleNames[s.index],
                          onTap: () => onStyle(s),
                          ink: _ink,
                          dark: dark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // الألوان: دوائر بحلقة بيضاء، والمختار بحلقة من لونه
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (i, c) in markColors.indexed)
                    _ColorDot(
                      color: Color(c),
                      selected: hasMark && c == color,
                      label: labels.colorNames[i],
                      ring: _surface,
                      onTap: () => onColor(c),
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
              const SizedBox(height: 10),
              Divider(height: 1, color: _line),
              const SizedBox(height: 6),
              // الإجراءات: دائرة خفيفة بأيقونة + اسم صغير، بينها فواصل
              IntrinsicHeight(
                child: Row(
                  children: [
                    for (final (i, a) in [
                      if (hasMark) (AppIcons.trash, labels.delete, onDelete),
                      (AppIcons.copy, labels.copy, onCopy),
                      (AppIcons.stickyNote, labels.note, onNote),
                      (AppIcons.bookmarkAdd, labels.bookmark, onBookmark),
                      // المشاركة داخل "المزيد" مع الترجمة
                      (AppIcons.moreHorizontal, labels.more, onMore),
                    ].indexed) ...[
                      if (i > 0) _Separator(color: _line, inset: 14),
                      Expanded(child: _Action(a.$1, a.$2, a.$3, _ink, _well)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final x = tailX;
    if (x == null) return card;
    // الذيل بنفس لون اللوحة يتصل بها (يُرسم فوق حدها)
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          left: x - 11,
          top: tailUp ? -tail + 1 : null,
          bottom: tailUp ? null : -tail + 1,
          child: CustomPaint(
            size: const Size(22, tail),
            painter: _TailPainter(color: _surface, up: tailUp),
          ),
        ),
      ],
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

class _Separator extends StatelessWidget {
  const _Separator({required this.color, this.inset = 12, this.hidden = false});

  final Color color;
  final double inset;
  final bool hidden; // بجانب الرقاقة المختارة لا فاصل

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: inset),
      child: SizedBox(
        width: 1,
        child: ColoredBox(color: hidden ? Colors.transparent : color),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color, required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // مثلث بطرف مستدير
    final path = up
        ? (Path()
            ..moveTo(0, h)
            ..quadraticBezierTo(w * 0.38, h * 0.62, w * 0.46, h * 0.16)
            ..quadraticBezierTo(w / 2, 0, w * 0.54, h * 0.16)
            ..quadraticBezierTo(w * 0.62, h * 0.62, w, h)
            ..close())
        : (Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(w * 0.38, h * 0.38, w * 0.46, h * 0.84)
            ..quadraticBezierTo(w / 2, h, w * 0.54, h * 0.84)
            ..quadraticBezierTo(w * 0.62, h * 0.38, w, 0)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color || old.up != up;
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.label,
    required this.ring,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  // لمعة خفيفة من الأعلى
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.5),
                    radius: 0.9,
                    colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap, this.ink, this.well);

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color ink;
  final Color well;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: well, shape: BoxShape.circle),
              child: AppIcon(icon, size: 21, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// زر "T" يعرض شكل النوع نفسه؛ المختار رقاقة بلون التحديد وشرطة تحتها
class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.style,
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.ink,
    required this.dark,
  });

  final MarkStyle style;
  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Color ink;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    // على الرقاقة الملونة النص داكن دائمًا (ألوان التحديد فاتحة)
    final glyphInk = selected ? const Color(0xFF2A2A2E) : ink;
    final base = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: glyphInk,
      height: 1.1,
    );

    final glyph = switch (style) {
      MarkStyle.highlight => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: selected ? null : color.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('T', style: base),
      ),
      MarkStyle.underline => Text(
        'T',
        style: base.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: selected ? glyphInk : color,
          decorationThickness: 2.5,
        ),
      ),
      MarkStyle.strike => Text(
        'T',
        style: base.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: selected ? glyphInk : color,
          decorationThickness: 2.5,
        ),
      ),
      MarkStyle.squiggly => Text(
        'T',
        style: base.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: selected ? glyphInk : color,
          decorationThickness: 2,
        ),
      ),
    };

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: dark ? 0.85 : 0.75)
                : null,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: glyph,
        ),
      ),
    );
  }
}
