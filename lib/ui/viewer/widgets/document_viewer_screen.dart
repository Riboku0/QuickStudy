import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, FilteringTextInputFormatter, HapticFeedback;
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart' show Printing;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfBitmap, PdfDocument;

import '../../../data/repositories/bookmarks/bookmark_repository.dart';
import '../../../data/repositories/reader/reader_settings_repository.dart';
import '../../../data/services/ocr_service.dart';
import '../../../domain/models/reader_settings.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/themes/app_icons.dart';
import '../../core/ui/app_icon.dart';
import 'reader_settings_sheet.dart';
import 'reader_chrome.dart';
import 'text_marks.dart';

// ---------------------------------------------------------------------------
// معلومات المستند (PDF أو صورة)
// ---------------------------------------------------------------------------

class _PdfInfo {
  final int pageCount;
  final double aspectRatio; // height / width

  const _PdfInfo(this.pageCount, this.aspectRatio);
}

// دالة عامة حتى تعمل داخل compute بدون تجميد الواجهة
_PdfInfo _readPdfInfo(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);

  try {
    final size = document.pages[0].size;
    return _PdfInfo(document.pages.count, size.height / size.width);
  } finally {
    document.dispose();
  }
}

// ---------------------------------------------------------------------------
// مصدر الصفحات: PDF (رسم عند الحاجة) أو صورة (صفحة واحدة)
// ---------------------------------------------------------------------------

abstract class _PageSource {
  Future<Uint8List?> load(int index);
  void cancel(int index);
  void dispose();
}

class _ImageSource implements _PageSource {
  _ImageSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List?> load(int index) => Future.value(bytes);

  @override
  void cancel(int index) {}

  @override
  void dispose() {}
}

class _PageRenderer implements _PageSource {
  _PageRenderer(this.bytes);

  final Uint8List bytes;

  static const double _dpi = 200;
  static const int _maxCached = 10;

  final Map<int, Uint8List> _cache = {};
  final Map<int, Future<Uint8List?>> _inFlight = {};
  final Set<int> _wanted = {};

  Future<void> _queue = Future.value();

  @override
  Future<Uint8List?> load(int index) {
    final cached = _cache.remove(index);

    if (cached != null) {
      _cache[index] = cached;
      return Future.value(cached);
    }

    _wanted.add(index);
    return _inFlight[index] ??= _enqueue(index);
  }

  @override
  void cancel(int index) => _wanted.remove(index);

  Future<Uint8List?> _enqueue(int index) {
    final result = _queue.then<Uint8List?>((_) async {
      try {
        if (!_wanted.contains(index)) return null;

        await for (final raster in Printing.raster(
          bytes,
          pages: [index],
          dpi: _dpi,
        )) {
          final png = await raster.toPng();

          _cache[index] = png;
          while (_cache.length > _maxCached) {
            _cache.remove(_cache.keys.first);
          }

          return png;
        }

        return null;
      } finally {
        _inFlight.remove(index);
        _wanted.remove(index);
      }
    });

    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  void dispose() {
    _cache.clear();
    _wanted.clear();
  }
}

// ---------------------------------------------------------------------------
// الخطوط: عربية (Google Fonts) + لاتينية
// تحتاج حزمة google_fonts وإنترنت عند أول استخدام لكل خط (ثم تُخزَّن)
// ---------------------------------------------------------------------------

class _NoteFont {
  final String id;
  final String label;
  final String? google; // اسم الخط في Google Fonts
  final String? family; // خط النظام
  final List<String> fallback;

  const _NoteFont(
    this.id,
    this.label, {
    this.google,
    this.family,
    this.fallback = const [],
  });
}

const List<_NoteFont> _fonts = [
  _NoteFont('default', 'Default'),
  // عربية
  _NoteFont('cairo', 'القاهرة', google: 'Cairo'),
  _NoteFont('tajawal', 'تجوّل', google: 'Tajawal'),
  _NoteFont('amiri', 'أميري', google: 'Amiri'),
  _NoteFont('naskh', 'نسخ', google: 'Noto Naskh Arabic'),
  _NoteFont('kufi', 'كوفي', google: 'Noto Kufi Arabic'),
  _NoteFont('reem', 'ريم كوفي', google: 'Reem Kufi'),
  _NoteFont('almarai', 'المرعي', google: 'Almarai'),
  _NoteFont('messiri', 'المسيري', google: 'El Messiri'),
  _NoteFont('lalezar', 'لالزار', google: 'Lalezar'),
  _NoteFont('ruqaa', 'رقعة', google: 'Aref Ruqaa'),
  _NoteFont('lateef', 'لطيف', google: 'Lateef'),
  _NoteFont('mada', 'مدى', google: 'Mada'),
  _NoteFont('changa', 'شانغا', google: 'Changa'),
  _NoteFont('markazi', 'مركزي', google: 'Markazi Text'),
  _NoteFont('scheherazade', 'شهرزاد', google: 'Scheherazade New'),
  _NoteFont('rakkas', 'رقّاص', google: 'Rakkas'),
  _NoteFont('katibeh', 'كاتبة', google: 'Katibeh'),
  _NoteFont('lemonada', 'ليمونادا', google: 'Lemonada'),
  _NoteFont('harmattan', 'هرمتان', google: 'Harmattan'),
  // لاتينية
  _NoteFont(
    'serif',
    'Serif',
    family: 'serif',
    fallback: ['Georgia', 'Times New Roman'],
  ),
  _NoteFont(
    'mono',
    'Mono',
    family: 'monospace',
    fallback: ['Courier New', 'Menlo'],
  ),
  _NoteFont('playfair', 'Playfair', google: 'Playfair Display'),
  _NoteFont('robotoslab', 'Roboto Slab', google: 'Roboto Slab'),
  _NoteFont('bebas', 'BEBAS', google: 'Bebas Neue'),
  _NoteFont('pacifico', 'Pacifico', google: 'Pacifico'),
];

_NoteFont _fontById(String? id) =>
    _fonts.firstWhere((f) => f.id == id, orElse: () => _fonts.first);

TextStyle _fontStyle(_NoteFont font, TextStyle base) {
  if (font.google != null) {
    try {
      return GoogleFonts.getFont(font.google!, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  if (font.family != null) {
    return base.copyWith(
      fontFamily: font.family,
      fontFamilyFallback: font.fallback.isEmpty ? null : font.fallback,
    );
  }

  return base;
}

const List<int> _palette = [
  0xFF202020, 0xFF424242, 0xFF757575, 0xFFBDBDBD, 0xFFFFFFFF, //
  0xFFD32F2F, 0xFFB71C1C, 0xFFE91E63, 0xFFEF6C00, 0xFFFFB300, //
  0xFFFFD84D, 0xFFAFB42B, 0xFF7CB342, 0xFF2E7D32, 0xFF00897B, //
  0xFF00ACC1, 0xFF29B6F6, 0xFF1565C0, 0xFF3949AB, 0xFF6A1B9A, //
  0xFF8E24AA, 0xFF6D4C41, 0xFF37474F, 0xFFFFCDD2, 0xFFFFE0B2, //
  0xFFFFF9C4, 0xFFC8E6C9, 0xFFB3E5FC, 0xFFE1BEE7, //
];

final RegExp _arabicRe = RegExp(r'[\u0600-\u06FF]');

bool _isRtl(String text) => _arabicRe.hasMatch(text);

// ---------------------------------------------------------------------------
// ملاحظة نصية فوق الصفحة
// الإحداثيات والأحجام نسبية (0..1) حتى تبقى مضبوطة مع الزوم
// ---------------------------------------------------------------------------

class _Note {
  _Note({
    required this.id,
    required this.page,
    required this.x,
    required this.y,
    required this.w,
    required this.size,
    required this.text,
    this.bg,
    this.color = 0xFF202020,
    this.h,
    this.font = 'default',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = 0,
    this.rot = 0,
    this.opacity = 1,
  });

  final String id;
  final int page;

  double x; // من عرض الصفحة (الزاوية العلوية اليسرى قبل الدوران)
  double y; // من ارتفاع الصفحة
  double w; // عرض الصندوق من عرض الصفحة
  double? h; // ارتفاع الصندوق من ارتفاع الصفحة (null = تلقائي حسب النص)
  double size; // حجم الخط من عرض الصفحة
  String text;
  int? bg; // لون الخلفية (null = شفاف)
  int color; // لون النص (ARGB)
  String font;
  bool bold;
  bool italic;
  bool underline;
  int align; // 0 تلقائي، 1 يسار، 2 وسط، 3 يمين
  double rot; // الدوران بالراديان
  double opacity;

  Map<String, dynamic> toJson() => {
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
  };

  factory _Note.fromJson(Map<String, dynamic> json) => _Note(
    id: json['id'] as String,
    page: json['page'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    size: (json['size'] as num).toDouble(),
    text: json['text'] as String,
    // توافق مع الملاحظات القديمة (cover = خلفية بيضاء)
    bg:
        (json['bg'] as int?) ??
        ((json['cover'] as bool?) == true ? 0xFFFFFFFF : null),
    color: (json['color'] as int?) ?? 0xFF202020,
    h: (json['h'] as num?)?.toDouble(),
    font: (json['font'] as String?) ?? 'default',
    bold: (json['bold'] as bool?) ?? false,
    italic: (json['italic'] as bool?) ?? false,
    underline: (json['underline'] as bool?) ?? false,
    align: (json['align'] as int?) ?? 0,
    rot: (json['rot'] as num?)?.toDouble() ?? 0,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
  );
}

TextStyle _noteTextStyle(_Note note, double fontSize) {
  final base = TextStyle(
    fontSize: fontSize,
    height: 1.4,
    color: Color(note.color),
    fontWeight: note.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: note.italic ? FontStyle.italic : FontStyle.normal,
    decoration: note.underline ? TextDecoration.underline : TextDecoration.none,
    decorationColor: Color(note.color),
  );

  return _fontStyle(_fontById(note.font), base);
}

TextAlign _alignOf(_Note note) {
  switch (note.align) {
    case 1:
      return TextAlign.left;
    case 2:
      return TextAlign.center;
    case 3:
      return TextAlign.right;
    default:
      return _isRtl(note.text) ? TextAlign.right : TextAlign.left;
  }
}

// الارتفاع التلقائي للصندوق (نسبة من ارتفاع الصفحة)
double _autoHeight(_Note note, double pw, double ph) {
  final fontSize = note.size * pw;
  final padding = fontSize * 0.15;

  final painter = TextPainter(
    // نص فارغ (بداية الكتابة) يُقاس كسطر واحد
    text: TextSpan(
      text: note.text.isEmpty ? ' ' : note.text,
      style: _noteTextStyle(note, fontSize),
    ),
    textDirection: _isRtl(note.text) ? TextDirection.rtl : TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: math.max(1.0, note.w * pw - padding * 2));

  return (painter.height + padding * 2) / ph;
}

double _noteH(_Note note, double pw, double ph) =>
    note.h ?? _autoHeight(note, pw, ph);

Offset _rotate(Offset v, double a) {
  final c = math.cos(a);
  final s = math.sin(a);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

// ---------------------------------------------------------------------------
// التصدير: دمج الملاحظات في الملف (حفظ / مشاركة)
// ---------------------------------------------------------------------------

class _ExportResult {
  final Uint8List bytes;
  final String name;
  final String mime;

  const _ExportResult(this.bytes, this.name, this.mime);
}

// يرسم الملاحظات بنفس منطق _NoteView (الأبعاد بالبكسل: pw × ph)
void _paintNotes(Canvas canvas, double pw, double ph, List<_Note> notes) {
  for (final note in notes) {
    if (note.text.trim().isEmpty) continue;

    final fontSize = note.size * pw;
    final pad = fontSize * 0.15;
    final bw = note.w * pw;
    final bh = _noteH(note, pw, ph) * ph;
    final innerW = math.max(1.0, bw - pad * 2);

    final painter = TextPainter(
      text: TextSpan(text: note.text, style: _noteTextStyle(note, fontSize)),
      textDirection: _isRtl(note.text) ? TextDirection.rtl : TextDirection.ltr,
      textAlign: _alignOf(note),
      textScaler: TextScaler.noScaling,
    )..layout(minWidth: innerW, maxWidth: innerW);

    final center = Offset(note.x * pw + bw / 2, note.y * ph + bh / 2);
    final rect = Rect.fromLTWH(0, 0, bw, bh);
    final opacity = note.opacity.clamp(0.0, 1.0).toDouble();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(note.rot);
    canvas.translate(-bw / 2, -bh / 2);

    if (opacity < 1) {
      canvas.saveLayer(
        rect.inflate(2),
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }

    canvas.clipRect(rect);

    if (note.bg != null) {
      canvas.drawRect(rect, Paint()..color = Color(note.bg!));
    }

    painter.paint(canvas, Offset(pad, pad));

    if (opacity < 1) canvas.restore();
    canvas.restore();

    painter.dispose();
  }
}

Future<Uint8List> _picturePng(ui.Picture picture, int width, int height) async {
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);

  image.dispose();
  picture.dispose();

  return data!.buffer.asUint8List();
}

// طبقة شفافة تحتوي الملاحظات فقط
Future<Uint8List> _renderOverlay(
  List<_Note> notes,
  double pw,
  double ph,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, pw, ph));

  _paintNotes(canvas, pw, ph, notes);

  return _picturePng(recorder.endRecording(), pw.round(), ph.round());
}

Future<Uint8List> _exportPdf(
  Uint8List bytes,
  Map<int, List<_Note>> notes,
  double ratio, // نسبة العرض المستخدمة في العارض (ارتفاع / عرض)
) async {
  final document = PdfDocument(inputBytes: bytes);

  try {
    for (final entry in notes.entries) {
      if (entry.key < 0 || entry.key >= document.pages.count) continue;
      if (entry.value.every((n) => n.text.trim().isEmpty)) continue;

      final page = document.pages[entry.key];
      final size = page.size;

      // نفس BoxFit.contain المستخدم في العارض
      final tileW = math.min(size.width, size.height / ratio);
      final tileH = tileW * ratio;
      final left = (size.width - tileW) / 2;
      final top = (size.height - tileH) / 2;

      final pw = math.min(tileW * 3, 2400.0);
      final ph = pw * ratio;

      final png = await _renderOverlay(entry.value, pw, ph);

      page.graphics.drawImage(
        PdfBitmap(png),
        Rect.fromLTWH(left, top, tileW, tileH),
      );
    }

    final saved = await document.save();
    return Uint8List.fromList(saved);
  } finally {
    document.dispose();
  }
}

Future<Uint8List> _exportImage(Uint8List bytes, List<_Note> notes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final w = image.width.toDouble();
  final h = image.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

  canvas.drawImage(
    image,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.high,
  );
  _paintNotes(canvas, w, h, notes);

  final png = await _picturePng(recorder.endRecording(), w.round(), h.round());

  image.dispose();
  codec.dispose();

  return png;
}

// ---------------------------------------------------------------------------
// نافذة اختيار لون (ألوان جاهزة + ألوان مخصصة HSV)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// نافذة إدخال نص: تملك الـ controller وتتخلص منه عند إزالتها فعلًا.
// (التخلص منه بعد showDialog مباشرة يُسقط التطبيق: النافذة ما زالت
//  تُرسم أثناء حركة الإغلاق وتستخدمه)
// ---------------------------------------------------------------------------

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    this.initial = '',
    this.number = false,
  });

  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String initial;
  final bool number; // رقم صفحة: سطر واحد ولوحة أرقام

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _input.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _input,
        autofocus: true,
        keyboardType: widget.number
            ? TextInputType.number
            : TextInputType.multiline,
        minLines: widget.number ? 1 : 2,
        maxLines: widget.number ? 1 : 6,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: widget.number ? (_) => _submit() : null,
        // رقم صفحة: أرقام صحيحة فقط (لا فاصلة عشرية)
        inputFormatters: widget.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

class _ColorChoice {
  final int? color; // null = بدون لون

  const _ColorChoice(this.color);
}

class _ColorDialog extends StatefulWidget {
  final String title;
  final int? initial;
  final bool allowNone;

  const _ColorDialog({
    required this.title,
    required this.initial,
    required this.allowNone,
  });

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(Color(widget.initial ?? 0xFF1A73E8));
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, max).toDouble(),
            min: 0,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _hsv = HSVColor.fromColor(Color(c))),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _slider(
              'H',
              _hsv.hue,
              360,
              (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _slider(
              'S',
              _hsv.saturation,
              1,
              (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _slider(
              'V',
              _hsv.value,
              1,
              (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.of(context).cancel),
        ),
        if (widget.allowNone)
          TextButton(
            onPressed: () => Navigator.pop(context, const _ColorChoice(null)),
            child: Text(AppStrings.of(context).none),
          ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _ColorChoice(_hsv.toColor().value)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// صفحة العرض
// ---------------------------------------------------------------------------

class DocumentViewerPage extends StatefulWidget {
  final int fileId;
  final String fileName;
  final String filePath;
  final String fileType;

  // آخر صفحة قرأها المستخدم (يفتح عليها العارض)
  final int? initialPage;

  // يُستدعى عند الفتح وعند كل تغيير صفحة: (الصفحة، عدد الصفحات)
  final void Function(int page, int pageCount)? onPageChanged;

  const DocumentViewerPage({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    this.initialPage,
    this.onPageChanged,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage>
    with SingleTickerProviderStateMixin {
  // الألوان من lib/ui/core/themes/app_theme.dart
  // العارض مصمم لخلفية فاتحة، فيبقى فاتحًا حتى في الوضع الداكن
  static const Color dark = Color(0xFF202020);
  static const Color red = Color(0xFFC62828);
  static const Color pillColor = Color(0xFF7FF0DF);

  // الهامش الجانبي حسب إعدادات القراءة
  double get _hPad => switch (_reader.settings.margin) {
    ReaderMargin.none => 0,
    ReaderMargin.standard => 12,
    ReaderMargin.wide => 32,
  };
  static const double _gap = 12;
  static const double _ov = 56; // هامش منطقة المقابض حول الصندوق

  final ValueNotifier<int> _currentPage = ValueNotifier<int>(1);
  final GlobalKey _ovKey = GlobalKey();

  bool _loading = true;
  String? _error;

  _PageSource? _source;
  int _pageCount = 0;
  int? _pendingPage; // صفحة البداية، تُطبَّق بعد معرفة حجم الشاشة

  // إعدادات القراءة (لكل الكتب)
  late final ReaderSettingsRepository _reader;
  bool _vertical = true; // الوضع المطبَّق حاليًا
  PageController? _pager; // للقراءة الأفقية
  // الزوم في القراءة الأفقية: للصفحة الحالية فقط
  final TransformationController _pagedZoom = TransformationController();
  bool _pagedZoomed = false;
  int _pointers = 0; // أصابع على الشاشة (إصبعان = زوم لا تقليب)

  // تحديد النص وتلوينه (PDF فقط)
  BookmarkRepository? _bookmarks;
  PageTextCache? _text;
  final Map<int, List<TextMark>> _marks = {};
  final GlobalKey _pagesKey =
      GlobalKey(); // منطقة الصفحات (لتحويل إحداثيات المقابض)
  Rect? _pagedRect; // مكان الصفحة على الشاشة في القراءة الأفقية
  int? _selPage;
  int _selStart = 0;
  int _selEnd = 0;
  List<PageWord>? _selWords;
  String? _selMarkId;
  MarkStyle _markStyle = MarkStyle.highlight;
  int _markColor = markColors.first;
  double _aspectRatio = 1.4142; // A4 افتراضيًا

  // حجم منطقة العرض
  double _viewWidth = 0;
  double _viewHeight = 0;

  // الزوم والتحريك (نظام مكتوب يدويًا حتى يثبت الزوم تحت الإصبع)
  double _zoom = 1.0;
  double _scrollX = 0;
  double _scrollY = 0;
  double _startZoom = 1.0;
  int _lastPointerCount = 0;
  late final AnimationController _fling = AnimationController.unbounded(
    vsync: this,
  );

  // الملاحظات
  final Map<int, List<_Note>> _notes = {};
  bool _editMode = false;
  String? _selectedId;

  // الكتابة المباشرة: النص الذي يُكتب الآن في مكانه على الصفحة
  String? _editingId;
  final TextEditingController _inlineText = TextEditingController();
  final FocusNode _inlineFocus = FocusNode();

  // حالة التصدير (حفظ / مشاركة)
  bool _exporting = false;

  // آخر إعدادات استخدمتها (تُطبَّق على النصوص الجديدة)
  int _defColor = 0xFF202020;
  double _defSize = 0.032;
  String _defFont = 'default';

  String get _type => widget.fileType.toLowerCase();
  bool get _isPdf => _type == 'pdf';
  bool get _isImage => ['png', 'jpg', 'jpeg'].contains(_type);
  double get _maxZoom => _isImage ? 5.0 : 3.0;

  @override
  void initState() {
    super.initState();
    _fling.addListener(_onFling);
    _currentPage.addListener(_reportPage);
    _reader = context.read<ReaderSettingsRepository>();
    _bookmarks = context.read<BookmarkRepository>();
    _vertical = _reader.settings.vertical;
    _reader.addListener(_onReaderChanged);
    _load();
  }

  // ------------------------- التحميل -------------------------

  Future<void> _load() async {
    try {
      final file = File(widget.filePath);

      if (!await file.exists()) {
        throw Exception('The original file could not be found.');
      }

      final bytes = await file.readAsBytes();

      if (_isPdf) {
        final info = await compute(_readPdfInfo, bytes);

        _source = _PageRenderer(bytes);
        // الصفحات الممسوحة (بلا نص) تُقرأ بالتعرف الضوئي عند الحاجة
        _text = PageTextCache(
          bytes,
          ocr: (page) async {
            final words = await OcrService.instance.pageWords(
              lectureId: widget.fileId,
              pdfBytes: bytes,
              page: page,
            );
            return [
              for (final w in words) (text: w.text, rect: w.rect, line: w.line),
            ];
          },
        );
        _pageCount = info.pageCount;
        _aspectRatio = info.aspectRatio;
      } else if (_isImage) {
        final image = await decodeImageFromList(bytes);
        _aspectRatio = image.height / image.width;
        image.dispose();

        _source = _ImageSource(bytes);
        _pageCount = 1;
      } else {
        throw Exception('Unsupported file type.');
      }

      await _loadNotes();
      await _loadMarks();

      if (!mounted) return;

      final start = widget.initialPage;
      if (start != null && start > 1 && start <= _pageCount) {
        if (_vertical) {
          _pendingPage = start;
        } else {
          _currentPage.value = start; // المستمع يسجّل التقدم
        }
      } else {
        _reportPage(); // تسجيل فتح الملف من الصفحة الأولى
      }
      if (!_vertical) {
        _pager = PageController(initialPage: _currentPage.value - 1);
      }

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ------------------------- حفظ الملاحظات -------------------------

  Future<File> _notesFile() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final directory = Directory(p.join(appDirectory.path, 'quickstudy_notes'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File(p.join(directory.path, '${widget.fileId}_notes.json'));
  }

  Future<void> _loadNotes() async {
    try {
      final file = await _notesFile();

      if (!await file.exists()) return;

      final list = jsonDecode(await file.readAsString()) as List;

      for (final item in list) {
        final note = _Note.fromJson(item as Map<String, dynamic>);
        _notes.putIfAbsent(note.page, () => []).add(note);
      }
    } catch (e) {
      debugPrint('Could not load notes: $e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final all = _notes.values
          .expand((list) => list)
          // نص قيد الكتابة وما زال فارغًا لا يُحفظ
          .where((note) => note.text.trim().isNotEmpty)
          .map((note) => note.toJson())
          .toList();

      final file = await _notesFile();
      await file.writeAsString(jsonEncode(all), flush: true);
    } catch (e) {
      _showMessage('${AppStrings.of(context).notesNotSaved}: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: red,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
  }

  // ------------------------- إضافة وتعديل الملاحظات -------------------------

  _Note? get _selectedNote {
    final id = _selectedId;
    if (id == null) return null;

    for (final list in _notes.values) {
      for (final note in list) {
        if (note.id == id) return note;
      }
    }

    return null;
  }

  // لمسة على الصفحة: كتابة مباشرة في مكانها (بدون نافذة)
  Future<void> _addNote(int page, double nx, double ny) async {
    // لمسة على مكان فارغ وفيه عنصر محدد = إنهاء الكتابة وإلغاء التحديد فقط
    if (_selectedId != null) {
      _finishEditing();
      setState(() => _selectedId = null);
      return;
    }

    const width = 0.5;

    final note = _Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: page,
      // الصندوق يتوسط مكان اللمسة
      x: (nx - width / 2).clamp(0.0, 1.0 - width).toDouble(),
      y: ny.clamp(0.0, 0.97).toDouble(),
      w: width,
      size: _defSize,
      text: '',
      color: _defColor,
      font: _defFont,
      align: 2, // النص الجديد في المنتصف
    );

    setState(() {
      _notes.putIfAbsent(page, () => []).add(note);
      _selectedId = note.id;
    });

    _startEditing(note);
  }

  void _onTapNote(_Note note) {
    if (_selectedId == note.id) {
      _startEditing(note);
    } else {
      _finishEditing();
      setState(() => _selectedId = note.id);
    }
  }

  // ---- الكتابة المباشرة على الصفحة ----

  void _startEditing(_Note note) {
    if (_editingId == note.id) return;
    _finishEditing();
    _zoomToEditing(note); // النص بحجم مريح للكتابة
    _inlineText.value = TextEditingValue(
      text: note.text,
      selection: TextSelection.collapsed(offset: note.text.length),
    );
    setState(() {
      _selectedId = note.id;
      _editingId = note.id;
    });
    // يظهر المؤشر ولوحة المفاتيح بعد بناء حقل الكتابة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingId == note.id) _inlineFocus.requestFocus();
    });
  }

  void _onInlineChanged(String value) {
    final note = _editingNote;
    if (note == null) return;
    setState(() => note.text = value);
  }

  _Note? get _editingNote {
    final id = _editingId;
    if (id == null) return null;
    for (final list in _notes.values) {
      for (final note in list) {
        if (note.id == id) return note;
      }
    }
    return null;
  }

  // إنهاء الكتابة: النص الفارغ يُحذف، وغيره يُحفظ
  void _finishEditing() {
    final note = _editingNote;
    if (_editingId == null) return;
    _editingId = null;
    _inlineFocus.unfocus();
    if (note == null) return;

    final text = note.text.trimRight();
    setState(() {
      // نرجع للتكبير الذي كان قبل الكتابة
      final before = _zoomBeforeEdit;
      _zoomBeforeEdit = null;
      if (before != null && _vertical && _viewWidth > 0) {
        _zoomAround(before, Offset(_viewWidth / 2, _viewHeight / 2));
        _clampScroll();
      }
      if (text.trim().isEmpty) {
        _notes[note.page]?.removeWhere((n) => n.id == note.id);
        if (_selectedId == note.id) _selectedId = null;
      } else {
        note.text = text;
      }
    });
    _saveNotes();
  }

  // تكبير الصفحة حول النص عند بدء الكتابة إن كان خطه صغيرًا على الشاشة
  // (حتى لا يضطر المستخدم لإخفاء لوحة المفاتيح ليكبّر ويرى ما يكتب)
  double? _zoomBeforeEdit;

  void _zoomToEditing(_Note note) {
    if (!_vertical || _viewWidth <= 0) return;
    final r = _pageRect(note.page);
    if (r == null) return;

    final shown = note.size * r.width; // حجم الخط الظاهر الآن
    if (shown <= 0 || shown >= 17) return;

    var zoom = _zoom * 22 / shown;
    // لا يصير النص أعرض من الشاشة
    final noteWidth = note.w * r.width;
    if (noteWidth > 0) {
      zoom = math.min(zoom, _zoom * (_viewWidth * 0.92) / noteWidth);
    }
    zoom = zoom.clamp(1.0, _maxZoom).toDouble();
    if (zoom <= _zoom + 0.01) return;

    _zoomBeforeEdit ??= _zoom;
    final h = _noteH(note, r.width, r.height);
    _fling.stop();
    _zoomAround(
      zoom,
      Offset(
        r.left + (note.x + note.w / 2) * r.width,
        r.top + (note.y + h / 2) * r.height,
      ),
    );
    // النص في منتصف الشاشة أفقيًا
    final r2 = _pageRect(note.page)!;
    _scrollX += r2.left + (note.x + note.w / 2) * r2.width - _viewWidth / 2;
    _clampScroll();
    _updateCurrentPage();
  }

  // سحب النص بالإصبع أثناء كتابته (مع إيقاف تمرير الصفحة)
  bool _noteDragging = false;

  void _dragEditingNote(_Note note, Offset delta) {
    _noteDragging = true;
    _moveNote(note, delta);
  }

  // تحريك النص من مقبض التحريك في الإطار
  void _moveNote(_Note note, Offset delta) {
    final pw = _pw;
    final ph = _ph;
    if (pw <= 0 || ph <= 0) return;
    setState(() {
      note.x += delta.dx / pw;
      note.y += delta.dy / ph;
      final hf = _noteH(note, pw, ph);
      note.x = note.x.clamp(-note.w / 2, 1 - note.w / 2).toDouble();
      note.y = note.y.clamp(-hf / 2, 1 - hf / 2).toDouble();
    });
  }

  // حجم الصفحة على الشاشة في الوضع الحالي (عامودي أو أفقي)
  double get _pw => _vertical ? _pageWidth : (_pagedRect?.width ?? _pageWidth);
  double get _ph =>
      _vertical ? _pageHeight : (_pagedRect?.height ?? _pageHeight);

  void _deleteNote(_Note note) {
    setState(() {
      if (_editingId == note.id) {
        _editingId = null;
        _inlineFocus.unfocus();
      }
      _notes[note.page]?.removeWhere((n) => n.id == note.id);
      if (_selectedId == note.id) _selectedId = null;
    });

    _saveNotes();
  }

  void _duplicateNote(_Note note) {
    final copy = _Note.fromJson({
      ...note.toJson(),
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'x': note.x + 0.03,
      'y': note.y + 0.02,
    });

    setState(() {
      _notes.putIfAbsent(copy.page, () => []).add(copy);
      _selectedId = copy.id;
    });

    _saveNotes();
  }

  // تعديل خصائص النص المحدد من الشريط السفلي
  void _mutate(void Function(_Note note) change, {bool save = true}) {
    final note = _selectedNote;
    if (note == null) return;

    setState(() => change(note));

    if (save) _saveNotes();
  }

  Future<void> _pickColor({
    required String title,
    required int? initial,
    required bool allowNone,
    required void Function(int? color) apply,
  }) async {
    final result = await showDialog<_ColorChoice>(
      context: context,
      builder: (_) =>
          _ColorDialog(title: title, initial: initial, allowNone: allowNone),
    );

    if (result == null) return;

    _mutate((_) => apply(result.color));
  }

  // ---- تحريك النص بإصبع واحد وتكبيره بإصبعين (على جسم النص) ----

  double _noteStartSize = 0;
  double _noteStartW = 0;
  double? _noteStartH;
  int _noteLastCount = 0;

  void _noteScaleStart(_Note note) {
    _noteStartSize = note.size;
    _noteStartW = note.w;
    _noteStartH = note.h;
    _noteLastCount = 1;

    if (_selectedId != note.id) setState(() => _selectedId = note.id);
  }

  void _noteScaleUpdate(
    _Note note,
    ScaleUpdateDetails details,
    double pageWidth,
    double pageHeight,
  ) {
    final countChanged = details.pointerCount != _noteLastCount;
    _noteLastCount = details.pointerCount;

    setState(() {
      if (details.pointerCount >= 2) {
        note.size = (_noteStartSize * details.scale)
            .clamp(0.012, 0.3)
            .toDouble();
        note.w = (_noteStartW * details.scale).clamp(0.1, 1.5).toDouble();

        final startH = _noteStartH;
        if (startH != null) {
          note.h = (startH * details.scale).clamp(0.02, 1.5).toDouble();
        }

        _defSize = note.size;
      }

      if (!countChanged) {
        note.x += details.focalPointDelta.dx / pageWidth;
        note.y += details.focalPointDelta.dy / pageHeight;
      }

      // يبقى مركز الصندوق داخل الصفحة
      final hf = _noteH(note, pageWidth, pageHeight);
      note.x = note.x.clamp(-note.w / 2, 1 - note.w / 2).toDouble();
      note.y = note.y.clamp(-hf / 2, 1 - hf / 2).toDouble();
    });
  }

  // ---- المقابض (تعمل في فضاء الصندوق المُدار) ----

  // تغيير حجم من الحواف: القيم بالبكسل المحلي (موجب = يكبر للخارج)
  void _edgeResize(_Note n, double dl, double dt, double dr, double db) {
    final pw = _pw;
    final ph = _ph;

    final hFrac = _noteH(n, pw, ph);
    final w0 = n.w * pw;
    final h0 = hFrac * ph;

    var newW = w0 + dl + dr;
    var newH = h0 + dt + db;

    final minW = 0.1 * pw;
    final minH = 0.02 * ph;

    if (newW < minW) {
      final s = (dl + dr) == 0 ? 0.0 : (minW - w0) / (dl + dr);
      dl *= s;
      dr *= s;
      newW = minW;
    }

    if (newH < minH) {
      final s = (dt + db) == 0 ? 0.0 : (minH - h0) / (dt + db);
      dt *= s;
      db *= s;
      newH = minH;
    }

    final center = Offset((n.x + n.w / 2) * pw, (n.y + hFrac / 2) * ph);
    final anchor = center + _rotate(Offset(-w0 / 2, -h0 / 2), n.rot);
    final anchor2 = anchor + _rotate(Offset(-dl, -dt), n.rot);

    setState(() {
      n.w = newW / pw;
      if (dt != 0 || db != 0) n.h = newH / ph;

      final h2 = _noteH(n, pw, ph) * ph;
      final c2 = anchor2 + _rotate(Offset(newW / 2, h2 / 2), n.rot);

      n.x = c2.dx / pw - n.w / 2;
      n.y = c2.dy / ph - h2 / ph / 2;
    });
  }

  // دوران بسحب الزر العلوي الأيمن
  double _rotPointer0 = 0;
  double _rot0 = 0;

  Offset? _overlayCenter() {
    final box = _ovKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _rotDown(PointerDownEvent e) {
    final c = _overlayCenter();
    final n = _selectedNote;
    if (c == null || n == null) return;

    _rotPointer0 = (e.position - c).direction;
    _rot0 = n.rot;
  }

  void _rotMove(PointerMoveEvent e) {
    final c = _overlayCenter();
    final n = _selectedNote;
    if (c == null || n == null) return;

    var r = _rot0 + ((e.position - c).direction - _rotPointer0);
    r = math.atan2(math.sin(r), math.cos(r));

    // التصاق خفيف بمضاعفات 45°
    const step = math.pi / 4;
    final snapped = (r / step).round() * step;
    if ((r - snapped).abs() < 0.06) r = snapped;

    setState(() => n.rot = r);
  }

  // تكبير/تصغير متناسق بسحب الزر السفلي الأيمن (الزاوية العلوية اليسرى ثابتة)
  Offset _scAnchor = Offset.zero;
  double _scStartDist = 1;
  double _scSize = 0;
  double _scW = 0;
  double? _scH;

  void _scaleDown(PointerDownEvent e) {
    final c = _overlayCenter();
    final n = _selectedNote;
    if (c == null || n == null) return;

    final pw = _pw;
    final ph = _ph;
    final hf = _noteH(n, pw, ph);

    final center = Offset((n.x + n.w / 2) * pw, (n.y + hf / 2) * ph);

    _scAnchor = center + _rotate(Offset(-n.w * pw / 2, -hf * ph / 2), n.rot);
    _scStartDist = math.max(1.0, (e.position - c).distance);
    _scSize = n.size;
    _scW = n.w;
    _scH = n.h;
  }

  void _scaleMove(PointerMoveEvent e) {
    final c = _overlayCenter();
    final n = _selectedNote;
    if (c == null || n == null) return;

    final f = ((e.position - c).distance / _scStartDist)
        .clamp(0.2, 8.0)
        .toDouble();

    final pw = _pw;
    final ph = _ph;

    setState(() {
      n.size = (_scSize * f).clamp(0.012, 0.3).toDouble();
      n.w = (_scW * f).clamp(0.1, 1.5).toDouble();

      final startH = _scH;
      if (startH != null) n.h = (startH * f).clamp(0.02, 1.5).toDouble();

      _defSize = n.size;

      final h2 = _noteH(n, pw, ph) * ph;
      final c2 = _scAnchor + _rotate(Offset(n.w * pw / 2, h2 / 2), n.rot);

      n.x = c2.dx / pw - n.w / 2;
      n.y = c2.dy / ph - h2 / ph / 2;
    });
  }

  // ------------------------- الحفظ والمشاركة -------------------------

  void _showInfo(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: dark,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
  }

  Future<_ExportResult> _buildExport() async {
    final original = await File(widget.filePath).readAsBytes();

    final allNotes = _notes.values
        .expand((list) => list)
        .where((n) => n.text.trim().isNotEmpty)
        .toList();

    final base = p.basenameWithoutExtension(widget.fileName);
    final ext = p.extension(widget.filePath).toLowerCase(); // مع النقطة

    // لا توجد ملاحظات: نسخة طبق الأصل
    if (allNotes.isEmpty) {
      final mime = _isPdf
          ? 'application/pdf'
          : (ext == '.png' ? 'image/png' : 'image/jpeg');

      return _ExportResult(original, '$base$ext', mime);
    }

    // التأكد من تحميل خطوط Google قبل الرسم
    try {
      for (final n in allNotes) {
        _noteTextStyle(n, 12);
      }
      await GoogleFonts.pendingFonts();
    } catch (_) {}

    if (_isPdf) {
      final bytes = await _exportPdf(original, _notes, _aspectRatio);
      return _ExportResult(bytes, '${base}_notes.pdf', 'application/pdf');
    }

    final bytes = await _exportImage(original, allNotes);
    return _ExportResult(bytes, '${base}_notes.png', 'image/png');
  }

  Future<void> _withExport(
    Future<void> Function(_ExportResult r) action,
  ) async {
    if (_exporting) return;

    setState(() {
      _exporting = true;
      _selectedId = null;
    });

    try {
      final result = await _buildExport();
      await action(result);
    } catch (e) {
      _showMessage('${AppStrings.of(context).exportFailed}: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveCopy() {
    return _withExport((r) async {
      // file_picker 11+ : الدوال أصبحت static (لا يوجد FilePicker.platform)
      final path = await FilePicker.saveFile(
        dialogTitle: AppStrings.of(context).saveCopy,
        fileName: r.name,
        bytes: r.bytes,
      );

      if (path == null) return; // أُلغي

      _showInfo(AppStrings.of(context).savedSuccessfully);
    });
  }

  Future<void> _shareCopy() {
    // الحصول على المقاس قبل أي await (مطلوب لنافذة المشاركة على iPad)
    final screen = MediaQuery.of(context).size;
    final origin = Rect.fromLTWH(screen.width - 56, 0, 56, 56);

    return _withExport((r) async {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, r.name));
      await file.writeAsBytes(r.bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: r.mime, name: r.name)],
          subject: widget.fileName,
          sharePositionOrigin: origin,
        ),
      );
    });
  }

  // ------------------------- الأبعاد -------------------------

  double get _pageWidth => (_viewWidth - _hPad * 2) * _zoom;
  double get _pageHeight => _pageWidth * _aspectRatio;
  double get _extent => _pageHeight + _gap * _zoom;
  double get _contentHeight => _extent * _pageCount;
  double get _maxX => math.max(0.0, _viewWidth * _zoom - _viewWidth);
  double get _maxY => math.max(0.0, _contentHeight - _viewHeight);

  // توسيط عمودي عندما يكون المحتوى (مثل صورة) أقصر من الشاشة
  double get _offsetY {
    if (_contentHeight > _viewHeight) return 0;
    return (_viewHeight - (_contentHeight - _gap * _zoom)) / 2;
  }

  void _clampScroll() {
    _scrollX = _scrollX.clamp(0.0, _maxX).toDouble();
    _scrollY = _scrollY.clamp(0.0, _maxY).toDouble();
  }

  // تغيّر إعداد من لوحة القراءة: نعيد البناء، ونحافظ على الصفحة عند تبديل الاتجاه
  void _onReaderChanged() {
    if (!mounted) return;
    final vertical = _reader.settings.vertical;

    if (vertical != _vertical && !_loading && _error == null) {
      final page = _currentPage.value;
      _selPage = null;
      _selWords = null;
      _selMarkId = null;
      _fling.stop();
      if (vertical) {
        _pager?.dispose();
        _pager = null;
        _zoom = 1.0;
        _scrollX = 0;
        _pendingPage = page; // يُطبَّق بعد معرفة حجم الشاشة
      } else {
        _finishEditing(); // يحفظ ما كُتب قبل تغيير الاتجاه
        _selectedId = null;
        _pager = PageController(initialPage: page - 1);
      }
    }
    _vertical = vertical;
    setState(() {});
  }

  void _openReaderSettings() {
    _clearSelection();
    ReaderSettingsSheet.show(context, _reader);
  }

  // ------------------------- العلامات المرجعية -------------------------

  Future<void> _togglePageBookmark() async {
    final bookmarks = _bookmarks;
    if (bookmarks == null) return;
    final s = AppStrings.of(context);
    final added = await bookmarks.togglePage(widget.fileId, _currentPage.value);
    _showInfo(added ? s.bookmarkAdded : s.bookmarkRemoved);
  }

  // من قائمة التحديد: علامة بالنص المحدد
  Future<void> _bookmarkSelection() async {
    final bookmarks = _bookmarks;
    final page = _selPage;
    final text = _selectionText;
    if (bookmarks == null || page == null || text.isEmpty) return;
    final s = AppStrings.of(context);
    await bookmarks.addText(
      widget.fileId,
      page + 1,
      text,
      color: _selectedMark?.color,
    );
    _showInfo(s.bookmarkAdded);
    _clearSelection();
  }

  // ------------------------- تحديد النص: الحفظ -------------------------

  Future<File> _marksFile() async {
    final notes = await _notesFile(); // نفس المجلد
    return File(p.join(notes.parent.path, '${widget.fileId}_marks.json'));
  }

  Future<void> _loadMarks() async {
    try {
      final file = await _marksFile();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      for (final item in list) {
        final mark = TextMark.fromJson(item as Map<String, dynamic>);
        _marks.putIfAbsent(mark.page, () => []).add(mark);
      }
    } catch (e) {
      debugPrint('Could not load marks: $e');
    }
  }

  Future<void> _saveMarks() async {
    try {
      final all = _marks.values
          .expand((l) => l)
          .map((m) => m.toJson())
          .toList();
      final file = await _marksFile();
      await file.writeAsString(jsonEncode(all), flush: true);
    } catch (e) {
      _showMessage('${AppStrings.of(context).notesNotSaved}: $e');
    }
  }

  // ------------------------- تحديد النص: المواضع -------------------------

  // مكان الصفحة داخل منطقة الصفحات (null = غير ظاهرة)
  Rect? _pageRect(int page) {
    if (_vertical) {
      return Rect.fromLTWH(
        _hPad * _zoom - _scrollX,
        page * _extent - _scrollY + _offsetY,
        _pageWidth,
        _pageHeight,
      );
    }
    // الأفقي: مكان الصفحة بعد الزوم والتحريك (InteractiveViewer)
    final paged = _pagedRect;
    if (paged == null || page != _currentPage.value - 1) return null;
    return MatrixUtils.transformRect(_pagedZoom.value, paged);
  }

  // أي صفحة تحت الإصبع، وأين داخلها (نسبة 0..1)
  (int, Offset)? _hitPage(Offset local) {
    if (_vertical) {
      if (_extent <= 0) return null;
      final i = ((local.dy + _scrollY - _offsetY) / _extent).floor();
      if (i < 0 || i >= _pageCount) return null;
      final r = _pageRect(i)!;
      if (!r.contains(local)) return null;
      return (
        i,
        Offset((local.dx - r.left) / r.width, (local.dy - r.top) / r.height),
      );
    }
    // الأفقي: المستطيل بعد الزوم، فالموضع صحيح والصفحة مكبرة أيضًا
    final i = _currentPage.value - 1;
    final r = _pageRect(i);
    if (r == null || !r.contains(local)) return null;
    return (
      i,
      Offset((local.dx - r.left) / r.width, (local.dy - r.top) / r.height),
    );
  }

  TextMark? _markAt(int page, Offset p) {
    final list = _marks[page];
    if (list == null) return null;
    for (final m in list.reversed) {
      if (m.contains(p)) return m;
    }
    return null;
  }

  TextMark? get _selectedMark {
    final id = _selMarkId;
    final page = _selPage;
    if (id == null || page == null) return null;
    for (final m in _marks[page] ?? const <TextMark>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Rect>? get _selectionRects {
    final words = _selWords;
    if (words != null && words.isNotEmpty)
      return rectsFor(words, _selStart, _selEnd);
    return _selectedMark?.rects;
  }

  String get _selectionText {
    final words = _selWords;
    if (words != null && words.isNotEmpty)
      return textFor(words, _selStart, _selEnd);
    return _selectedMark?.text ?? '';
  }

  // ------------------------- تحديد النص: اللمس -------------------------

  Future<void> _onLongPress(Offset local) async {
    final text = _text;
    if (_editMode || text == null) return;
    final hit = _hitPage(local);
    if (hit == null) return;
    final (page, point) = hit;

    // ضغطة مطولة على تحديد موجود = اختياره
    final existing = _markAt(page, point);
    if (existing != null) {
      _selectMark(existing);
      return;
    }

    // الصفحة الممسوحة تحتاج ثواني للتعرف عليها أول مرة: رسالة إن تأخرت
    final s = AppStrings.of(context);
    var waiting = false;
    final notice = text.isReady(page)
        ? null
        : Timer(const Duration(milliseconds: 600), () {
            waiting = true;
            _showInfo(s.recognizingPage);
          });
    final words = await text.words(page);
    notice?.cancel();
    if (!mounted) return;
    if (waiting) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (words.isEmpty) {
      _showInfo(AppStrings.of(context).noSelectableText);
      return;
    }
    final index = wordAt(words, point, exact: true);
    if (index == null) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selPage = page;
      _selWords = words;
      _selStart = index;
      _selEnd = index;
      _selMarkId = null;
    });
  }

  // نقطة الملاحظة (بجانب التحديد) تحت الإصبع؟ نفس حساب الرسم في MarksPainter
  TextMark? _noteDotAt(Offset local) {
    const touch = 24.0; // نصف قطر منطقة اللمس حول النقطة الصغيرة
    for (final entry in _marks.entries) {
      final r = _pageRect(entry.key);
      if (r == null) continue;
      for (final mark in entry.value) {
        if ((mark.note ?? '').isEmpty || mark.rects.isEmpty) continue;
        final last = mark.rects.last;
        final top = r.top + last.top * r.height;
        final right = r.left + last.right * r.width;
        final radius = math.max(3.5, last.height * r.height * 0.18);
        if ((local - Offset(right + radius, top)).distance <= touch)
          return mark;
      }
    }
    return null;
  }

  void _onTapPages(Offset local) {
    if (_editMode) return;
    // لمسة على نقطة الملاحظة: تعديل الملاحظة مباشرة
    final dot = _noteDotAt(local);
    if (dot != null) {
      _selectMark(dot);
      _editMarkNote();
      return;
    }
    if (_selPage != null) {
      _clearSelection();
      return;
    }
    final hit = _hitPage(local);
    if (hit == null) return;
    final mark = _markAt(hit.$1, hit.$2);
    if (mark != null) _selectMark(mark);
  }

  void _selectMark(TextMark mark) {
    HapticFeedback.selectionClick();
    setState(() {
      _selPage = mark.page;
      _selMarkId = mark.id;
      _selStart = mark.start;
      _selEnd = mark.end;
      _selWords = null;
      _markStyle = mark.style;
      _markColor = mark.color;
    });
    // الكلمات تلزم للمقابض فقط، فتُحمَّل بعد الظهور
    _text?.words(mark.page).then((words) {
      if (!mounted || _selMarkId != mark.id || words.isEmpty) return;
      setState(() => _selWords = words);
    });
  }

  void _clearSelection() {
    if (_selPage == null) return;
    setState(() {
      _selPage = null;
      _selWords = null;
      _selMarkId = null;
    });
  }

  // سحب مقبض البداية أو النهاية
  void _dragHandle(bool start, Offset global) {
    final words = _selWords;
    final page = _selPage;
    final box = _pagesKey.currentContext?.findRenderObject() as RenderBox?;
    if (words == null || page == null || box == null) return;
    final r = _pageRect(page);
    if (r == null) return;

    final local = box.globalToLocal(global);
    // الإصبع فوق المقبض: نبحث قليلًا فوقه حيث النص
    final p = Offset(
      (local.dx - r.left) / r.width,
      (local.dy - SelectionHandle.size - r.top) / r.height,
    );
    final index = wordAt(words, p);
    if (index == null) return;

    setState(() {
      if (start) {
        _selStart = math.min(index, _selEnd);
      } else {
        _selEnd = math.max(index, _selStart);
      }
      final mark = _selectedMark;
      if (mark != null) {
        mark.start = _selStart;
        mark.end = _selEnd;
        mark.rects = rectsFor(words, _selStart, _selEnd);
        mark.text = textFor(words, _selStart, _selEnd);
      }
    });
  }

  // ------------------------- تحديد النص: الإجراءات -------------------------

  // تطبيق نوع أو لون: ينشئ تحديدًا محفوظًا أو يعدّل الموجود
  TextMark? _applyMark({MarkStyle? style, int? color}) {
    final page = _selPage;
    if (page == null) return null;
    if (style != null) _markStyle = style;
    if (color != null) _markColor = color;

    var mark = _selectedMark;
    if (mark != null) {
      mark.style = _markStyle;
      mark.color = _markColor;
    } else {
      final words = _selWords;
      if (words == null || words.isEmpty) return null;
      mark = TextMark(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: page,
        start: math.min(_selStart, _selEnd),
        end: math.max(_selStart, _selEnd),
        style: _markStyle,
        color: _markColor,
        text: textFor(words, _selStart, _selEnd),
        rects: rectsFor(words, _selStart, _selEnd),
      );
      _marks.putIfAbsent(page, () => []).add(mark);
      _selMarkId = mark.id;
    }
    setState(() {});
    _saveMarks();
    return mark;
  }

  void _deleteMark() {
    final mark = _selectedMark;
    if (mark == null) return;
    _marks[mark.page]?.removeWhere((m) => m.id == mark.id);
    _clearSelection();
    _saveMarks();
  }

  Future<void> _copySelection() async {
    final text = _selectionText;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showInfo(AppStrings.of(context).copied);
    _clearSelection();
  }

  // "المزيد": ترجمة النص المحدد في DeepL أو ChatGPT أو Google، أو مشاركته.
  // تفتح التطبيق إن كان مثبتًا، وإلا الموقع، والنص جاهز فيه (بلا مفاتيح API).
  Future<void> _showMoreSheet() async {
    final text = _selectionText;
    if (text.isEmpty) return;
    final s = AppStrings.of(context);
    final c = _chrome;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        Widget item(String id, IconData icon, String label) => ListTile(
          leading: Icon(icon, color: c.ink),
          title: Text(
            label,
            style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
          ),
          minTileHeight: 52,
          onTap: () => Navigator.pop(sheetContext, id),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item('deepl', Icons.translate, s.translateDeepL),
                item('chatgpt', Icons.auto_awesome_outlined, s.askChatGpt),
                item('google', Icons.g_translate, s.translateGoogle),
                Divider(height: 1, color: c.line),
                item('share', Icons.share_outlined, s.share),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    if (choice == 'share') {
      await _shareSelection();
      return;
    }

    // روابط طويلة جدًا ترفضها بعض التطبيقات
    final clipped = text.length > 1500 ? text.substring(0, 1500) : text;
    final q = Uri.encodeComponent(clipped);
    // للعربية (أي نص بحروف عربية) الترجمة إلى الإنجليزية، ولغيرها إلى العربية
    final target = _isRtl(clipped) ? 'en' : 'ar';
    final url = switch (choice) {
      'deepl' => 'https://www.deepl.com/translator#auto/$target/$q',
      'chatgpt' =>
        'https://chatgpt.com/?q=${Uri.encodeComponent(s.chatGptPrompt(clipped))}',
      _ =>
        'https://translate.google.com/?sl=auto&tl=$target&text=$q&op=translate',
    };

    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened && mounted) _showInfo(s.openAppFailed);
  }

  Future<void> _shareSelection() async {
    final text = _selectionText;
    if (text.isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _editMarkNote() async {
    final s = AppStrings.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: s.markNoteTitle,
        confirmLabel: s.saveNote,
        cancelLabel: s.cancel,
        initial: _selectedMark?.note ?? '',
      ),
    );
    if (result == null || !mounted) return;

    // الملاحظة تحتاج تحديدًا محفوظًا
    final mark = _applyMark();
    if (mark == null) return;
    setState(() => mark.note = result.trim().isEmpty ? null : result.trim());
    _saveMarks();
  }

  // المقبضان + القائمة فوق الصفحات
  List<Widget> _buildSelectionOverlay(BoxConstraints area) {
    final page = _selPage;
    final rects = _selectionRects;
    if (page == null || rects == null || rects.isEmpty) return const [];
    final r = _pageRect(page);
    if (r == null) return const [];

    Offset toScreen(Offset n) =>
        Offset(r.left + n.dx * r.width, r.top + n.dy * r.height);

    final first = rects.first;
    final last = rects.last;
    final words = _selWords;
    final rtl =
        words != null &&
        words.isNotEmpty &&
        words[math.min(_selStart, words.length - 1)].rtl;

    final startPoint = toScreen(
      Offset(rtl ? first.right : first.left, first.bottom),
    );
    final endPoint = toScreen(
      Offset(rtl ? last.left : last.right, last.bottom),
    );

    const h = SelectionHandle.size;
    final s = AppStrings.of(context);
    final mark = _selectedMark;

    // القائمة فوق التحديد إن وُجد مكان، وإلا تحته
    final top = toScreen(first.topLeft).dy;
    final bottom = toScreen(last.bottomRight).dy;
    final menuWidth = math.min(360.0, area.maxWidth - 24);
    final menuLeft = ((area.maxWidth - menuWidth) / 2).clamp(
      12.0,
      area.maxWidth,
    );
    final menuTop = top - SelectionMenu.height - 14 >= 8
        ? top - SelectionMenu.height - 14
        : math.min(bottom + h + 10, area.maxHeight - SelectionMenu.height - 8);

    Widget handle(bool start, Offset at) => Positioned(
      left: at.dx - (start != rtl ? h : 0),
      top: at.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _dragHandle(start, d.globalPosition),
        onPanEnd: (_) {
          if (_selectedMark != null) _saveMarks();
        },
        child: Transform.flip(
          flipX: start != rtl,
          child: const SelectionHandle(),
        ),
      ),
    );

    return [
      if (words != null) handle(true, startPoint),
      if (words != null) handle(false, endPoint),
      Positioned(
        left: menuLeft,
        top: menuTop.clamp(
          8.0,
          math.max(8.0, area.maxHeight - SelectionMenu.height),
        ),
        width: menuWidth,
        child: SelectionMenu(
          style: _markStyle,
          color: _markColor,
          hasMark: mark != null,
          note: mark?.note,
          labels: SelectionLabels(
            styleNames: s.markStyles,
            colorNames: s.markColors,
            delete: s.removeMark,
            copy: s.copyText,
            note: s.markNote,
            share: s.share,
            bookmark: s.bookmarkAction,
            more: s.more,
          ),
          onStyle: (v) => _applyMark(style: v),
          onColor: (v) => _applyMark(color: v),
          onDelete: _deleteMark,
          onCopy: _copySelection,
          onNote: _editMarkNote,
          onShare: _shareSelection,
          onBookmark: _bookmarkSelection,
          onMore: _showMoreSheet,
          dark: _paperIsDark,
          surface: _chrome.surface,
          accent: _chrome.strong,
        ),
      ),
    ];
  }

  void _reportPage() {
    if (_pageCount > 0)
      widget.onPageChanged?.call(_currentPage.value, _pageCount);
    _schedulePrefetch();
  }

  // تجهيز نص الصفحة الحالية والصفحتين التاليتين في الخلفية بعد توقف التمرير،
  // حتى يكون التحديد فوريًا في الصفحات الممسوحة (بدل رسالة "جارٍ قراءة النص")
  Timer? _prefetchTimer;

  void _schedulePrefetch() {
    final text = _text;
    if (text == null) return;
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final current = _currentPage.value - 1;
      for (var i = current; i <= current + 2 && i < _pageCount; i++) {
        text.prefetch(i);
      }
    });
  }

  void _updateCurrentPage() {
    if (_extent <= 0 || _pageCount == 0) return;

    final page = ((_scrollY + _viewHeight / 2) / _extent).floor() + 1;
    _currentPage.value = page.clamp(1, _pageCount).toInt();
  }

  // ------------------------- التحريك والزوم -------------------------

  // تكبير/تصغير بحيث تبقى نقطة (focal) ثابتة في مكانها على الشاشة
  void _zoomAround(double newZoom, Offset focal) {
    final z = newZoom.clamp(1.0, _maxZoom).toDouble();
    final ratio = z / _zoom;

    _zoom = z;
    _scrollX = (_scrollX + focal.dx) * ratio - focal.dx;
    _scrollY = (_scrollY + focal.dy) * ratio - focal.dy;
  }

  void _zoomByButton(double delta) {
    setState(() {
      _zoomAround(_zoom + delta, Offset(_viewWidth / 2, _viewHeight / 2));
      _clampScroll();
    });
    _updateCurrentPage();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _noteDragging = false;
    _fling.stop();
    _startZoom = _zoom;
    _lastPointerCount = details.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_noteDragging) return; // الإصبع يحرك نصًا لا الصفحة
    final pointerCountChanged = details.pointerCount != _lastPointerCount;
    _lastPointerCount = details.pointerCount;

    setState(() {
      _zoomAround(_startZoom * details.scale, details.localFocalPoint);

      // تحريك المحتوى مع الأصابع (نتجاهل القفزة عند تغيّر عدد الأصابع)
      if (!pointerCountChanged) {
        _scrollX -= details.focalPointDelta.dx;
        _scrollY -= details.focalPointDelta.dy;
      }

      _clampScroll();
    });

    _updateCurrentPage();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_noteDragging) return;
    if (details.pointerCount > 0) return;

    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity.abs() < 80) return;

    _fling.animateWith(
      ClampingScrollSimulation(position: _scrollY, velocity: -velocity),
    );
  }

  void _onFling() {
    setState(() {
      _scrollY = _fling.value.clamp(0.0, _maxY).toDouble();
    });
    _updateCurrentPage();
  }

  Future<void> _goToPage() async {
    final s = AppStrings.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: s.goToPageRange(_pageCount),
        confirmLabel: s.go,
        cancelLabel: s.cancel,
        number: true,
      ),
    );

    final page = int.tryParse(value?.trim() ?? '');
    if (page == null) return;

    final target = page.clamp(1, _pageCount).toInt();

    final pager = _pager;
    if (!_vertical && pager != null) {
      pager.jumpToPage(target - 1);
      return;
    }

    _fling.stop();

    setState(() {
      _scrollY = (target - 1) * _extent;
      _clampScroll();
    });

    _updateCurrentPage();
  }

  @override
  void dispose() {
    _fling.removeListener(_onFling);
    _currentPage.removeListener(_reportPage);
    _reader.removeListener(_onReaderChanged);
    _inlineText.dispose();
    _pagedZoom.dispose();
    _prefetchTimer?.cancel();
    _inlineFocus.dispose();
    _pager?.dispose();
    _fling.dispose();
    _currentPage.dispose();
    _source?.dispose();
    super.dispose();
  }

  // ------------------------- الواجهة -------------------------

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _error == null;

    // ما حول الصفحة بنفس لون الورق (موحّد)، والشريط بلون الحبر
    final bg = _paper;
    final onBg = _ink;

    // زر الرجوع في الهاتف: يُنهي الكتابة أو يلغي التحديد أولًا، ثم يخرج من الكتاب
    final busy = _editMode || _selPage != null;

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _finishEditing(); // يحفظ ما كُتب
        setState(() {
          _editMode = false;
          _selectedId = null;
          _selPage = null;
          _selWords = null;
          _selMarkId = null;
        });
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: onBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (ready) ...[
              if (_pageCount > 1)
                // رقم الصفحة نفسه زر "اذهب إلى صفحة" (يوفّر مكانًا لزر العلامة)
                ValueListenableBuilder<int>(
                  valueListenable: _currentPage,
                  builder: (_, page, _) => Tooltip(
                    message: AppStrings.of(context).goToPage,
                    child: InkWell(
                      onTap: _goToPage,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '$page / $_pageCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // علامة مرجعية للصفحة الحالية (ممتلئة إن كانت محفوظة)
              if (_bookmarks != null)
                ListenableBuilder(
                  listenable: Listenable.merge([_bookmarks, _currentPage]),
                  builder: (context, _) {
                    final saved =
                        _bookmarks!.pageBookmark(
                          widget.fileId,
                          _currentPage.value,
                        ) !=
                        null;
                    final s = AppStrings.of(context);
                    return IconButton(
                      tooltip: saved ? s.removeBookmark : s.addBookmark,
                      onPressed: _togglePageBookmark,
                      icon: AppIcon(
                        saved ? AppIcons.bookmarkSaved : AppIcons.bookmark,
                        size: 23,
                        strokeWidth: 1.9,
                      ),
                    );
                  },
                ),
              IconButton(
                tooltip: AppStrings.of(context).readerSettings,
                onPressed: _openReaderSettings,
                icon: const Icon(Icons.tune),
              ),
              // القلم: الكتابة على الصفحة في الوضعين
              IconButton(
                tooltip: _editMode
                    ? AppStrings.of(context).finishEditing
                    : AppStrings.of(context).addEditText,
                onPressed: () {
                  _finishEditing(); // يحفظ ما كُتب قبل الخروج
                  _resetPagedZoom(); // الكتابة على المقاس الطبيعي
                  setState(() {
                    _editMode = !_editMode;
                    _selectedId = null;
                    // لا تحديد نص أثناء الكتابة على الصفحة
                    _selPage = null;
                    _selWords = null;
                    _selMarkId = null;
                  });
                },
                icon: AppIcon(
                  _editMode ? AppIcons.correct : AppIcons.pen,
                  size: 24,
                  strokeWidth: 1.9,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppStrings.of(context).saveShare,
                enabled: !_exporting,
                icon: const Icon(Icons.ios_share),
                onSelected: (value) =>
                    value == 'save' ? _saveCopy() : _shareCopy(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.save_alt, size: 20),
                        SizedBox(width: 12),
                        Text(AppStrings.of(context).saveCopy),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 20),
                        SizedBox(width: 12),
                        Text(AppStrings.of(context).share),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _buildBody(),
      ),
    );
  }

  Widget _buildError() {
    final message = (_error ?? '').length > 300
        ? '${_error!.substring(0, 300)}...'
        : (_error ?? '');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: red, size: 48),
            const SizedBox(height: 16),
            Text(
              AppStrings.of(context).couldNotOpen,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.of(context).tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, area) => Stack(
              key: _pagesKey,
              children: [
                _vertical ? _buildPages() : _buildPaged(),
                // السطوع: طبقة سوداء شفافة لا تلتقط اللمس
                if (_reader.settings.brightness < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: (1 - _reader.settings.brightness) * 0.85,
                        ),
                      ),
                    ),
                  ),
                // أزرار الزوم في الوضعين
                Positioned(
                  right: 12,
                  // فوق شريط التنقل في الهاتف
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: null,
                        backgroundColor: _chrome.fab,
                        foregroundColor: _chrome.onFab,
                        onPressed: () =>
                            _vertical ? _zoomByButton(0.5) : _zoomPaged(0.5),
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: null,
                        backgroundColor: _chrome.fab,
                        foregroundColor: _chrome.onFab,
                        onPressed: () =>
                            _vertical ? _zoomByButton(-0.5) : _zoomPaged(-0.5),
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
                // تحديد النص: المقبضان والقائمة
                ..._buildSelectionOverlay(area),
                if (_exporting)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_editMode) _buildToolbar(),
      ],
    );
  }

  // ------------------------- الشريط السفلي -------------------------

  // ألوان واجهة القراءة تتبع الليلي والنهاري
  ReaderChrome get _chrome => ReaderChrome(dark: _paperIsDark, paper: _paper);

  // ثيم لشريط القلم: الأيقونات والنصوص والشرائح بألوان الليلي عند الحاجة
  ThemeData _chromeTheme(BuildContext context) {
    final base = Theme.of(context);
    final c = _chrome;
    // نهارًا وليلًا: لون الورق ولون الثيم بدل الأبيض والأزرق الافتراضيين
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: c.strong,
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.ink,
      ),
      iconTheme: IconThemeData(color: c.ink),
      textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.chip,
        labelStyle: TextStyle(color: c.ink),
      ),
    );
  }

  Widget _buildToolbar() {
    final note = _selectedNote;

    return Theme(
      data: _chromeTheme(context),
      child: Material(
        color: _chrome.surface,
        elevation: 12,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: note == null
                ? _buildToolbarHint()
                : _buildToolbarControls(note),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarHint() {
    return Row(
      children: [
        Icon(Icons.touch_app_outlined, size: 20, color: _chrome.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.of(context).tapToAddText,
            style: TextStyle(fontSize: 12, color: _chrome.muted),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _editMode = false),
          child: Text(AppStrings.of(context).done),
        ),
      ],
    );
  }

  Widget _toggle(IconData icon, bool on, VoidCallback onTap, String tip) {
    return IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: on ? _chrome.strong.withValues(alpha: 0.14) : null,
        foregroundColor: on ? _chrome.strong : _chrome.ink,
      ),
      icon: Icon(icon, size: 22),
    );
  }

  Widget _sliderRow(
    IconData icon,
    String tip,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        Tooltip(
          message: tip,
          child: Icon(icon, size: 18, color: _chrome.muted),
        ),
        Expanded(
          // شريط رفيع بألوان التطبيق (أسود + خلفية فاتحة)
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: _chrome.ink,
              inactiveTrackColor: _chrome.line,
              thumbColor: _chrome.ink,
              overlayColor: const Color(0x1AFFD84D),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              semanticFormatterCallback: (v) => tip,
              onChanged: onChanged,
              onChangeEnd: (_) => _saveNotes(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarControls(_Note note) {
    final maxHeight = MediaQuery.of(context).size.height * 0.42;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الخطوط
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fonts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final font = _fonts[i];
                  final selected = note.font == font.id;

                  return ChoiceChip(
                    label: Text(
                      font.label,
                      style: _fontStyle(font, const TextStyle(fontSize: 15)),
                    ),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: _chrome.strong.withValues(alpha: 0.16),
                    side: BorderSide(
                      color: selected ? _chrome.strong : _chrome.line,
                    ),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      _defFont = font.id;
                      _mutate((n) => n.font = font.id);
                    },
                  );
                },
              ),
            ),

            // أدوات التنسيق
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _toggle(
                    Icons.format_bold,
                    note.bold,
                    () => _mutate((n) => n.bold = !n.bold),
                    AppStrings.of(context).bold,
                  ),
                  _toggle(
                    Icons.format_italic,
                    note.italic,
                    () => _mutate((n) => n.italic = !n.italic),
                    AppStrings.of(context).italic,
                  ),
                  _toggle(
                    Icons.format_underlined,
                    note.underline,
                    () => _mutate((n) => n.underline = !n.underline),
                    AppStrings.of(context).underline,
                  ),
                  _toggle(
                    Icons.format_align_left,
                    note.align == 1,
                    () => _mutate((n) => n.align = n.align == 1 ? 0 : 1),
                    AppStrings.of(context).alignLeft,
                  ),
                  _toggle(
                    Icons.format_align_center,
                    note.align == 2,
                    () => _mutate((n) => n.align = n.align == 2 ? 0 : 2),
                    AppStrings.of(context).alignCenter,
                  ),
                  _toggle(
                    Icons.format_align_right,
                    note.align == 3,
                    () => _mutate((n) => n.align = n.align == 3 ? 0 : 3),
                    AppStrings.of(context).alignRight,
                  ),
                  _toggle(
                    Icons.format_color_fill,
                    note.bg != null,
                    () => _pickColor(
                      title: AppStrings.of(context).coverBackgroundTitle,
                      initial: note.bg,
                      allowNone: true,
                      apply: (c) => note.bg = c,
                    ),
                    AppStrings.of(context).coverBackground,
                  ),
                  IconButton(
                    tooltip: AppStrings.of(context).editText,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _startEditing(note),
                    icon: const Icon(Icons.text_fields, size: 22),
                  ),
                  IconButton(
                    tooltip: AppStrings.of(context).duplicate,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _duplicateNote(note),
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: AppStrings.of(context).delete,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteNote(note),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 22,
                      color: red,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedId = null),
                    child: Text(AppStrings.of(context).done),
                  ),
                ],
              ),
            ),

            // الألوان
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _palette.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  // آخر عنصر: لون مخصص
                  if (i == _palette.length) {
                    return GestureDetector(
                      onTap: () => _pickColor(
                        title: AppStrings.of(context).textColor,
                        initial: note.color,
                        allowNone: false,
                        apply: (c) {
                          if (c != null) {
                            note.color = c;
                            _defColor = c;
                          }
                        },
                      ),
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0000FF),
                              Color(0xFFFF00FF),
                              Color(0xFFFF0000),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  final c = _palette[i];
                  final selected = note.color == c;

                  return GestureDetector(
                    onTap: () {
                      _defColor = c;
                      _mutate((n) => n.color = c);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? _chrome.strong : _chrome.line,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: Color(c).computeLuminance() > 0.6
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),

            // الحجم / الشفافية / الدوران
            _sliderRow(
              Icons.format_size,
              AppStrings.of(context).size,
              note.size,
              0.012,
              0.3,
              (v) {
                _defSize = v;
                _mutate((n) => n.size = v, save: false);
              },
            ),
            _sliderRow(
              Icons.opacity,
              AppStrings.of(context).opacity,
              note.opacity,
              0.1,
              1.0,
              (v) => _mutate((n) => n.opacity = v, save: false),
            ),
            _sliderRow(
              Icons.rotate_right,
              AppStrings.of(context).rotation,
              note.rot,
              -math.pi,
              math.pi,
              (v) => _mutate((n) => n.rot = v, save: false),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- ألوان الصفحة -------------------------
  // الصفحة نفسها تأخذ لون الخلفية (لا ما حولها فقط):
  // الأبيض في الصفحة ← لون الورق، والأسود ← لون الحبر.
  // الليلي موحّد وهادئ (رمادي دافئ ونص بيج) بدل الأسود والأبيض الحادين،
  // وألوان الخلفية تعمل في النهاري فقط.

  // الخلفية ولون نصها من مكان واحد (ReaderPaper في reader_settings_sheet.dart)
  Color get _paper => _reader.settings.paperColor;

  Color get _ink => _reader.settings.inkColor;

  // كل قناة لونية: 0 ← الحبر، 255 ← الورق (خط مستقيم بينهما)
  ColorFilter get _pageFilter {
    final ink = _ink;
    final paper = _paper;
    List<double> row(double i, double p, int index) => [
      for (var c = 0; c < 4; c++) c == index ? (p - i) : 0.0,
      i * 255,
    ];
    return ColorFilter.matrix(<double>[
      ...row(ink.r, paper.r, 0),
      ...row(ink.g, paper.g, 1),
      ...row(ink.b, paper.b, 2),
      0, 0, 0, 1, 0, //
    ]);
  }

  // الورق داكن (الليلي أو لون داكن): الملاحظات الداكنة تُعرض فاتحة
  bool get _paperIsDark => _reader.settings.darkPaper;

  // طبقة التحديدات لصفحة واحدة (لا تلتقط اللمس)
  Widget _marksLayer(int page) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: MarksPainter(
        marks: List.of(_marks[page] ?? const <TextMark>[]),
        selection: page == _selPage ? _selectionRects : null,
      ),
    ),
  );

  // ------------------------- القراءة الأفقية (صفحة صفحة) -------------------------

  Widget _buildPaged() {
    final source = _source!;
    final pager = _pager ??= PageController(
      initialPage: _currentPage.value - 1,
    );
    // في العربية تُقلب الصفحات من اليمين إلى اليسار
    final reverse = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(
      builder: (context, constraints) {
        // الصفحة كاملة داخل الشاشة مع الهامش
        final pad = _hPad;
        final maxW = math.max(0.0, constraints.maxWidth - pad * 2);
        final maxH = math.max(
          0.0,
          constraints.maxHeight - math.max(pad, 12) * 2,
        );
        final w = math.min(maxW, maxH / _aspectRatio);
        final h = w * _aspectRatio;
        // مكان الصفحة على الشاشة (لتحديد النص)
        _pagedRect = Rect.fromLTWH(
          (constraints.maxWidth - w) / 2,
          (constraints.maxHeight - h) / 2,
          w,
          h,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              // إصبعان على الشاشة: نوقف التقليب حتى لا يتنافس مع الزوم
              onPointerDown: (_) => _countPointers(1),
              onPointerUp: (_) => _countPointers(-1),
              onPointerCancel: (_) => _countPointers(-1),
              child: GestureDetector(
                onLongPressStart: (d) => _onLongPress(d.localPosition),
                onTapUp: (d) => _onTapPages(d.localPosition),
                child: PageView.builder(
                  controller: pager,
                  // لا تقليب أثناء الكتابة أو الزوم
                  physics: _pagerLocked
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  reverse: reverse,
                  itemCount: _pageCount,
                  onPageChanged: (i) {
                    _clearSelection();
                    _resetPagedZoom();
                    _currentPage.value = i + 1;
                  },
                  itemBuilder: (context, i) {
                    final page = Center(
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _PageTile(
                              key: ValueKey('paged-$i'),
                              index: i,
                              source: source,
                              notes: _notes[i] ?? const [],
                              editMode: _editMode,
                              onTapPage: _addNote,
                              onTapNote: _onTapNote,
                              onScaleStartNote: _noteScaleStart,
                              onScaleUpdateNote: _noteScaleUpdate,
                              onScaleEndNote: _saveNotes,
                              editingId: _editingId,
                              inlineText: _inlineText,
                              inlineFocus: _inlineFocus,
                              onInlineChanged: _onInlineChanged,
                              onInlineDrag: _dragEditingNote,
                              // لون الورق على صورة الصفحة فقط، والملاحظات بألوانها
                              pageFilter: _pageFilter,
                              paperColor: _paper,
                              darkPaper: _paperIsDark,
                            ),
                            _marksLayer(i),
                          ],
                        ),
                      ),
                    );

                    // الصفحة الحالية فقط قابلة للتكبير (بإصبعين أو بالأزرار)
                    if (i != _currentPage.value - 1) return page;
                    return InteractiveViewer(
                      transformationController: _pagedZoom,
                      minScale: 1,
                      maxScale: 4,
                      // السحب بإصبع واحد للتنقل داخل الصفحة المكبرة فقط
                      panEnabled: _pagedZoomed,
                      // لا زوم أثناء الكتابة (مواضع الملاحظات بمقاس الصفحة الأصلي)
                      scaleEnabled: !_editMode,
                      onInteractionUpdate: (_) => _syncPagedZoom(),
                      onInteractionEnd: (_) => _syncPagedZoom(),
                      child: page,
                    );
                  },
                ),
              ),
            ),
            // إطار النص المحدد ومقابضه (نفس طبقة العامودي)
            _buildOverlay(),
          ],
        );
      },
    );
  }

  // ---- الزوم في القراءة الأفقية ----

  bool get _pagerLocked => _editMode || _pagedZoomed || _pointers >= 2;

  void _countPointers(int delta) {
    final wasLocked = _pagerLocked;
    _pointers = math.max(0, _pointers + delta);
    if (_pagerLocked != wasLocked) setState(() {});
  }

  void _syncPagedZoom() {
    final zoomed = _pagedZoom.value.getMaxScaleOnAxis() > 1.01;
    if (!zoomed && _pagedZoom.value != Matrix4.identity()) {
      _pagedZoom.value = Matrix4.identity(); // يرجع للمقاس الطبيعي تمامًا
    }
    if (zoomed != _pagedZoomed) {
      setState(() => _pagedZoomed = zoomed);
    } else if (_selPage != null) {
      setState(() {}); // المقبضان والقائمة يتبعان الصفحة أثناء الزوم والتحريك
    }
  }

  void _resetPagedZoom() {
    _pagedZoom.value = Matrix4.identity();
    _pointers = 0;
    if (_pagedZoomed) setState(() => _pagedZoomed = false);
  }

  // أزرار + و −: تكبير حول منتصف الشاشة
  void _zoomPaged(double delta) {
    final box = _pagesKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _editMode) return;
    final c = box.size.center(Offset.zero);
    final s = (_pagedZoom.value.getMaxScaleOnAxis() + delta).clamp(1.0, 4.0);
    _pagedZoom.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, c.dx * (1 - s))
      ..setEntry(1, 3, c.dy * (1 - s));
    _syncPagedZoom();
  }

  // ------------------------- الصفحات + مقابض التحكم -------------------------

  Widget _buildPages() {
    final source = _source!;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewWidth = constraints.maxWidth;
        _viewHeight = constraints.maxHeight;

        // أول بناء: الانتقال لآخر صفحة مقروءة
        final pending = _pendingPage;
        if (pending != null && _viewWidth > 0) {
          _pendingPage = null;
          _scrollY = (pending - 1) * _extent;
          // تحديث رقم الصفحة بعد انتهاء البناء (لا يجوز أثناءه)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _updateCurrentPage();
            _reportPage();
          });
        }

        // أثناء الكتابة: يبقى النص ظاهرًا فوق لوحة المفاتيح
        final editing = _editingNote;
        if (editing != null && _extent > 0) {
          final top =
              editing.page * _extent + _offsetY + editing.y * _pageHeight;
          final bottom =
              top + _noteH(editing, _pageWidth, _pageHeight) * _pageHeight;
          if (bottom - _scrollY > _viewHeight - 16) {
            _scrollY = bottom - _viewHeight + 16;
          }
          if (top - _scrollY < 8) _scrollY = top - 8;
        }
        _clampScroll();

        final extent = _extent;
        final offsetY = _offsetY;

        final first = (_scrollY / extent).floor().clamp(0, _pageCount - 1);
        final last =
            ((_scrollY + _viewHeight) / extent).floor() +
            1; // صفحة إضافية للتحميل المسبق
        final lastIndex = last.clamp(0, _pageCount - 1).toInt();

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // ضغطة مطولة = تحديد كلمة، ولمسة = إلغاء التحديد أو اختيار تحديد محفوظ
                onLongPressStart: (d) => _onLongPress(d.localPosition),
                onTapUp: (d) => _onTapPages(d.localPosition),
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: ClipRect(
                  child: SizedBox.expand(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (var i = first.toInt(); i <= lastIndex; i++)
                          Positioned(
                            key: ValueKey(i),
                            left: _hPad * _zoom - _scrollX,
                            top: i * extent - _scrollY + offsetY,
                            width: _pageWidth,
                            height: _pageHeight,
                            child: _PageTile(
                              index: i,
                              source: source,
                              notes: _notes[i] ?? const [],
                              editMode: _editMode,
                              onTapPage: _addNote,
                              onTapNote: _onTapNote,
                              onScaleStartNote: _noteScaleStart,
                              onScaleUpdateNote: _noteScaleUpdate,
                              onScaleEndNote: _saveNotes,
                              editingId: _editingId,
                              inlineText: _inlineText,
                              inlineFocus: _inlineFocus,
                              onInlineChanged: _onInlineChanged,
                              onInlineDrag: _dragEditingNote,
                              // لون الورق على صورة الصفحة فقط، والملاحظات بألوانها
                              pageFilter: _pageFilter,
                              paperColor: _paper,
                              darkPaper: _paperIsDark,
                            ),
                          ),
                        // التحديدات فوق الصفحة (خارج فلتر الوضع الليلي حتى تبقى ألوانها)
                        for (var i = first.toInt(); i <= lastIndex; i++)
                          if (_marks[i] != null || i == _selPage)
                            Positioned(
                              key: ValueKey('marks-$i'),
                              left: _hPad * _zoom - _scrollX,
                              top: i * extent - _scrollY + offsetY,
                              width: _pageWidth,
                              height: _pageHeight,
                              child: _marksLayer(i),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildOverlay(),
          ],
        );
      },
    );
  }

  // مقابض أصغر (طلب المستخدم)، ومنطقة اللمس حولها تبقى 48
  Widget _circleHandle() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9E9E9E), width: 2),
      ),
    );
  }

  Widget _pillHandle() {
    return Container(
      width: 14,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: pillColor, width: 1.6),
      ),
      child: Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _cornerButton(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.6),
      ),
      child: Icon(icon, size: 17, color: const Color(0xFF303030)),
    );
  }

  // منطقة لمس تلتقط الحركة مباشرة بدون تأخير (Listener)
  Widget _grab({
    required double left,
    required double top,
    required double width,
    required double height,
    required Widget child,
    void Function(PointerDownEvent e)? onDown,
    required void Function(PointerMoveEvent e) onMove,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onDown,
        onPointerMove: onMove,
        onPointerUp: (_) => _saveNotes(),
        onPointerCancel: (_) => _saveNotes(),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildOverlay() {
    final note = _selectedNote;

    if (!_editMode || note == null) {
      return const Positioned(
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        child: SizedBox.shrink(),
      );
    }

    final pw = _pw;
    final ph = _ph;

    final hFrac = _noteH(note, pw, ph);
    final noteW = note.w * pw;
    final noteH = hFrac * ph;

    // مكان الصفحة على الشاشة (عامودي أو أفقي)
    final pageRect = _pageRect(note.page);
    if (pageRect == null) {
      return const Positioned(
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        child: SizedBox.shrink(),
      );
    }
    final pageLeft = pageRect.left;
    final pageTop = pageRect.top;

    final cx = pageLeft + (note.x + note.w / 2) * pw;
    final cy = pageTop + (note.y + hFrac / 2) * ph;

    final cw = noteW + _ov * 2;
    final ch = noteH + _ov * 2;

    const hit = 48.0;
    const corner = 26.0; // بُعد الأزرار الزاوية عن الصندوق
    const btn = 40.0; // منطقة اللمس (الدائرة نفسها 30)

    return Positioned(
      left: cx - cw / 2,
      top: cy - ch / 2,
      width: cw,
      height: ch,
      child: Transform.rotate(
        angle: note.rot,
        child: SizedBox(
          key: _ovKey,
          width: cw,
          height: ch,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // إطار رفيع حول الصندوق
              Positioned(
                left: _ov,
                top: _ov,
                width: noteW,
                height: noteH,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF424242),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),

              // مقبض علوي (الارتفاع)
              _grab(
                left: _ov + noteW / 2 - hit / 2,
                top: _ov - hit / 2,
                width: hit,
                height: hit,
                child: _circleHandle(),
                onMove: (e) => _edgeResize(note, 0, -e.localDelta.dy, 0, 0),
              ),

              // مقبض سفلي (الارتفاع)
              _grab(
                left: _ov + noteW / 2 - hit / 2,
                top: _ov + noteH - hit / 2,
                width: hit,
                height: hit,
                child: _circleHandle(),
                onMove: (e) => _edgeResize(note, 0, 0, 0, e.localDelta.dy),
              ),

              // مقبض أيسر (العرض)
              _grab(
                left: _ov - hit / 2,
                top: _ov + noteH / 2 - hit / 2,
                width: hit,
                height: hit,
                child: _circleHandle(),
                onMove: (e) => _edgeResize(note, -e.localDelta.dx, 0, 0, 0),
              ),

              // مقبض أيمن على شكل حبة (العرض)
              _grab(
                left: _ov + noteW - hit / 2,
                top: _ov + noteH / 2 - 28,
                width: hit,
                height: 56,
                child: _pillHandle(),
                onMove: (e) => _edgeResize(note, 0, 0, e.localDelta.dx, 0),
              ),

              // زر الحذف (أعلى اليسار)
              Positioned(
                left: _ov - corner - btn / 2,
                top: _ov - corner - btn / 2,
                width: btn,
                height: btn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _deleteNote(note),
                  child: Center(child: _cornerButton(Icons.close)),
                ),
              ),

              // زر الدوران (أعلى اليمين)
              _grab(
                left: _ov + noteW + corner - btn / 2,
                top: _ov - corner - btn / 2,
                width: btn,
                height: btn,
                child: _cornerButton(Icons.rotate_right),
                onDown: _rotDown,
                onMove: _rotMove,
              ),

              // مقبض التحريك (أسفل اليسار): يعمل حتى أثناء الكتابة
              _grab(
                left: _ov - corner - btn / 2,
                top: _ov + noteH + corner - btn / 2,
                width: btn,
                height: btn,
                child: _cornerButton(Icons.open_with),
                onMove: (e) => _moveNote(note, e.delta),
              ),

              // زر التكبير المتناسق (أسفل اليمين)
              _grab(
                left: _ov + noteW + corner - btn / 2,
                top: _ov + noteH + corner - btn / 2,
                width: btn,
                height: btn,
                child: _cornerButton(Icons.open_in_full),
                onDown: _scaleDown,
                onMove: _scaleMove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// صفحة واحدة: صورة الصفحة + الملاحظات فوقها
// ---------------------------------------------------------------------------

class _PageTile extends StatefulWidget {
  final int index;
  final _PageSource source;
  final List<_Note> notes;
  final bool editMode;
  final void Function(int page, double x, double y) onTapPage;
  final void Function(_Note note) onTapNote;
  final void Function(_Note note) onScaleStartNote;
  final void Function(
    _Note note,
    ScaleUpdateDetails details,
    double pageWidth,
    double pageHeight,
  )
  onScaleUpdateNote;
  final VoidCallback onScaleEndNote;

  // الكتابة المباشرة (اختيارية)
  final String? editingId;
  final TextEditingController? inlineText;
  final FocusNode? inlineFocus;
  final ValueChanged<String>? onInlineChanged;
  final void Function(_Note note, Offset delta)? onInlineDrag;

  // لون الورق: يُطبَّق على صورة الصفحة فقط (الملاحظات تبقى بألوانها)
  final ColorFilter? pageFilter;
  final Color? paperColor;
  final bool darkPaper;

  const _PageTile({
    super.key,
    required this.index,
    required this.source,
    required this.notes,
    required this.editMode,
    required this.onTapPage,
    required this.onTapNote,
    required this.onScaleStartNote,
    required this.onScaleUpdateNote,
    required this.onScaleEndNote,
    this.editingId,
    this.inlineText,
    this.inlineFocus,
    this.onInlineChanged,
    this.onInlineDrag,
    this.pageFilter,
    this.paperColor,
    this.darkPaper = false,
  });

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  // مساحة لمس إضافية حول النص في وضع التعديل
  static const double _touchPad = 14;

  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.source.load(widget.index);
  }

  @override
  void dispose() {
    widget.source.cancel(widget.index);
    super.dispose();
  }

  void _retry() {
    setState(() {
      _future = widget.source.load(widget.index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.editMode ? _touchPad : 0.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.paperColor ?? Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: IconButton(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    tooltip: AppStrings.of(context).retryPage(widget.index + 1),
                  ),
                );
              }

              final data = snapshot.data;

              if (data == null) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final image = Image.memory(
                data,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              );
              final filter = widget.pageFilter;
              return filter == null
                  ? image
                  : ColorFiltered(colorFilter: filter, child: image);
            },
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (widget.editMode)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) => widget.onTapPage(
                            widget.index,
                            details.localPosition.dx / w,
                            details.localPosition.dy / h,
                          ),
                        ),
                      ),
                    for (final note in widget.notes)
                      Positioned(
                        left: note.x * w - pad,
                        top: note.y * h - pad,
                        width: note.w * w + pad * 2,
                        child: Transform.rotate(
                          angle: note.rot,
                          child: _NoteView(
                            note: note,
                            pageWidth: w,
                            pageHeight: h,
                            pad: pad,
                            editMode: widget.editMode,
                            onTap: () => widget.onTapNote(note),
                            editing:
                                widget.editMode && note.id == widget.editingId,
                            inlineText: widget.inlineText,
                            inlineFocus: widget.inlineFocus,
                            onInlineChanged: widget.onInlineChanged,
                            darkPaper: widget.darkPaper,
                            onInlineDrag: widget.onInlineDrag == null
                                ? null
                                : (d) => widget.onInlineDrag!(note, d),
                            onScaleStart: () => widget.onScaleStartNote(note),
                            onScaleUpdate: (details) =>
                                widget.onScaleUpdateNote(note, details, w, h),
                            onScaleEnd: widget.onScaleEndNote,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteView extends StatelessWidget {
  final _Note note;
  final double pageWidth;
  final double pageHeight;
  final double pad;
  final bool editMode;
  final bool editing; // يُكتب الآن في مكانه
  final bool darkPaper; // الورق داكن (الليلي)
  final TextEditingController? inlineText;
  final FocusNode? inlineFocus;
  final ValueChanged<String>? onInlineChanged;
  final ValueChanged<Offset>? onInlineDrag;
  final VoidCallback onTap;
  final VoidCallback onScaleStart;
  final void Function(ScaleUpdateDetails details) onScaleUpdate;
  final VoidCallback onScaleEnd;

  const _NoteView({
    required this.note,
    required this.pageWidth,
    required this.pageHeight,
    required this.pad,
    required this.editMode,
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    this.editing = false,
    this.darkPaper = false,
    this.inlineText,
    this.inlineFocus,
    this.onInlineChanged,
    this.onInlineDrag,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = note.size * pageWidth;
    final fixedHeight = note.h;
    final rtl = _isRtl(note.text);
    // على ورق داكن: النص الداكن (كالأسود الافتراضي) يظهر فاتحًا، وبقية الألوان كما اختيرت
    final chosen = Color(note.color);
    final shown = darkPaper && chosen.computeLuminance() < 0.2
        ? const Color(0xFFE6E0D4)
        : chosen;
    final style = _noteTextStyle(
      note,
      fontSize,
    ).copyWith(color: shown, decorationColor: shown);

    final box = Opacity(
      opacity: note.opacity.clamp(0.0, 1.0).toDouble(),
      child: Container(
        height: fixedHeight == null ? null : fixedHeight * pageHeight,
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.all(fontSize * 0.15),
        decoration: BoxDecoration(
          color: note.bg == null ? null : Color(note.bg!),
        ),
        // حدّ خفيف لا يؤثر على قياس الصندوق
        foregroundDecoration: editMode
            ? BoxDecoration(
                border: Border.all(color: const Color(0x30000000), width: 1),
              )
            : null,
        child: editing && inlineText != null
            // الكتابة المباشرة: حقل بلا إطار بنفس خط النص ومكانه
            ? MediaQuery.withNoTextScaling(
                child: TextField(
                  controller: inlineText,
                  focusNode: inlineFocus,
                  onChanged: onInlineChanged,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlign: _alignOf(note),
                  textDirection: note.text.isEmpty
                      ? Directionality.of(context)
                      : (rtl ? TextDirection.rtl : TextDirection.ltr),
                  style: style,
                  cursorColor: shown,
                  cursorWidth: math.max(1.5, fontSize * 0.08),
                  decoration: const InputDecoration.collapsed(hintText: null),
                ),
              )
            : Text(
                note.text,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                textAlign: _alignOf(note),
                textScaler: TextScaler.noScaling,
                style: style,
              ),
      ),
    );

    if (!editMode) return box;

    // أثناء الكتابة: لمسة قصيرة للمؤشر، وسحب بالإصبع يحرك النص
    if (editing) {
      return _DragToMove(
        onMove: onInlineDrag,
        onEnd: onScaleEnd,
        child: Padding(padding: EdgeInsets.all(pad), child: box),
      );
    }

    // جسم النص: سحب بإصبع، وتكبير بإصبعين، وضغطة للتحديد/التعديل
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onScaleStart: (_) => onScaleStart(),
      onScaleUpdate: onScaleUpdate,
      onScaleEnd: (_) => onScaleEnd(),
      child: Padding(padding: EdgeInsets.all(pad), child: box),
    );
  }
}

// سحب النص بالإصبع أثناء الكتابة: حركة أكثر من 10 بكسل = سحب، وأقل = لمسة
// (Listener لا يدخل في تنافس الإيماءات، فالحقل يبقى يستقبل اللمس للمؤشر)
class _DragToMove extends StatefulWidget {
  const _DragToMove({
    required this.child,
    required this.onMove,
    required this.onEnd,
  });

  final Widget child;
  final ValueChanged<Offset>? onMove;
  final VoidCallback onEnd;

  @override
  State<_DragToMove> createState() => _DragToMoveState();
}

class _DragToMoveState extends State<_DragToMove> {
  static const double _slop = 10;

  Offset? _start;
  bool _dragging = false;

  void _reset() {
    if (_dragging) widget.onEnd();
    _start = null;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _start = e.position;
        _dragging = false;
      },
      onPointerMove: (e) {
        final start = _start;
        if (start == null || widget.onMove == null) return;
        if (!_dragging && (e.position - start).distance > _slop) {
          _dragging = true;
        }
        if (_dragging) widget.onMove!(e.delta);
      },
      onPointerUp: (_) => _reset(),
      onPointerCancel: (_) => _reset(),
      child: widget.child,
    );
  }
}
