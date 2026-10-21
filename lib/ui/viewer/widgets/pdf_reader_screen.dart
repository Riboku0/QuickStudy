import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        FilteringTextInputFormatter,
        HapticFeedback,
        LengthLimitingTextInputFormatter;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/bookmarks/bookmark_repository.dart';
import '../../../data/repositories/reader/reader_settings_repository.dart';
import '../../../domain/models/reader_settings.dart';
import '../../core/ui/core_ui.dart';
import 'pdf_ink.dart';
import 'pdf_marks.dart';
import 'pdf_note_cards.dart';
import 'pdf_notes.dart';
import 'pdf_text_tools.dart';
import 'pdf_scanned_text.dart';
import 'reader_chrome.dart';
import 'reader_settings_sheet.dart';
import 'text_marks.dart';

// نتيجة إغلاق العارض: فتح العارض القديم على صفحة (للقلم والتحديد حتى تُبنى هنا)
class OpenClassicViewer {
  const OpenClassicViewer(this.page);

  final int page;
}

// عارض PDF الجديد على pdfrx (PDFium): رسم سريع بأجزاء حسب الزوم، وصفحات حسب الحاجة.
// المرحلة 1: القراءة والزوم والتقدم والعلامات والسطوع وألوان الورق والليلي.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    this.initialPage,
    this.onPageChanged,
  });

  final int fileId;
  final String fileName;
  final String filePath;
  final int? initialPage;
  final void Function(int page, int count)? onPageChanged;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final _controller = PdfViewerController();
  final _page = ValueNotifier<int>(1);
  late final ReaderSettingsRepository _reader;
  late final BookmarkRepository _bookmarks;
  int _pageCount = 0;

  // التحديدات المحفوظة، والنشط منها (يُعدَّل من القائمة)
  late final PdfMarks _marks = PdfMarks(widget.fileId);
  // الصفحات الممسوحة: كلمات OCR وتحديد خاص بها (مقبضان من عندنا)
  late final ScannedPageText _scanned = ScannedPageText(
    lectureId: widget.fileId,
    filePath: widget.filePath,
  );
  int? _ocrPage; // من 0
  List<PageWord> _ocrWords = const [];
  int _ocrA = 0;
  int _ocrB = 0;
  Timer? _prefetchTimer;
  final _stackKey = GlobalKey();

  // القلم: إصبع يرسم أو يكتب، وإصبعان يحركان ويكبّران
  late final PdfInk _ink = PdfInk(widget.fileId);
  late final PdfNotes _notes = PdfNotes(widget.fileId);
  late final PdfNoteCards _cards = PdfNoteCards(widget.fileId);
  NoteCard? _openCard;
  double _cardHeight = 300; // ارتفاع المذكرة المفتوحة، يتغير بسحب مقبضها
  InkStroke? _cardLive;
  int _cardInkVersion = 0;
  final _cardText = TextEditingController();
  final _cardFocus = FocusNode();
  bool _drawMode = false;
  InkTool _tool = InkTool.pen;
  int _inkColorIndex = 1; // الرمادي الداكن (أو الفاتح على الورق الداكن)
  int _inkWidth = 1; // فهرس في _inkWidths
  InkStroke? _live;
  int? _erasePage;
  final Map<int, Offset> _pointers = {};
  bool _multiTouch = false;
  Offset? _downAt;
  Matrix4 _gesture0 = Matrix4.identity();
  Offset _focal0 = Offset.zero;
  double _distance0 = 1;
  // الملاحظة التي تُكتب الآن
  PageNote? _editing;
  Offset? _textDragStart;
  bool _textDragging = false;
  final _noteText = TextEditingController();
  final _noteFocus = FocusNode();

  // نمط الخط: سماكة نسبة من عرض الصفحة، من الأعرض للأنحف
  static const List<double> _inkWidths = [0.012, 0.0075, 0.0045, 0.0025];
  List<TextMark> _active = const [];
  MarkStyle _style = MarkStyle.highlight;
  int _color = markColors.first;
  // نص محدد الآن بمقابض pdfrx (لم يُحفظ بعد)
  bool _hasSelection = false;
  List<PdfPageTextRange> _selRanges = const [];
  bool _draggingHandle = false;

  // ألوان الليلي الموحّدة (نفس العارض القديم)
  static const Color _nightPaper = Color(0xFF222733);
  static const Color _nightInk = Color(0xFFD5DAE2);

  @override
  void initState() {
    super.initState();
    _reader = context.read<ReaderSettingsRepository>();
    _bookmarks = context.read<BookmarkRepository>();
    _page.value = widget.initialPage ?? 1;
    _reader.addListener(_onReaderChanged);
    _marks.addListener(_onMarksChanged);
    _ink.addListener(_onMarksChanged);
    _ink.load();
    _notes.addListener(_onMarksChanged);
    _notes.load();
    _cards.load();
    _marks.load();
  }

  @override
  void dispose() {
    _reader.removeListener(_onReaderChanged);
    _marks.removeListener(_onMarksChanged);
    _ink.removeListener(_onMarksChanged);
    _ink.dispose();
    _notes.removeListener(_onMarksChanged);
    _notes.dispose();
    _noteText.dispose();
    _noteFocus.dispose();
    _cards.dispose();
    _cardText.dispose();
    _cardFocus.dispose();
    _marks.dispose();
    _prefetchTimer?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _onReaderChanged() {
    if (!mounted) return;
    setState(() {});
    // الألوان مرسومة على الصفحات نفسها، فنعيد رسمها
    if (_controller.isReady) _controller.invalidate();
  }

  ReaderSettings get _settings => _reader.settings;

  Color get _paper =>
      _settings.nightMode ? _nightPaper : _settings.background.color;

  bool get _darkPaper => _settings.nightMode || _settings.background.isDark;

  ReaderChrome get _chrome => ReaderChrome(dark: _darkPaper, paper: _paper);

  double get _margin => switch (_settings.margin) {
    ReaderMargin.none => 2,
    ReaderMargin.standard => 8,
    ReaderMargin.wide => 22,
  };

  // ألوان الورق على الصفحة نفسها:
  // نهارًا multiply (الأبيض ← لون الورق، والأسود يبقى)،
  // وليلًا: عكس ثم screen بلون الورق الكحلي ثم multiply بلون الحبر.
  void _paintPaper(Canvas canvas, Rect rect, PdfPage page) {
    final s = _settings;
    if (s.nightMode || s.background.isDark) {
      final paper = s.nightMode ? _nightPaper : s.background.color;
      final ink = s.nightMode ? _nightInk : const Color(0xFFE6E0D4);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..blendMode = BlendMode.difference,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = paper
          ..blendMode = BlendMode.screen,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = ink
          ..blendMode = BlendMode.multiply,
      );
      return;
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = s.background.color
        ..blendMode = BlendMode.multiply,
    );
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    _page.value = page;
    if (_pageCount > 0) widget.onPageChanged?.call(page, _pageCount);
    _schedulePrefetch();
  }

  Future<void> _toggleBookmark() async {
    final s = AppStrings.of(context);
    final added = await _bookmarks.togglePage(widget.fileId, _page.value);
    if (!mounted) return;
    showAppMessage(context, added ? s.bookmarkAdded : s.bookmarkRemoved);
  }

  void _openSettings() {
    _clearAll();
    ReaderSettingsSheet.show(context, _reader, showLayout: false);
  }

  // ------------------------- التحديد والتظليل -------------------------

  // رسم التحديدات المحفوظة فوق الصفحة (بعد لون الورق حتى تبقى ألوانها)،
  // والتحديد النشط (المختار باللمس أو المحفوظ للتو) بإطار أزرق خفيف
  void _paintMarks(Canvas canvas, Rect rect, PdfPage page) {
    final index = page.pageNumber - 1;
    final marks = _marks.forPage(index);
    final active = [
      for (final m in _active)
        if (m.page == index) ...m.rects,
      if (_hasOcr && _ocrPage == index) ...rectsFor(_ocrWords, _ocrA, _ocrB),
    ];
    if (marks.isEmpty && active.isEmpty) return;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    MarksPainter(
      marks: marks,
      selection: active.isEmpty ? null : active,
      selectionColor: _chrome.selection,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  void _onMarksChanged() {
    if (!mounted) return;
    if (_controller.isReady) _controller.invalidate();
    setState(() {});
  }

  Future<void> _saveMarks() async {
    final ok = await _marks.save();
    if (!ok && mounted) {
      showAppMessage(context, AppStrings.of(context).notesNotSaved);
    }
  }

  void _setActive(List<TextMark> marks) {
    setState(() {
      _active = marks;
      if (marks.isNotEmpty) {
        _style = marks.first.style;
        _color = marks.first.color;
      }
    });
    if (_controller.isReady) _controller.invalidate();
  }

  void _clearAll() {
    if (_ocrPage != null) _clearOcr();
    if (_active.isNotEmpty) _setActive(const []);
    if (_hasSelection) _controller.textSelectionDelegate.clearTextSelection();
  }

  PdfTextSelectionDelegate get _selection => _controller.textSelectionDelegate;

  // نوع أو لون: من نص محدد ينشئ تحديدًا محفوظًا، ومن تحديد محفوظ يعدّله
  Future<void> _applyMark({MarkStyle? style, int? color}) async {
    if (style != null) _style = style;
    if (color != null) _color = color;

    if (_active.isNotEmpty) {
      for (final m in _active) {
        _marks.update(m, style: _style, color: _color);
      }
      setState(() {});
      await _saveMarks();
      return;
    }
    if (_hasOcr) {
      final page = _ocrPage!;
      final mark = TextMark(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: page,
        start: math.min(_ocrA, _ocrB),
        end: math.max(_ocrA, _ocrB),
        style: _style,
        color: _color,
        text: textFor(_ocrWords, _ocrA, _ocrB),
        rects: rectsFor(_ocrWords, _ocrA, _ocrB),
      );
      _marks.add(mark);
      _clearOcr();
      _setActive([mark]);
      await _saveMarks();
      return;
    }
    if (!_hasSelection) return;
    final ranges = await _selection.getSelectedTextRanges();
    final created = _marks.addFromRanges(
      ranges,
      pages: _controller.pages,
      style: _style,
      color: _color,
    );
    await _selection.clearTextSelection();
    if (!mounted) return;
    // القائمة تبقى على التحديد الجديد لتغيير لونه أو إضافة ملاحظة
    _setActive(created);
    await _saveMarks();
  }

  void _deleteMarks() {
    for (final m in _active) {
      _marks.remove(m);
    }
    _setActive(const []);
    _saveMarks();
  }

  Future<String> _currentText() async {
    if (_active.isNotEmpty) return _active.map((m) => m.text).join('\n');
    if (_hasOcr) return textFor(_ocrWords, _ocrA, _ocrB);
    if (_hasSelection) return (await _selection.getSelectedText()).trim();
    return '';
  }

  Future<void> _copy() async {
    final text = await _currentText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppMessage(context, AppStrings.of(context).copied);
    _clearAll();
  }

  Future<void> _bookmarkText() async {
    final text = await _currentText();
    if (text.isEmpty) return;
    int page;
    int? color;
    if (_active.isNotEmpty) {
      page = _active.first.page + 1;
      color = _active.first.color;
    } else if (_hasOcr) {
      page = _ocrPage! + 1;
    } else {
      final ranges = await _selection.getSelectedTextRanges();
      if (ranges.isEmpty) return;
      page = ranges.first.pageNumber;
    }
    await _bookmarks.addText(widget.fileId, page, text, color: color);
    if (!mounted) return;
    showAppMessage(context, AppStrings.of(context).bookmarkAdded);
    _clearAll();
  }

  // الملاحظة تحتاج تحديدًا محفوظًا: من نص محدد نظلّله أولًا
  Future<void> _editNote() async {
    final s = AppStrings.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: s.markNoteTitle,
        confirm: s.saveNote,
        initial: _active.isEmpty ? '' : (_active.first.note ?? ''),
      ),
    );
    if (result == null || !mounted) return;
    if (_active.isEmpty) await _applyMark();
    if (_active.isEmpty) return;
    _marks.update(_active.first, note: result.trim());
    setState(() {});
    await _saveMarks();
  }

  // "المزيد": ترجمة DeepL / ChatGPT / Google أو مشاركة (بلا مفاتيح API)
  Future<void> _showMore() async {
    final text = await _currentText();
    if (text.isEmpty || !mounted) return;
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
      await SharePlus.instance.share(ShareParams(text: text));
      return;
    }
    // روابط طويلة جدًا ترفضها بعض التطبيقات
    final clipped = text.length > 1500 ? text.substring(0, 1500) : text;
    final q = Uri.encodeComponent(clipped);
    // النص العربي يُترجم للإنجليزية، وغيره للعربية
    final target = _arabic.hasMatch(clipped) ? 'en' : 'ar';
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
    if (!opened && mounted) showAppMessage(context, s.openAppFailed);
  }

  static final RegExp _arabic = RegExp(r'[؀-ۿݐ-ݿ]');

  // ------------------------- الصفحات الممسوحة (OCR) -------------------------

  bool get _hasOcr => _ocrPage != null && _ocrWords.isNotEmpty;

  void _clearOcr() {
    setState(() {
      _ocrPage = null;
      _ocrWords = const [];
      _draggingHandle = false;
    });
    if (_controller.isReady) _controller.invalidate();
  }

  // موضع في المستند ← (رقم الصفحة من 0، نقطة نسبية داخلها)
  (int, Offset)? _pagePoint(Offset doc, {int? onlyPage}) {
    final layouts = _controller.layout.pageLayouts;
    for (var i = 0; i < layouts.length; i++) {
      if (onlyPage != null && i != onlyPage) continue;
      final r = layouts[i];
      if (onlyPage == null && !r.contains(doc)) continue;
      return (
        i,
        Offset(
          ((doc.dx - r.left) / r.width).clamp(0.0, 1.0),
          ((doc.dy - r.top) / r.height).clamp(0.0, 1.0),
        ),
      );
    }
    return null;
  }

  Future<void> _onLongPress(Offset doc) async {
    final hit = _pagePoint(doc);
    if (hit == null) return;
    final (index, point) = hit;
    final page = _controller.pages[index];
    final s = AppStrings.of(context);
    _clearAll();

    // صفحة نصية: تحديد pdfrx العادي
    if (!await _scanned.isScanned(page)) {
      await _selection.selectWord(doc);
      return;
    }

    // ممسوحة: "جارٍ قراءة النص" إن تأخرت القراءة أكثر من لحظة
    if (!mounted) return;
    Timer? message;
    if (!_scanned.isReady(index)) {
      message = Timer(const Duration(milliseconds: 600), () {
        if (mounted) showAppMessage(context, s.recognizingPage);
      });
    }
    final words = await _scanned.words(index);
    message?.cancel();
    if (!mounted || words.isEmpty) return;
    final at = wordAt(words, point, exact: true);
    if (at == null) return;

    HapticFeedback.selectionClick();
    setState(() {
      _ocrPage = index;
      _ocrWords = words;
      _ocrA = at;
      _ocrB = at;
    });
    if (_controller.isReady) _controller.invalidate();
  }

  // سحب مقبض: أقرب كلمة في نفس الصفحة لمكان الإصبع
  void _dragOcrHandle(bool start, Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final page = _ocrPage;
    if (box == null || page == null) return;
    final inverse = Matrix4.tryInvert(_controller.value);
    if (inverse == null) return;
    final doc = MatrixUtils.transformPoint(inverse, box.globalToLocal(global));
    final hit = _pagePoint(doc, onlyPage: page);
    if (hit == null) return;
    final at = wordAt(_ocrWords, hit.$2);
    if (at == null) return;
    setState(() => start ? _ocrA = at : _ocrB = at);
    _controller.invalidate();
  }

  // مقبضا التحديد في الصفحات الممسوحة (تحديد pdfrx له مقابضه الخاصة)
  Widget _ocrHandles() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final page = _ocrPage;
        if (!_hasOcr || page == null || !_controller.isReady) {
          return const SizedBox.shrink();
        }
        final List<Rect> layouts;
        try {
          layouts = _controller.layout.pageLayouts;
        } catch (_) {
          return const SizedBox.shrink();
        }
        final pr = layouts[page];
        Offset toLocal(Offset n) => MatrixUtils.transformPoint(
          _controller.value,
          Offset(pr.left + n.dx * pr.width, pr.top + n.dy * pr.height),
        );

        final a = math.min(_ocrA, _ocrB);
        final b = math.max(_ocrA, _ocrB);
        final first = _ocrWords[a].rect;
        final last = _ocrWords[b].rect;
        final rtl = _ocrWords[a].rtl;
        final startAt = toLocal(
          Offset(rtl ? first.right : first.left, first.bottom),
        );
        final endAt = toLocal(
          Offset(rtl ? last.left : last.right, last.bottom),
        );
        const h = SelectionHandle.size;

        // المقبض الأول يحرك بداية التحديد، والثاني نهايته
        Widget handle(bool isStart, Offset at) => Positioned(
          left: at.dx - (isStart != rtl ? h : 0),
          top: at.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _draggingHandle = true),
            onPanUpdate: (d) =>
                _dragOcrHandle(isStart == (_ocrA <= _ocrB), d.globalPosition),
            onPanEnd: (_) => setState(() => _draggingHandle = false),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Transform.flip(
                flipX: isStart != rtl,
                child: SelectionHandle(color: _chrome.strong),
              ),
            ),
          ),
        );

        return Stack(children: [handle(true, startAt), handle(false, endAt)]);
      },
    );
  }

  // قراءة مسبقة: بعد توقف التمرير تُقرأ الصفحة الحالية والتاليتان في الخلفية،
  // فيكون التحديد في الصفحات الممسوحة فوريًا غالبًا
  void _schedulePrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || !_controller.isReady) return;
      final pages = _controller.pages;
      final current = _page.value - 1;
      for (var i = current; i <= current + 2 && i < pages.length; i++) {
        if (i >= 0) _scanned.prefetch(pages[i]);
      }
    });
  }

  // ------------------------- القلم: الرسم والكتابة -------------------------

  void _toggleDrawMode() {
    _clearAll();
    _finishNote();
    setState(() {
      _drawMode = !_drawMode;
      _live = null;
      _pointers.clear();
    });
  }

  // الألوان الهادئة من مرجع المستخدم؛ الأول لون الثيم، والرمادي يفتح على الورق الداكن
  List<int> get _inkPalette => [
    _chrome.strong.toARGB32(),
    _darkPaper ? 0xFFE4E3EA : 0xFF4B4955,
    0xFF94A88E,
    0xFFE8A9AE,
    0xFFEBC77A,
  ];

  int get _inkColor => _inkPalette[_inkColorIndex];

  void _paintInk(Canvas canvas, Rect rect, PdfPage page) {
    final index = page.pageNumber - 1;
    final live = _live;
    final strokes = [
      ..._ink.forPage(index),
      if (live != null && live.page == index) live,
    ];
    final notes = _notes.forPage(index);
    if (strokes.isEmpty && notes.isEmpty) return;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    paintStrokes(canvas, rect.size, strokes);
    paintNotes(
      canvas,
      rect.size,
      notes,
      skipId: _editing?.id,
      darkPaper: _darkPaper,
    );
    canvas.restore();
  }

  Offset? _toDoc(Offset local) {
    final inverse = Matrix4.tryInvert(_controller.value);
    return inverse == null ? null : MatrixUtils.transformPoint(inverse, local);
  }

  // بداية إيماءة الإصبعين: نحفظ المصفوفة والمسافة والمركز
  void _beginTransform() {
    final pts = _pointers.values.take(2).toList();
    _focal0 = (pts[0] + pts[1]) / 2;
    _distance0 = math.max(1, (pts[0] - pts[1]).distance);
    _gesture0 = _controller.value.clone();
  }

  // إصبعان: تحريك وتكبير معًا حول مركز الإصبعين
  void _applyTransform() {
    final pts = _pointers.values.take(2).toList();
    final focal = (pts[0] + pts[1]) / 2;
    final scale = (pts[0] - pts[1]).distance / _distance0;
    final m = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-_focal0.dx, -_focal0.dy, 0, 1)
      ..multiply(_gesture0);
    _controller.value = m;
  }

  // الممحاة: 14 بكسل على الشاشة حول الإصبع
  void _eraseAt(Offset local) {
    final doc = _toDoc(local);
    if (doc == null) return;
    final hit = _pagePoint(doc, onlyPage: _erasePage);
    if (hit == null) return;
    _erasePage ??= hit.$1;
    final layouts = _controller.layout.pageLayouts;
    final tolerance = 14 / (layouts[hit.$1].width * _controller.currentZoom);
    if (_ink.eraseAt(hit.$1, hit.$2, tolerance)) _ink.save();
  }

  bool get _typingTool => _tool == InkTool.note || _tool == InkTool.text;

  void _inkDown(PointerDownEvent e) {
    if (!_controller.isReady) return;
    // لمسة على الصفحة والمذكرة مفتوحة: تطويها ولا ترسم
    if (_openCard != null && _pointers.isEmpty) {
      _closeCard();
      _pointers[e.pointer] = e.localPosition;
      _multiTouch = true; // تجاهل بقية هذه اللمسة
      return;
    }
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _multiTouch = false;
      _erasePage = null;
      _downAt = e.localPosition;
      if (_typingTool) return; // يُعالج عند الرفع كلمسة
      if (_tool == InkTool.eraser) {
        _eraseAt(e.localPosition);
        return;
      }
      final doc = _toDoc(e.localPosition);
      final hit = doc == null ? null : _pagePoint(doc);
      if (hit == null) return;
      final pencil = _tool == InkTool.pencil;
      _live = InkStroke(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: hit.$1,
        pencil: pencil,
        color: _inkColor,
        width: _inkWidths[_inkWidth] * (pencil ? 0.8 : 1),
        points: [hit.$2],
      );
      _controller.invalidate();
    } else if (_pointers.length == 2) {
      // إصبع ثانٍ: لا رسم، بل تحريك وزوم
      _multiTouch = true;
      _live = null;
      _beginTransform();
      _controller.invalidate();
    }
  }

  void _inkMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2) {
      _applyTransform();
      return;
    }
    if (_multiTouch || _typingTool) return;
    if (_tool == InkTool.eraser) {
      _eraseAt(e.localPosition);
      return;
    }
    final live = _live;
    final doc = _toDoc(e.localPosition);
    if (live == null || doc == null) return;
    final hit = _pagePoint(doc, onlyPage: live.page);
    if (hit == null) return;
    // نقاط متقاربة جدًا لا تضيف شيئًا
    if ((hit.$2 - live.points.last).distance < 0.0015) return;
    live.points.add(hit.$2);
    _controller.invalidate();
  }

  void _inkUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length >= 2) {
      _beginTransform();
      return;
    }
    if (_pointers.isNotEmpty) return;
    final live = _live;
    _live = null;
    final wasMulti = _multiTouch;
    _multiTouch = false;
    if (wasMulti) return;
    if (live != null) {
      _ink.add(live);
      _ink.save();
      return;
    }
    // لمسة قصيرة بأداة المذكرة أو النص: ملاحظة جديدة أو تعديل موجودة
    final down = _downAt;
    if (_typingTool &&
        down != null &&
        e is PointerUpEvent &&
        (e.localPosition - down).distance < 12) {
      _tapToType(e.localPosition);
    }
  }

  // ------------------------- المذكرة والنص -------------------------

  void _tapToType(Offset local) {
    // لمسة خارج المذكرة المفتوحة تطويها فقط
    if (_openCard != null) {
      _closeCard();
      return;
    }
    // لمسة خارج الملاحظة المفتوحة تنهيها فقط
    if (_editing != null) {
      _finishNote();
      return;
    }
    final doc = _toDoc(local);
    final hit = doc == null ? null : _pagePoint(doc);
    if (hit == null) return;
    final (index, point) = hit;
    final layout = _controller.layout.pageLayouts[index];

    final existing = _notes.hit(index, point, layout.size);
    if (existing != null) {
      _startEditing(existing);
      return;
    }

    // أداة المذكرة: بطاقة جديدة في مكان اللمسة
    if (_tool == InkTool.note) {
      _createCard(index, point);
      return;
    }
    final sticky = _tool == InkTool.note;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final w = sticky ? 0.42 : 0.55;
    final color = _inkColor;
    final note = PageNote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: index,
      // يبدأ الصندوق من مكان اللمسة باتجاه الكتابة
      x: (rtl ? point.dx - w : point.dx).clamp(0.01, 0.99 - w),
      y: (point.dy - 0.012).clamp(0.0, 0.97),
      w: w,
      size: 0.034,
      text: '',
      // المذكرة: خلفية فاتحة من اللون المختار ونص داكن
      bg: sticky
          ? Color.lerp(Color(color), Colors.white, 0.72)!.toARGB32()
          : null,
      color: sticky ? 0xFF2A2830 : color,
    );
    _notes.add(note);
    _startEditing(note);
  }

  void _startEditing(PageNote note) {
    _noteText.text = note.text;
    setState(() => _editing = note);
    _controller.invalidate();
    _noteFocus.requestFocus();
    // بعد ظهور لوحة المفاتيح: تحريك الصفحة إن غطّت الملاحظة
    Future.delayed(const Duration(milliseconds: 400), _keepEditingVisible);
  }

  // الملاحظة الفارغة تُحذف، والباقي يُحفظ
  void _finishNote() {
    final note = _editing;
    if (note == null) return;
    final text = _noteText.text.trimRight();
    if (text.trim().isEmpty) {
      _notes.remove(note);
    } else {
      note.text = text;
      _notes.changed();
    }
    _notes.save();
    _noteFocus.unfocus();
    setState(() => _editing = null);
    if (_controller.isReady) _controller.invalidate();
  }

  // مكان الملاحظة المفتوحة على الشاشة، وحجم الخط بعد الزوم
  ({Rect box, double fontSize, double pageWidth})? _editingGeometry() {
    final note = _editing;
    if (note == null || !_controller.isReady) return null;
    final List<Rect> layouts;
    try {
      layouts = _controller.layout.pageLayouts;
    } catch (_) {
      return null;
    }
    final pr = layouts[note.page];
    final box = noteBox(note, pr.size).shift(pr.topLeft);
    final local = MatrixUtils.transformRect(_controller.value, box);
    final scale = _controller.currentZoom;
    return (
      box: local,
      fontSize: note.size * pr.width * scale,
      pageWidth: pr.width * scale,
    );
  }

  void _keepEditingVisible() {
    if (!mounted) return;
    final g = _editingGeometry();
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (g == null || box == null) return;
    final visible = box.size.height - 12;
    final overflow = g.box.top + g.fontSize * 2.4 - visible;
    if (overflow > 0) {
      _controller.value = Matrix4.translationValues(0, -overflow, 0)
        ..multiply(_controller.value);
    }
  }

  // ارتفاع الصفحة إلى عرضها (لتحويل حركة السحب إلى نسبة من الارتفاع)
  double _pageAspect(int page) {
    final r = _controller.layout.pageLayouts[page];
    return r.height / r.width;
  }

  // صندوق الكتابة في مكان النص نفسه، بنفس الخط والحجم واللون والدوران (مثل العارض
  // القديم): سحب النص بالإصبع يحركه (أكثر من 10 بكسل، وأقل = لمسة للمؤشر)،
  // ومقبض جانبي يغيّر العرض، ودائرة الدوران فوقه.
  Widget _noteEditor() {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _noteText]),
      builder: (context, _) {
        final note = _editing;
        final g = _editingGeometry();
        if (note == null || g == null) return const SizedBox.shrink();
        final c = _chrome;
        final pad = notePadding(g.fontSize);
        note.text = _noteText.text; // للاتجاه والمحاذاة أثناء الكتابة
        final pageHeight = g.pageWidth * _pageAspect(note.page);

        void move(Offset delta) {
          // الحركة على الشاشة ← نسبة من الصفحة (مع الدوران)
          note.x = (note.x + delta.dx / g.pageWidth).clamp(
            -note.w + 0.05,
            0.95,
          );
          note.y = (note.y + delta.dy / pageHeight).clamp(0.0, 0.97);
          setState(() {});
          _controller.invalidate();
        }

        final box = Container(
          width: g.box.width,
          decoration: BoxDecoration(
            color: note.bg == null
                ? null
                : Color(note.bg!).withValues(alpha: note.opacity),
            borderRadius: BorderRadius.circular(g.fontSize * 0.3),
            border: Border.all(color: c.strong, width: 1.4),
          ),
          child: Listener(
            onPointerDown: (e) {
              _textDragStart = e.position;
              _textDragging = false;
            },
            onPointerMove: (e) {
              final start = _textDragStart;
              if (start == null) return;
              if (!_textDragging && (e.position - start).distance > 10) {
                _textDragging = true;
              }
              if (_textDragging) move(e.delta);
            },
            onPointerUp: (_) {
              if (_textDragging) _notes.save();
              _textDragStart = null;
            },
            child: TextField(
              controller: _noteText,
              focusNode: _noteFocus,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              cursorColor: c.strong,
              textDirection: noteDirection(_noteText.text),
              textAlign: noteAlign(note),
              style: noteStyle(note, g.fontSize),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(pad),
              ),
            ),
          ),
        );

        // مقبض العرض على الحافة اليمنى، ودائرة الدوران فوق المنتصف
        final editor = Stack(
          clipBehavior: Clip.none,
          children: [
            box,
            Positioned(
              right: -9,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    note.w = (note.w + d.delta.dx / g.pageWidth).clamp(
                      0.08,
                      1.0,
                    );
                    setState(() {});
                    _controller.invalidate();
                  },
                  onPanEnd: (_) => _notes.save(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 8,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.strong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -38,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    // زاوية الإصبع حول مركز الصندوق
                    final center = g.box.center;
                    final p = d.globalPosition;
                    final stack =
                        _stackKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (stack == null) return;
                    final local = stack.globalToLocal(p);
                    note.rot =
                        math.atan2(local.dy - center.dy, local.dx - center.dx) +
                        math.pi / 2;
                    setState(() {});
                    _controller.invalidate();
                  },
                  onPanEnd: (_) => _notes.save(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.strong, width: 1.6),
                    ),
                    child: Icon(Icons.rotate_right, size: 17, color: c.strong),
                  ),
                ),
              ),
            ),
          ],
        );

        // الصندوق قبل الدوران (مكانه بلا دوران)، والدوران حول مركزه
        final unrotated = g.box;
        return Stack(
          children: [
            Positioned(
              left: unrotated.left,
              top: unrotated.top,
              child: Transform.rotate(
                angle: note.rot,
                alignment: Alignment.center,
                child: editor,
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteEditingNote() {
    final note = _editing;
    if (note == null) return;
    _noteText.clear();
    _finishNote(); // الفارغ يُحذف
  }

  // ------------------------- المذكرات (بطاقات) -------------------------

  // لون البطاقة من الثيم: فاتح على الورق الفاتح، وداكن هادئ على الداكن
  Color get _cardColor => _darkPaper
      ? Color.lerp(StudyTone.tone.mainDark, const Color(0xFF15131B), 0.72)!
      : Color.lerp(StudyTone.tone.main, Colors.white, 0.86)!;

  void _openCardAt(NoteCard card) {
    _finishNote();
    _closeCard();
    _cardText.text = card.text;
    setState(() => _openCard = card);
  }

  // طي البطاقة: حفظ نصها وإخفاؤها (تبقى أيقونتها على الصفحة)
  void _closeCard() {
    final card = _openCard;
    if (card == null) return;
    card.text = _cardText.text.trimRight();
    _cardFocus.unfocus();
    _cardLive = null;
    setState(() => _openCard = null);
    _cards.changed();
    _cards.save();
  }

  void _deleteCard() {
    final card = _openCard;
    if (card == null) return;
    _cardFocus.unfocus();
    setState(() => _openCard = null);
    _cards.remove(card);
    _cards.save();
  }

  void _createCard(int page, Offset point) {
    final card = NoteCard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: page,
      x: point.dx.clamp(0.0, 0.4),
      y: point.dy.clamp(0.0, 0.9),
    );
    _cards.add(card);
    _cards.save();
    _openCardAt(card);
    // المذكرة الجديدة تبدأ بالكتابة
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _cardFocus.requestFocus(),
    );
  }

  // مساحة رسم البطاقة بنسبة ثابتة من عرضها، فتغيير الارتفاع يكشف الرسم أو
  // يخفيه ولا يمطّه (النسبة نفسها التي كانت للبطاقة على الصفحة)
  Size _cardCanvas(NoteCard card, double width) =>
      Size(width, width * card.h / card.w);

  // أيقونات المذكرات المطوية على الصفحات (لمسة تفتحها، وسحبها يحركها)
  Widget _cardIcons() {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _cards]),
      builder: (context, _) {
        if (!_controller.isReady) return const SizedBox.shrink();
        final List<Rect> layouts;
        try {
          layouts = _controller.layout.pageLayouts;
        } catch (_) {
          return const SizedBox.shrink();
        }
        final c = _chrome;
        final size = MediaQuery.sizeOf(context);
        final icons = <Widget>[];
        for (final card in _cards.all) {
          if (card.id == _openCard?.id || card.page >= layouts.length) {
            continue;
          }
          final pr = layouts[card.page];
          final at = MatrixUtils.transformPoint(
            _controller.value,
            Offset(pr.left + card.x * pr.width, pr.top + card.y * pr.height),
          );
          // خارج الشاشة: لا داعي لبنائها
          if (at.dx < -40 ||
              at.dy < -40 ||
              at.dx > size.width + 40 ||
              at.dy > size.height + 40) {
            continue;
          }
          final scaledWidth = pr.width * _controller.currentZoom;
          icons.add(
            Positioned(
              left: at.dx - 6,
              top: at.dy - 6,
              child: Semantics(
                button: true,
                label: AppStrings.of(context).noteTool,
                child: GestureDetector(
                  onTap: () => _openCardAt(card),
                  onPanUpdate: (d) {
                    card.x = (card.x + d.delta.dx / scaledWidth).clamp(
                      0.0,
                      0.97,
                    );
                    card.y =
                        (card.y +
                                d.delta.dy /
                                    (scaledWidth * _pageAspect(card.page)))
                            .clamp(0.0, 0.97);
                    _cards.changed();
                  },
                  onPanEnd: (_) => _cards.save(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.strong,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 8),
                      ],
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.stickyNote,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(children: icons);
      },
    );
  }

  // البطاقة المفتوحة: تكتب فيها بأداة النص أو المذكرة، وترسم بالقلم أو الرصاص،
  // وتمسح بالممحاة. تظهر بعرض الشاشة فوق لوحة المفاتيح مباشرة (جسم Scaffold
  // ينتهي عند لوحة المفاتيح)، ويُغيَّر ارتفاعها بسحب المقبض العلوي.
  Widget _cardView() {
    return ListenableBuilder(
      listenable: _cards,
      builder: (context, _) {
        final card = _openCard;
        if (card == null) return const SizedBox.shrink();
        final c = _chrome;
        final s = AppStrings.of(context);
        final drawing =
            _drawMode &&
            (_tool == InkTool.pen ||
                _tool == InkTool.pencil ||
                _tool == InkTool.eraser);
        const fontSize = 16.0;
        // بلا لوحة مفاتيح: فوق شريط أندرويد
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        final bottomPad = keyboard ? 0.0 : MediaQuery.paddingOf(context).bottom;

        return LayoutBuilder(
          builder: (context, area) {
            const minHeight = 150.0;
            final maxHeight = (area.maxHeight - 24).clamp(
              minHeight,
              double.infinity,
            );
            final height = _cardHeight.clamp(minHeight, maxHeight);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height + bottomPad,
                  child: Material(
                    color: _cardColor,
                    elevation: 14,
                    shadowColor: Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      side: BorderSide(
                        color: c.strong.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPad),
                      child: Column(
                        children: [
                          // مقبض التمديد: سحب للأعلى يكبّرها وللأسفل يصغّرها
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (d) => setState(
                              () => _cardHeight = (height - d.delta.dy).clamp(
                                minHeight,
                                maxHeight,
                              ),
                            ),
                            child: Semantics(
                              label: s.resizeNote,
                              child: SizedBox(
                                height: 22,
                                width: double.infinity,
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: c.strong.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // الرأس: الأيقونة + حذف + طي
                          SizedBox(
                            height: 40,
                            child: Row(
                              children: [
                                const SizedBox(width: 10),
                                AppIcon(
                                  AppIcons.stickyNote,
                                  size: 20,
                                  color: c.strong,
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: s.delete,
                                  onPressed: _deleteCard,
                                  icon: AppIcon(
                                    AppIcons.trash,
                                    size: 19,
                                    color: c.ink,
                                  ),
                                ),
                                IconButton(
                                  tooltip: s.closeNote,
                                  onPressed: _closeCard,
                                  icon: AppIcon(
                                    AppIcons.close,
                                    size: 19,
                                    color: c.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: c.strong.withValues(alpha: 0.25),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final canvas = _cardCanvas(card, box.maxWidth);
                                return Stack(
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    Positioned.fill(
                                      child: TextField(
                                        controller: _cardText,
                                        focusNode: _cardFocus,
                                        readOnly: drawing,
                                        expands: true,
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        cursorColor: c.strong,
                                        textDirection: textDirectionFor(
                                          _cardText.text,
                                        ),
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          height: 1.45,
                                          color: c.ink,
                                        ),
                                        decoration: InputDecoration(
                                          isCollapsed: true,
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.all(
                                            fontSize * 0.6,
                                          ),
                                        ),
                                        onChanged: (v) => card.text = v,
                                      ),
                                    ),
                                    // الرسم داخل البطاقة فوق النص
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      width: canvas.width,
                                      height: canvas.height,
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _CardInkPainter(
                                            strokes: [
                                              ...card.strokes,
                                              ?_cardLive,
                                            ],
                                            version: _cardInkVersion,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (drawing)
                                      Positioned.fill(
                                        child: Listener(
                                          behavior: HitTestBehavior.opaque,
                                          onPointerDown: (e) => _cardDown(
                                            card,
                                            e.localPosition,
                                            canvas,
                                          ),
                                          onPointerMove: (e) => _cardMove(
                                            card,
                                            e.localPosition,
                                            canvas,
                                          ),
                                          onPointerUp: (_) => _cardUp(card),
                                          onPointerCancel: (_) => _cardUp(card),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Offset _inCard(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _cardDown(NoteCard card, Offset local, Size size) {
    final point = _inCard(local, size);
    if (_tool == InkTool.eraser) {
      _cardErase(card, point, size);
      return;
    }
    final pencil = _tool == InkTool.pencil;
    // نفس سماكة الصفحة: السماكة نسبة من عرض البطاقة
    setState(() {
      _cardLive = InkStroke(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: card.page,
        pencil: pencil,
        color: _inkColor,
        width: _inkWidths[_inkWidth] * (pencil ? 0.8 : 1) / card.w,
        points: [point],
      );
    });
  }

  void _cardMove(NoteCard card, Offset local, Size size) {
    final point = _inCard(local, size);
    if (_tool == InkTool.eraser) {
      _cardErase(card, point, size);
      return;
    }
    final live = _cardLive;
    if (live == null) return;
    if ((point - live.points.last).distance < 0.003) return;
    live.points.add(point);
    setState(() => _cardInkVersion++);
  }

  void _cardUp(NoteCard card) {
    final live = _cardLive;
    if (live == null) return;
    card.strokes.add(live);
    setState(() => _cardLive = null);
    _cards.save();
  }

  void _cardErase(NoteCard card, Offset point, Size size) {
    final before = card.strokes.length;
    card.strokes.removeWhere((s) => s.near(point, 14 / size.width));
    if (card.strokes.length != before) {
      setState(() => _cardInkVersion++);
      _cards.save();
    }
  }

  // ------------------------- لوحة القلم -------------------------

  // مقتبسة من مرجع المستخدم: الأدوات بأسمائها، ثم نمط الخط والألوان
  Widget _drawPanel() {
    final s = AppStrings.of(context);
    final c = _chrome;
    final palette = _inkPalette;

    void pick(InkTool t) {
      if (t != _tool) _finishNote();
      setState(() => _tool = t);
    }

    Widget tool(InkTool t, AppIconData icon, String label) {
      final selected = _tool == t;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => pick(t),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 54,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: AppIcon(
                        icon,
                        size: 22,
                        color: selected ? c.strong : c.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.strong : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 1.4, color: c.muted),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.muted,
            ),
          ),
          const SizedBox(width: 5),
          Container(width: 8, height: 1.4, color: c.muted),
        ],
      ),
    );

    Widget widthOption(int i) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _inkWidth = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _inkWidth == i ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: CustomPaint(
            painter: _WavePainter(color: c.ink, width: 3.6 - i * 0.85),
          ),
        ),
      ),
    );

    Widget colorDot(int i) => GestureDetector(
      onTap: () => setState(() => _inkColorIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 30,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _inkColorIndex == i
                ? Color(palette[i]).withValues(alpha: 0.55)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(palette[i]),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _darkPaper ? 0.35 : 0.10),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: c.line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    tool(InkTool.pen, AppIcons.penNib, s.penTool),
                    tool(InkTool.pencil, AppIcons.pencil, s.pencilTool),
                    tool(InkTool.eraser, AppIcons.eraser, s.eraserTool),
                    tool(InkTool.note, AppIcons.stickyNote, s.noteTool),
                    tool(InkTool.text, AppIcons.textTool, s.textTool),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: c.line),
                ),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // نمط الخط: أربع سماكات من الأعرض للأنحف
                      Expanded(
                        flex: 11,
                        child: Column(
                          children: [
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: c.chip,
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: Row(
                                // stretch: بدونه ارتفاع الخيار صفر فلا يستقبل اللمس
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < _inkWidths.length; i++)
                                    widthOption(i),
                                ],
                              ),
                            ),
                            caption(s.lineStyle),
                          ],
                        ),
                      ),
                      VerticalDivider(width: 18, color: c.line),
                      // الألوان
                      Expanded(
                        flex: 10,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 38,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (var i = 0; i < palette.length; i++)
                                    colorDot(i),
                                ],
                              ),
                            ),
                            caption(s.inkColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // لمسة على تحديد محفوظ تختاره، ولمسة على نقطة ملاحظته تفتح تعديلها
  bool _onTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    // لمسة أثناء القراءة والمذكرة مفتوحة: تطويها
    if (_openCard != null && details.type == PdfViewerGeneralTapType.tap) {
      _closeCard();
      return true;
    }
    // الضغطة المطولة: نقرر نحن (صفحة نصية ← تحديد pdfrx، ممسوحة ← OCR)
    if (details.type == PdfViewerGeneralTapType.longPress) {
      _onLongPress(details.documentPosition);
      return true;
    }
    if (details.type == PdfViewerGeneralTapType.tap && _ocrPage != null) {
      _clearOcr();
      return true;
    }
    if (details.type != PdfViewerGeneralTapType.tap || _hasSelection) {
      return false;
    }
    final pos = details.documentPosition;
    final layouts = controller.layout.pageLayouts;
    for (var i = 0; i < layouts.length; i++) {
      final r = layouts[i];
      if (!r.contains(pos)) continue;
      final point = Offset(
        (pos.dx - r.left) / r.width,
        (pos.dy - r.top) / r.height,
      );
      // نقطة الملاحظة: 24 بكسل على الشاشة حولها
      final tolerance = 24 / (r.width * controller.currentZoom);
      for (final m in _marks.forPage(i).reversed) {
        if ((m.note ?? '').isEmpty || m.rects.isEmpty) continue;
        final last = m.rects.last;
        if ((Offset(last.right, last.top) - point).distance < tolerance) {
          _setActive([m]);
          _editNote();
          return true;
        }
      }
      final mark = _marks.hit(i, point);
      if (mark != null) {
        _setActive([mark]);
        return true;
      }
      break;
    }
    if (_active.isNotEmpty) {
      _setActive(const []);
      return true;
    }
    return false;
  }

  Widget _menu() {
    final s = AppStrings.of(context);
    final mark = _active.isEmpty ? null : _active.first;
    return SelectionMenu(
      style: _style,
      color: _color,
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
      onDelete: _deleteMarks,
      onCopy: _copy,
      onNote: _editNote,
      onShare: _showMore,
      onBookmark: _bookmarkText,
      onMore: _showMore,
      dark: _darkPaper,
      surface: _chrome.surface,
      accent: _chrome.strong,
    );
  }

  // القائمة فوق المنطقة [top, bottom] إن وُجد مكان، وإلا تحتها
  Widget _placeMenu(double top, double bottom) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(360.0, box.maxWidth - 24);
        const h = SelectionMenu.height;
        final above = top - h - 14;
        final y = above >= 8 ? above : bottom + 28;
        return Stack(
          children: [
            Positioned(
              left: (box.maxWidth - width) / 2,
              top: y.clamp(8.0, math.max(8.0, box.maxHeight - h - 8)),
              width: width,
              child: _menu(),
            ),
          ],
        );
      },
    );
  }

  // قائمة واحدة في طبقة العارض (لا في قائمة pdfrx، فهي بلا قيود حجم):
  // للنص المحدد الآن، أو للتحديد المحفوظ المختار. مكانها من المستطيلات على الشاشة.
  Widget _overlayMenu() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (!_controller.isReady) return const SizedBox.shrink();

        // (رقم الصفحة من 0، المستطيل نسبة من الصفحة)
        (int, Rect)? first;
        (int, Rect)? last;
        if (_active.isNotEmpty) {
          final m = _active.first;
          if (m.rects.isEmpty) return const SizedBox.shrink();
          first = (m.page, m.rects.first);
          last = (m.page, m.rects.last);
        } else if (_hasOcr) {
          if (_draggingHandle) return const SizedBox.shrink();
          final rects = rectsFor(_ocrWords, _ocrA, _ocrB);
          if (rects.isEmpty) return const SizedBox.shrink();
          first = (_ocrPage!, rects.first);
          last = (_ocrPage!, rects.last);
        } else if (_hasSelection && !_draggingHandle && _selRanges.isNotEmpty) {
          final pages = _controller.pages;
          final a = _selRanges.first;
          final b = _selRanges.last;
          final ra = PdfMarks.lineRects(a, pages[a.pageNumber - 1]);
          final rb = PdfMarks.lineRects(b, pages[b.pageNumber - 1]);
          if (ra.isEmpty || rb.isEmpty) return const SizedBox.shrink();
          first = (a.pageNumber - 1, ra.first);
          last = (b.pageNumber - 1, rb.last);
        }
        if (first == null || last == null) return const SizedBox.shrink();
        // تخطيط الصفحات قد لا يكون جاهزًا بعد أثناء فتح الكتاب
        final List<Rect> layouts;
        try {
          layouts = _controller.layout.pageLayouts;
        } catch (_) {
          return const SizedBox.shrink();
        }
        if (first.$1 >= layouts.length || last.$1 >= layouts.length) {
          return const SizedBox.shrink();
        }

        Rect toLocal((int, Rect) at) {
          final pr = layouts[at.$1];
          final n = at.$2;
          return MatrixUtils.transformRect(
            _controller.value,
            Rect.fromLTRB(
              pr.left + n.left * pr.width,
              pr.top + n.top * pr.height,
              pr.left + n.right * pr.width,
              pr.top + n.bottom * pr.height,
            ),
          );
        }

        return _placeMenu(toLocal(first).top, toLocal(last).bottom);
      },
    );
  }

  // مواضع النص المحدد (تُقرأ بعد كل تغيير في التحديد)
  void _onSelectionChange(PdfTextSelection selection) {
    final has = selection.hasSelectedText;
    if (has && _active.isNotEmpty) _setActive(const []);
    if (!has) {
      if (_hasSelection) {
        setState(() {
          _hasSelection = false;
          _selRanges = const [];
        });
      }
      return;
    }
    _hasSelection = true;
    selection.getSelectedTextRanges().then((ranges) {
      if (!mounted || !_hasSelection) return;
      setState(() => _selRanges = ranges);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = _chrome;
    final paper = _paper;
    final ink = c.ink;

    // زر الرجوع في الهاتف: يلغي التحديد أولًا، ثم يخرج من الكتاب
    final busy =
        _hasSelection ||
        _active.isNotEmpty ||
        _ocrPage != null ||
        _drawMode ||
        _editing != null ||
        _openCard != null;

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_openCard != null) {
          _closeCard();
        } else if (_editing != null) {
          _finishNote();
        } else if (_drawMode) {
          setState(() => _drawMode = false);
        } else {
          _clearAll();
        }
      },
      child: Scaffold(
        backgroundColor: paper,
        appBar: AppBar(
          backgroundColor: paper,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: textDirectionFor(widget.fileName),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          actions: [
            // رقم الصفحة: لمسة تحوله لخانة رقم مباشرة (بلا نافذة)
            if (_pageCount > 1)
              _PageJump(
                page: _page,
                pageCount: _pageCount,
                accent: c.strong,
                tooltip: s.goToPage,
                onGo: (p) {
                  if (_controller.isReady) _controller.goToPage(pageNumber: p);
                },
              ),
            ListenableBuilder(
              listenable: Listenable.merge([_bookmarks, _page]),
              builder: (context, _) {
                final saved =
                    _bookmarks.pageBookmark(widget.fileId, _page.value) != null;
                return IconButton(
                  tooltip: saved ? s.removeBookmark : s.addBookmark,
                  onPressed: _toggleBookmark,
                  icon: AppIcon(
                    saved ? AppIcons.bookmarkSaved : AppIcons.bookmark,
                    size: 23,
                    strokeWidth: 1.9,
                    color: saved ? c.strong : ink,
                  ),
                );
              },
            ),
            // الرسم الحر
            IconButton(
              tooltip: s.drawMode,
              onPressed: _toggleDrawMode,
              icon: AppIcon(
                AppIcons.draw,
                size: 23,
                color: _drawMode ? c.strong : ink,
              ),
            ),
            IconButton(
              tooltip: s.readerSettings,
              onPressed: _openSettings,
              icon: const Icon(Icons.tune),
            ),
            PopupMenuButton<int>(
              tooltip: s.more,
              color: c.surface,
              onSelected: (_) =>
                  Navigator.of(context).pop(OpenClassicViewer(_page.value)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      AppIcon(AppIcons.pen, size: 20, color: c.ink),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          s.classicViewer,
                          style: TextStyle(color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          key: _stackKey,
          children: [
            // تحديد pdfrx بلون الثيم بدل الأزرق
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: c.selection,
                  selectionHandleColor: c.strong,
                ),
              ),
              child: PdfViewer.file(
                widget.filePath,
                controller: _controller,
                initialPageNumber: widget.initialPage ?? 1,
                params: PdfViewerParams(
                  backgroundColor: paper,
                  margin: _margin,
                  pageDropShadow: BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _darkPaper ? 0.4 : 0.10,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  pagePaintCallbacks: [_paintPaper, _paintMarks, _paintInk],
                  onGeneralTap: _onTap,
                  // لا قائمة من pdfrx: قائمتنا في طبقة العارض (_overlayMenu)
                  buildContextMenu: (_, _) => null,
                  textSelectionParams: PdfTextSelectionParams(
                    onTextSelectionChange: _onSelectionChange,
                    // القائمة تختفي أثناء سحب المقبضين حتى لا تغطيهما
                    onSelectionHandlePanStart: (_) =>
                        setState(() => _draggingHandle = true),
                    onSelectionHandlePanEnd: (_) =>
                        setState(() => _draggingHandle = false),
                  ),
                  onViewerReady: (document, controller) {
                    setState(() => _pageCount = document.pages.length);
                    _onPageChanged(controller.pageNumber ?? _page.value);
                  },
                  onPageChanged: _onPageChanged,
                  loadingBannerBuilder: (_, _, _) =>
                      Center(child: CircularProgressIndicator(color: c.strong)),
                  errorBannerBuilder:
                      (context, error, stackTrace, documentRef) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            s.couldNotOpen,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ink, fontSize: 16),
                          ),
                        ),
                      ),
                  // شريط سحب سريع على الطرف للتنقل بين الصفحات
                  viewerOverlayBuilder: (context, size, _) => [
                    PdfViewerScrollThumb(
                      controller: _controller,
                      orientation: ScrollbarOrientation.right,
                      thumbSize: const Size(44, 26),
                      thumbBuilder:
                          (context, thumbSize, pageNumber, controller) =>
                              Container(
                                decoration: BoxDecoration(
                                  color: c.fab,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${pageNumber ?? ''}',
                                  style: TextStyle(
                                    color: c.onFab,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
            // السطوع: طبقة سوداء شفافة لا تلتقط اللمس
            if (_settings.brightness < 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (1 - _settings.brightness) * 0.85,
                    ),
                  ),
                ),
              ),
            // قائمة التحديد: للنص المحدد أو للتحديد المحفوظ المختار
            Positioned.fill(child: _overlayMenu()),
            // مقبضا تحديد الصفحات الممسوحة
            Positioned.fill(child: _ocrHandles()),
            // طبقة الرسم والكتابة: تلتقط اللمس كله في وضع القلم
            if (_drawMode)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _inkDown,
                  onPointerMove: _inkMove,
                  onPointerUp: _inkUp,
                  onPointerCancel: _inkUp,
                ),
              ),
            // المذكرات: أيقوناتها المطوية والبطاقة المفتوحة
            Positioned.fill(child: _cardIcons()),
            if (_openCard != null) Positioned.fill(child: _cardView()),
            // الملاحظة التي تُكتب الآن (فوق طبقة الرسم حتى تستقبل اللمس)
            if (_editing != null) Positioned.fill(child: _noteEditor()),
            // شريط تنسيق النص أسفل الشاشة (فوق لوحة المفاتيح)
            if (_editing != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NoteToolbar(
                  key: ValueKey(_editing!.id),
                  note: _editing!,
                  chrome: _chrome,
                  onChanged: () {
                    setState(() {});
                    _controller.invalidate();
                    _notes.save();
                  },
                  onDelete: _deleteEditingNote,
                  onDone: _finishNote,
                ),
              ),
            // لوحة القلم تحت الشريط العلوي (من زر القلم)
            if (_drawMode)
              Positioned(
                left: 12,
                right: 12,
                top: 6,
                child: Center(child: _drawPanel()),
              ),
          ],
        ),
      ),
    );
  }
}

// نافذة الملاحظة: تملك الـ controller وتتخلص منه في dispose
class _InputDialog extends StatefulWidget {
  const _InputDialog({required this.title, this.confirm, this.initial = ''});

  final String title;
  final String? confirm;
  final String initial;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _input = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _input.text);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _input,
        autofocus: true,
        keyboardType: TextInputType.multiline,
        minLines: 2,
        maxLines: 6,
        textDirection: textDirectionFor(_input.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirm ?? s.go)),
      ],
    );
  }
}

// رقم الصفحة في الشريط: لمسة ← خانة رقم في مكانها مع لوحة الأرقام.
// أرقام صحيحة فقط (لا فاصلة ولا علامة)، و"اذهب" في اللوحة تنقل للصفحة،
// ولمسة خارجها تلغي.
class _PageJump extends StatefulWidget {
  const _PageJump({
    required this.page,
    required this.pageCount,
    required this.accent,
    required this.tooltip,
    required this.onGo,
  });

  final ValueNotifier<int> page;
  final int pageCount;
  final Color accent;
  final String tooltip;
  final ValueChanged<int> onGo;

  @override
  State<_PageJump> createState() => _PageJumpState();
}

class _PageJumpState extends State<_PageJump> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  static const _style = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) setState(() => _editing = false);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _input.text = '${widget.page.value}';
    _input.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _input.text.length,
    );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _submit(String value) {
    final page = int.tryParse(value);
    if (page != null) widget.onGo(page.clamp(1, widget.pageCount));
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final digits = '${widget.pageCount}'.length;

    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            SizedBox(
              width: 14.0 + digits * 10,
              child: TextField(
                controller: _input,
                focusNode: _focus,
                style: _style,
                textAlign: TextAlign.center,
                cursorColor: widget.accent,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(digits),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: widget.accent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: widget.accent, width: 2),
                  ),
                ),
                onSubmitted: _submit,
                onTapOutside: (_) => _focus.unfocus(),
              ),
            ),
            Text(' / ${widget.pageCount}', style: _style),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: widget.page,
      builder: (_, page, _) => Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: _start,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '$page / ${widget.pageCount}',
                  textDirection: TextDirection.ltr,
                  style: _style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// موجة لزر نمط الخط بسماكة معينة
class _WavePainter extends CustomPainter {
  const _WavePainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.5;
    final left = (size.width - w) / 2;
    final y = size.height / 2;
    final path = Path()
      ..moveTo(left, y + 2)
      ..cubicTo(
        left + w * 0.25,
        y - 7,
        left + w * 0.5,
        y + 7,
        left + w * 0.75,
        y,
      )
      ..quadraticBezierTo(left + w * 0.88, y - 4, left + w, y - 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.width != width;
}

// رسم ضربات البطاقة المفتوحة (version يتغير مع كل نقطة لإعادة الرسم)
class _CardInkPainter extends CustomPainter {
  const _CardInkPainter({required this.strokes, required this.version});

  final List<InkStroke> strokes;
  final int version;

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, size, strokes);

  @override
  bool shouldRepaint(_CardInkPainter old) => true;
}
