import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' show Printing;
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfDocument;

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
  _NoteFont('serif', 'Serif',
      family: 'serif', fallback: ['Georgia', 'Times New Roman']),
  _NoteFont('mono', 'Mono',
      family: 'monospace', fallback: ['Courier New', 'Menlo']),
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
        bg: (json['bg'] as int?) ??
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
    text: TextSpan(text: note.text, style: _noteTextStyle(note, fontSize)),
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
// نافذة النص
// ---------------------------------------------------------------------------

class _TextDialog extends StatefulWidget {
  final String initial;

  const _TextDialog({this.initial = ''});

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? 'Add text' : 'Edit text'),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: 'Type your text...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// نافذة اختيار لون (ألوان جاهزة + ألوان مخصصة HSV)
// ---------------------------------------------------------------------------

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

  Widget _slider(String label, double value, double max,
      ValueChanged<double> onChanged) {
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
            _slider('H', _hsv.hue, 360,
                (v) => setState(() => _hsv = _hsv.withHue(v))),
            _slider('S', _hsv.saturation, 1,
                (v) => setState(() => _hsv = _hsv.withSaturation(v))),
            _slider('V', _hsv.value, 1,
                (v) => setState(() => _hsv = _hsv.withValue(v))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.allowNone)
          TextButton(
            onPressed: () => Navigator.pop(context, const _ColorChoice(null)),
            child: const Text('None'),
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

  const DocumentViewerPage({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage>
    with SingleTickerProviderStateMixin {
  static const Color background = Color(0xFFF3EFE6);
  static const Color dark = Color(0xFF202020);
  static const Color red = Color(0xFFC62828);
  static const Color accent = Color(0xFF1A73E8);
  static const Color pillColor = Color(0xFF7FF0DF);

  static const double _hPad = 12;
  static const double _gap = 12;
  static const double _ov = 56; // هامش منطقة المقابض حول الصندوق

  final ValueNotifier<int> _currentPage = ValueNotifier<int>(1);
  final GlobalKey _ovKey = GlobalKey();

  bool _loading = true;
  String? _error;

  _PageSource? _source;
  int _pageCount = 0;
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

      if (!mounted) return;

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

    final directory = Directory(
      p.join(appDirectory.path, 'quickstudy_notes'),
    );

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
          .map((note) => note.toJson())
          .toList();

      final file = await _notesFile();
      await file.writeAsString(jsonEncode(all), flush: true);
    } catch (e) {
      _showMessage('Could not save notes: $e');
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

  Future<void> _addNote(int page, double nx, double ny) async {
    // لمسة على مكان فارغ وفيه عنصر محدد = إلغاء التحديد فقط
    if (_selectedId != null) {
      setState(() => _selectedId = null);
      return;
    }

    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _TextDialog(),
    );

    if (text == null || text.trim().isEmpty) return;

    const width = 0.5;

    final note = _Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: page,
      x: nx.clamp(0.0, 1.0 - width).toDouble(),
      y: ny.clamp(0.0, 0.97).toDouble(),
      w: width,
      size: _defSize,
      text: text.trim(),
      color: _defColor,
      font: _defFont,
    );

    setState(() {
      _notes.putIfAbsent(page, () => []).add(note);
      _selectedId = note.id;
    });

    await _saveNotes();
  }

  void _onTapNote(_Note note) {
    if (_selectedId == note.id) {
      _editText(note);
    } else {
      setState(() => _selectedId = note.id);
    }
  }

  Future<void> _editText(_Note note) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(initial: note.text),
    );

    if (text == null) return;

    if (text.trim().isEmpty) {
      _deleteNote(note);
      return;
    }

    setState(() => note.text = text.trim());
    await _saveNotes();
  }

  void _deleteNote(_Note note) {
    setState(() {
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
      builder: (_) => _ColorDialog(
        title: title,
        initial: initial,
        allowNone: allowNone,
      ),
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
        note.size =
            (_noteStartSize * details.scale).clamp(0.012, 0.3).toDouble();
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
    final pw = _pageWidth;
    final ph = _pageHeight;

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

    final pw = _pageWidth;
    final ph = _pageHeight;
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

    final pw = _pageWidth;
    final ph = _pageHeight;

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
      _zoomAround(
        _zoom + delta,
        Offset(_viewWidth / 2, _viewHeight / 2),
      );
      _clampScroll();
    });
    _updateCurrentPage();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _fling.stop();
    _startZoom = _zoom;
    _lastPointerCount = details.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
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
    if (details.pointerCount > 0) return;

    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity.abs() < 80) return;

    _fling.animateWith(
      ClampingScrollSimulation(
        position: _scrollY,
        velocity: -velocity,
      ),
    );
  }

  void _onFling() {
    setState(() {
      _scrollY = _fling.value.clamp(0.0, _maxY).toDouble();
    });
    _updateCurrentPage();
  }

  Future<void> _goToPage() async {
    final input = TextEditingController();

    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Go to page (1 - $_pageCount)'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(input.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );

    input.dispose();

    if (page == null) return;

    final target = page.clamp(1, _pageCount).toInt();

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
    _fling.dispose();
    _currentPage.dispose();
    _source?.dispose();
    super.dispose();
  }

  // ------------------------- الواجهة -------------------------

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _error == null;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: dark,
        elevation: 0,
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (ready) ...[
            if (_pageCount > 1) ...[
              ValueListenableBuilder<int>(
                valueListenable: _currentPage,
                builder: (_, page, __) => Center(
                  child: Text(
                    '$page / $_pageCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Go to page',
                onPressed: _goToPage,
                icon: const Icon(Icons.pin_outlined),
              ),
            ],
            IconButton(
              tooltip: _editMode ? 'Finish editing' : 'Add / edit text',
              onPressed: () => setState(() {
                _editMode = !_editMode;
                _selectedId = null;
              }),
              icon: Icon(
                _editMode ? Icons.check_circle : Icons.edit_outlined,
              ),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
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
            const Text(
              'Could not open this file',
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
              label: const Text('Try again'),
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
          child: Stack(
            children: [
              _buildPages(),
              Positioned(
                right: 12,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: null,
                      backgroundColor: dark,
                      foregroundColor: Colors.white,
                      onPressed: () => _zoomByButton(0.5),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: null,
                      backgroundColor: dark,
                      foregroundColor: Colors.white,
                      onPressed: () => _zoomByButton(-0.5),
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_editMode) _buildToolbar(),
      ],
    );
  }

  // ------------------------- الشريط السفلي -------------------------

  Widget _buildToolbar() {
    final note = _selectedNote;

    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child:
              note == null ? _buildToolbarHint() : _buildToolbarControls(note),
        ),
      ),
    );
  }

  Widget _buildToolbarHint() {
    return Row(
      children: [
        const Icon(Icons.touch_app_outlined, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Tap anywhere to add text, or tap a text to edit it',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _editMode = false),
          child: const Text('Done'),
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
        backgroundColor: on ? accent.withValues(alpha: 0.14) : null,
        foregroundColor: on ? accent : Colors.black87,
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
          child: Icon(icon, size: 18, color: Colors.black54),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            activeColor: accent,
            onChanged: onChanged,
            onChangeEnd: (_) => _saveNotes(),
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
                    selectedColor: accent.withValues(alpha: 0.16),
                    side: BorderSide(
                      color: selected ? accent : Colors.black26,
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
                  _toggle(Icons.format_bold, note.bold,
                      () => _mutate((n) => n.bold = !n.bold), 'Bold'),
                  _toggle(Icons.format_italic, note.italic,
                      () => _mutate((n) => n.italic = !n.italic), 'Italic'),
                  _toggle(
                      Icons.format_underlined,
                      note.underline,
                      () => _mutate((n) => n.underline = !n.underline),
                      'Underline'),
                  _toggle(
                      Icons.format_align_left,
                      note.align == 1,
                      () => _mutate((n) => n.align = n.align == 1 ? 0 : 1),
                      'Align left'),
                  _toggle(
                      Icons.format_align_center,
                      note.align == 2,
                      () => _mutate((n) => n.align = n.align == 2 ? 0 : 2),
                      'Align center'),
                  _toggle(
                      Icons.format_align_right,
                      note.align == 3,
                      () => _mutate((n) => n.align = n.align == 3 ? 0 : 3),
                      'Align right'),
                  _toggle(
                    Icons.format_color_fill,
                    note.bg != null,
                    () => _pickColor(
                      title: 'Background (cover original text)',
                      initial: note.bg,
                      allowNone: true,
                      apply: (c) => note.bg = c,
                    ),
                    'Background / cover original text',
                  ),
                  IconButton(
                    tooltip: 'Edit text',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editText(note),
                    icon: const Icon(Icons.text_fields, size: 22),
                  ),
                  IconButton(
                    tooltip: 'Duplicate',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _duplicateNote(note),
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteNote(note),
                    icon:
                        const Icon(Icons.delete_outline, size: 22, color: red),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedId = null),
                    child: const Text('Done'),
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
                        title: 'Text color',
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
                          gradient: const SweepGradient(colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ]),
                        ),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white),
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
                          color: selected ? accent : Colors.black26,
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
            _sliderRow(Icons.format_size, 'Size', note.size, 0.012, 0.3, (v) {
              _defSize = v;
              _mutate((n) => n.size = v, save: false);
            }),
            _sliderRow(Icons.opacity, 'Opacity', note.opacity, 0.1, 1.0,
                (v) => _mutate((n) => n.opacity = v, save: false)),
            _sliderRow(Icons.rotate_right, 'Rotation', note.rot, -math.pi,
                math.pi, (v) => _mutate((n) => n.rot = v, save: false)),
          ],
        ),
      ),
    );
  }

  // ------------------------- الصفحات + مقابض التحكم -------------------------

  Widget _buildPages() {
    final source = _source!;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewWidth = constraints.maxWidth;
        _viewHeight = constraints.maxHeight;
        _clampScroll();

        final extent = _extent;
        final offsetY = _offsetY;

        final first = (_scrollY / extent).floor().clamp(0, _pageCount - 1);
        final last =
            ((_scrollY + _viewHeight) / extent).floor() + 1; // صفحة إضافية للتحميل المسبق
        final lastIndex = last.clamp(0, _pageCount - 1).toInt();

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
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
                            ),
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

  Widget _circleHandle() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9E9E9E), width: 2.5),
      ),
    );
  }

  Widget _pillHandle() {
    return Container(
      width: 26,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: pillColor, width: 2.5),
      ),
      child: Container(
        width: 6,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _cornerButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 2.5),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF303030)),
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

    final pw = _pageWidth;
    final ph = _pageHeight;

    final hFrac = _noteH(note, pw, ph);
    final noteW = note.w * pw;
    final noteH = hFrac * ph;

    final pageLeft = _hPad * _zoom - _scrollX;
    final pageTop = note.page * _extent - _scrollY + _offsetY;

    final cx = pageLeft + (note.x + note.w / 2) * pw;
    final cy = pageTop + (note.y + hFrac / 2) * ph;

    final cw = noteW + _ov * 2;
    final ch = noteH + _ov * 2;

    const hit = 48.0;
    const corner = 34.0; // بُعد الأزرار الزاوية عن الصندوق
    const btn = 40.0;

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
                top: _ov + noteH / 2 - 36,
                width: hit,
                height: 72,
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
  ) onScaleUpdateNote;
  final VoidCallback onScaleEndNote;

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
        color: Colors.white,
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
                    tooltip: 'Retry page ${widget.index + 1}',
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

              return Image.memory(
                data,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              );
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
                            onScaleStart: () => widget.onScaleStartNote(note),
                            onScaleUpdate: (details) => widget
                                .onScaleUpdateNote(note, details, w, h),
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
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = note.size * pageWidth;
    final fixedHeight = note.h;
    final rtl = _isRtl(note.text);

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
        child: Text(
          note.text,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: _alignOf(note),
          textScaler: TextScaler.noScaling,
          style: _noteTextStyle(note, fontSize),
        ),
      ),
    );

    if (!editMode) return box;

    // جسم النص: سحب بإصبع، وتكبير بإصبعين، وضغطة للتحديد/التعديل
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onScaleStart: (_) => onScaleStart(),
      onScaleUpdate: onScaleUpdate,
      onScaleEnd: (_) => onScaleEnd(),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: box,
      ),
    );
  }
}
