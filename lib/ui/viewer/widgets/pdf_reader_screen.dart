import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        FilteringTextInputFormatter,
        HapticFeedback,
        LengthLimitingTextInputFormatter;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/bookmarks/bookmark_repository.dart';
import '../../../data/repositories/reader/reader_settings_repository.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../domain/models/reader_settings.dart';
import '../../core/ui/core_ui.dart';
import 'attachment_widgets.dart';
import 'ink_color_wheel.dart';
import 'note_bookmark_dialog.dart';
import 'note_lines_editor.dart';
import 'pdf_attachments.dart';
import 'pdf_export.dart';
import 'pdf_ink.dart';
import 'pdf_marks.dart';
import 'pdf_note_cards.dart';
import 'pdf_notes.dart';
import 'pdf_text_tools.dart';
import 'pdf_scanned_text.dart';
import 'reader_chrome.dart';
import 'reading_wait.dart';
import 'styled_text.dart';
import 'pdf_text_mode.dart';
import 'reader_settings_sheet.dart';
import 'text_marks.dart';

// ------------------------- القراءة الأفقية (صفحة بصفحة) -------------------------
// الصفحات جنبًا إلى جنب بارتفاع واحد، والكتاب العربي يبدأ من اليمين (الصفحة
// التالية على اليسار). دوال عليا ثابتة حتى لا تتغير معاملات العارض في كل بناء.

PdfPageLayout _horizontalLayout(
  List<PdfPage> pages,
  PdfViewerParams params, {
  required bool rtl,
}) {
  final m = params.margin;
  final height = pages.fold(0.0, (h, p) => math.max(h, p.height));
  final rects = <Rect>[];
  var x = m;
  for (final page in pages) {
    final w = page.height <= 0 ? page.width : page.width * height / page.height;
    rects.add(Rect.fromLTWH(x, m, w, height));
    x += w + m * 2;
  }
  final width = x - m;
  return PdfPageLayout(
    pageLayouts: rtl
        ? [
            for (final r in rects)
              Rect.fromLTWH(width - r.right, r.top, r.width, r.height),
          ]
        : rects,
    documentSize: Size(width, height + m * 2),
  );
}

PdfPageLayout _layoutLtr(List<PdfPage> pages, PdfViewerParams params) =>
    _horizontalLayout(pages, params, rtl: false);

PdfPageLayout _layoutRtl(List<PdfPage> pages, PdfViewerParams params) =>
    _horizontalLayout(pages, params, rtl: true);

// يفتح على صفحة كاملة في الشاشة (الافتراضي يملأ الارتفاع فتُقص الصفحة)
double? _fitPageZoom(
  PdfDocument document,
  PdfViewerController controller,
  double fitZoom,
  double coverZoom,
) => fitZoom;

const _horizontalSizing = PdfViewerSizeDelegateProviderLegacy(
  calculateInitialZoom: _fitPageZoom,
);

// الصفحة الحالية في الأفقي: الأقرب لمنتصف الشاشة. تخمين pdfrx يحسبها من
// نسبة التمرير من اليسار، فيعطي الكتاب العربي (الصفحة 1 يمينًا) رقمًا معكوسًا
// (صفحة 117 من 456 ظهرت 340)
int? _pageAtCenter(
  Rect visible,
  List<Rect> pages,
  PdfViewerController controller,
) {
  var best = 1;
  var distance = double.infinity;
  for (var i = 0; i < pages.length; i++) {
    final d = (pages[i].center.dx - visible.center.dx).abs();
    if (d < distance) {
      distance = d;
      best = i + 1;
    }
  }
  return best;
}

// احتكاك الإفلات في InteractiveViewer (الافتراضي). مسافة الانزلاق بعد الإفلات
// بسرعة v (بكسل/ثانية) = v / -ln(drag)، فنعرف أين سيقف قبل أن يقف.
const double _drag = 0.0000135;
double _glideDistance(double velocity) => velocity / -math.log(_drag);

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
    this.openNoteId,
  });

  final int fileId;
  final String fileName;
  final String filePath;
  final int? initialPage;
  final void Function(int page, int count)? onPageChanged;
  // من علامة مذكرة في المكتبة: تُفتح المذكرة بعد الوصول لصفحتها
  final String? openNoteId;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final _controller = PdfViewerController();
  // الصفحات مصغرة كثيرًا (أقل من 60% من ملء العرض): تُرسم بلا ظل
  bool _overview = false;

  void _onViewChanged() {
    if (!_controller.isReady) return;
    final overview = _controller.currentZoom < _controller.coverScale * 0.6;
    if (overview != _overview) setState(() => _overview = overview);
  }

  final _page = ValueNotifier<int>(1);
  // القراءة النصية (النص المستخرج بحجم خط) بدل الصفحات الأصلية
  final _textMode = ValueNotifier<bool>(false);
  final _textReaderKey = GlobalKey<PdfTextReaderState>();
  late final ReaderSettingsRepository _reader;
  late final BookmarkRepository _bookmarks;
  int _pageCount = 0;
  // كتاب عربي (أو عبري): في اسمه حرف من اليمين، فتقليبه الأفقي من اليمين
  late final bool _rtlBook = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]').hasMatch(widget.fileName);
  bool _wasVertical = true; // لاكتشاف تبديل الوضع وإعادة ملاءمة الصفحة
  ReaderMargin _wasMargin = ReaderMargin.standard;
  Size? _viewSize; // لاكتشاف تدوير الجهاز وإعادة الملاءمة
  int _snapFrom = 0; // الصفحة عند بداية السحب (الأفقي)
  double _zoomAtStart = 1; // لمعرفة أن الإيماءة كانت قرصًا (تكبير/تصغير)
  // حدود الزوم في العامودي (تُحسب مرة بعد فتح الكتاب، من عرض الشاشة)
  PdfViewerSizeDelegateProvider? _verticalSizing;
  PdfViewerSizeDelegateProvider? _horizontalZoomOut;

  // حدود التصغير، تُحسب مرة لكل وضع بعد جاهزية العارض: حتى سُدس عرض الشاشة
  // في العامودي، وخُمس الصفحة في الأفقي. الهدف نظرة عامة على صفحات كثيرة
  // لمعرفة أماكن المذكرات (طلب المستخدم 23 أكتوبر). الافتراضي في pdfrx يقف
  // عند ملء العرض أو الصفحة فلا يصغر أكثر.
  void _updateZoomLimits() {
    if (!mounted || !_controller.isReady) return;
    if (_horizontal) {
      if (_horizontalZoomOut != null) return;
      final fit = _controller.alternativeFitScale ?? _controller.minScale;
      setState(
        () => _horizontalZoomOut = PdfViewerSizeDelegateProviderLegacy(
          calculateInitialZoom: _fitPageZoom,
          useAlternativeFitScaleAsMinScale: false,
          minScale: fit / 5,
        ),
      );
    } else {
      if (_verticalSizing != null) return;
      setState(
        () => _verticalSizing = PdfViewerSizeDelegateProviderLegacy(
          useAlternativeFitScaleAsMinScale: false,
          minScale: _controller.coverScale / 6,
        ),
      );
    }
  }

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
  late final PdfAttachments _attachments = PdfAttachments(widget.fileId);
  PageAttachment? _playing; // المقطع الذي يعمل في شريط التشغيل
  // سحب مرفق بضغطة مطولة: مكان الإصبع، ومكان الإمساك داخله، والمذكرة تحته
  PageAttachment? _dragAttach;
  Offset _dragAt = Offset.zero;
  Offset _dragGrab = Offset.zero;
  Offset _dragStart = Offset.zero;
  bool _dragMoved = false;
  NoteCard? _dropCard;
  double _pinchW = 0; // عرض الصورة عند بداية القرص
  final _cardPanelKey =
      GlobalKey(); // المذكرة المفتوحة: يُفلت فيها المرفق أيضًا
  NoteCard? _openCard;
  double? _cardHeight; // ارتفاع المذكرة المفتوحة بعد سحب مقبضها (null = تلقائي)
  bool _cardAutofocus = false; // المذكرة الجديدة تفتح لوحة المفاتيح
  double? _editAnchor; // مكان لمسة إنشاء النص الجديد (نسبة من عرض الصفحة)
  final _toolbarKey = GlobalKey(); // شريط تنسيق النص (لقياس ارتفاعه)
  Matrix4? _editRestore; // العرض قبل تحريكه لإظهار النص الذي يُكتب
  Matrix4? _editShifted; // العرض بعد تحريكنا (إن تغيّر فقد حرّكه المستخدم)
  double _lastInset = 0; // ارتفاع لوحة المفاتيح في آخر بناء
  bool _visibleCheckPending = false;
  final _panelKey = GlobalKey(); // لوحة القلم: المذكرة لا ترتفع فوق أسفلها
  final _noteHintKey = GlobalKey<TooltipState>(); // تلميح علامة المذكرة (مرة)
  bool _bookmarkBusy = false; // نافذة علامة المذكرة مفتوحة
  bool _exporting = false; // نجهّز نسخة للحفظ أو المشاركة
  // ارتفاع قائمة التحديد كما رُسمت (بلا الذيل)، لوضعها فوق النص أو تحته
  double _menuHeight = SelectionMenu.height;
  // تنسيق السطر الذي يُكتب في المذكرة المفتوحة (اللون والعريض والمائل والحجم)
  final _noteLines = NoteLinesController();
  late final Future<void> _cardsLoaded;
  InkStroke? _cardLive;
  int _cardInkVersion = 0;
  final _cardText = TextEditingController();
  bool _drawMode = false;
  InkTool _tool = InkTool.pen;
  int _inkColorIndex =
      1; // الرمادي الداكن (أو الفاتح على الورق الداكن)؛ 5 = لون العجلة
  double _inkSize = 0.45; // شريط السماكة 0..1 ← _inkThickness
  InkLine _inkLine = InkLine.solid;
  InkShape _inkShape = InkShape.rect;
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
  // نص الصفحة بتنسيق على مقاطع (اللون والعريض والمائل والحجم للمحدد أو للكتابة)
  final _noteText = StyledTextController();
  final _noteFocus = FocusNode();

  // السماكة نسبة من عرض الصفحة: من رفيع جدًا 0.0012 إلى عريض جدًا 0.02،
  // والشريط بمنحنى تربيعي فيكون التحكم في السماكات الرفيعة أدق
  double get _inkThickness => 0.0012 + 0.0188 * _inkSize * _inkSize;
  List<TextMark> _active = const [];
  MarkStyle _style = MarkStyle.highlight;
  int _color = markColors.first;
  // نص محدد الآن بمقابض pdfrx (لم يُحفظ بعد)
  bool _hasSelection = false;
  List<PdfPageTextRange> _selRanges = const [];
  bool _draggingHandle = false;

  @override
  void initState() {
    super.initState();
    _reader = context.read<ReaderSettingsRepository>();
    _bookmarks = context.read<BookmarkRepository>();
    _page.value = widget.initialPage ?? 1;
    _reader.addListener(_onReaderChanged);
    _textMode.addListener(_onTextModeChanged);
    _controller.addListener(_onViewChanged);
    _wasMargin = _settings.margin;
    _wasVertical = _settings.vertical;
    // سطر جديد يطيل الصندوق للأسفل: يبقى آخره ظاهرًا فوق لوحة المفاتيح
    _noteText.addListener(() {
      if (_editing == null || _visibleCheckPending) return;
      _visibleCheckPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _visibleCheckPending = false;
        _keepEditingVisible();
      });
    });
    _marks.addListener(_onMarksChanged);
    _ink.addListener(_onMarksChanged);
    _ink.load();
    _notes.addListener(_onMarksChanged);
    _notes.load();
    _cardsLoaded = _cards.load();
    _marks.load();
    _attachments.load();
  }

  // علامة مذكرة من المكتبة: بعد جاهزية العارض والمذكرات تُفتح المذكرة نفسها
  // (العارض فتح على صفحتها بـ initialPage). إن حُذفت تظهر رسالة فقط
  Future<void> _revealNote() async {
    final id = widget.openNoteId;
    if (id == null) return;
    await _cardsLoaded;
    if (!mounted) return;
    final card = _cards.all.where((c) => c.id == id).firstOrNull;
    if (card == null) {
      showAppMessage(context, AppStrings.of(context).noteMissing);
      return;
    }
    _openCardAt(card);
  }

  @override
  void dispose() {
    pdfrxPageColorFilter = null;
    _reader.removeListener(_onReaderChanged);
    _controller.removeListener(_onViewChanged);
    _marks.removeListener(_onMarksChanged);
    _ink.removeListener(_onMarksChanged);
    _ink.dispose();
    _notes.removeListener(_onMarksChanged);
    _notes.dispose();
    _noteText.dispose();
    _noteFocus.dispose();
    _cards.dispose();
    _noteLines.dispose();
    _attachments.dispose();
    _cardText.dispose();
    _marks.dispose();
    _prefetchTimer?.cancel();
    _page.dispose();
    _textMode.dispose();
    super.dispose();
  }

  void _onReaderChanged() {
    if (!mounted) return;
    final page = _page.value;
    final switched = _settings.vertical != _wasVertical;
    _wasVertical = _settings.vertical;
    final marginChanged = _settings.margin != _wasMargin;
    _wasMargin = _settings.margin;
    if (marginChanged && !switched) _refitAfterLayout();
    setState(() {});
    // الألوان مرسومة على الصفحات نفسها، فنعيد رسمها
    if (_controller.isReady) _controller.invalidate();
    // تبديل العامودي/الأفقي: العارض يعيد ترتيب الصفحات في الإطار التالي،
    // ثم نرجع لنفس الصفحة بملاءمتها للوضع الجديد
    if (switched) {
      _clearAll();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!mounted || !_controller.isReady) return;
          _updateZoomLimits();
          _fitPage(page - 1, animate: false);
        });
      });
    }
  }

  ReaderSettings get _settings => _reader.settings;

  bool get _horizontal => !_settings.vertical;

  // الصفحة index كاملة في الشاشة (الأفقي)، أو أعلاها بعرض الشاشة (العامودي)
  void _fitPage(int index, {bool animate = true}) {
    if (!_controller.isReady) return;
    final layouts = _controller.layout.pageLayouts;
    if (index < 0 || index >= layouts.length) return;
    final duration = animate
        ? const Duration(milliseconds: 220)
        : Duration.zero;
    if (_horizontal) {
      _controller.goTo(
        _controller.calcMatrixForRect(layouts[index].inflate(_margin)),
        duration: duration,
      );
    } else {
      _controller.goToPage(pageNumber: index + 1, duration: duration);
    }
  }

  // الصفحة الأقرب أفقيًا لنقطة في المستند
  int _pageNearX(double x) {
    final layouts = _controller.layout.pageLayouts;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < layouts.length; i++) {
      final d = (layouts[i].center.dx - x).abs();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  void _onInteractionStart(ScaleStartDetails details) {
    if (!_controller.isReady) return;
    _zoomAtStart = _controller.currentZoom;
    if (!_horizontal) return;
    _snapFrom = _pageNearX(_controller.visibleRect.center.dx);
  }

  // الحجم الطبيعي في العامودي: الصفحات بعرض الشاشة (مع الهوامش). حوله هامش
  // صغير يرجع إليه تلقائيًا، فلا يبقى زوم مثل 1.01 أو إزاحة جانبية تمنع التمرير
  static const double _naturalBand = 0.08;
  // أقل من هذا = نظرة عامة على صفحات كثيرة (تبقى كما تركها القارئ)
  static const double _overviewBelow = 0.85;

  double get _naturalRatio => _controller.currentZoom / _controller.coverScale;

  bool get _nearNatural {
    if (!_controller.isReady) return false;
    final r = _naturalRatio;
    return r > _overviewBelow && r < 1 + _naturalBand;
  }

  // العامودي بعد الإفلات: قرب الحجم الطبيعي (أو بعد قرص صغّر تحته قليلًا)
  // ترجع الصفحات بعرض الشاشة في منتصفها أفقيًا، والموضع العامودي كما هو.
  // التمرير العادي بالحجم الطبيعي لا يُلمس (يبقى انزلاقه).
  void _settleVertical() {
    if (_horizontal || !_controller.isReady || _drawMode) return;
    if (!_nearNatural) return;
    final natural = _controller.coverScale;
    final zoom = _controller.currentZoom;
    final view = _controller.visibleRect;
    final doc = _controller.layout.documentSize;
    final pinched = (zoom / _zoomAtStart - 1).abs() > 0.002;
    final offCenter = (view.center.dx - doc.width / 2).abs() > 0.5;
    if (!pinched && (zoom / natural - 1).abs() < 0.002 && !offCenter) return;
    scheduleMicrotask(() {
      if (!mounted || _horizontal || !_controller.isReady) return;
      _toNatural(view.center.dy);
    });
  }

  // الحجم الطبيعي حول الموضع العامودي y (في المستند)
  void _toNatural(double y, {bool animate = true}) {
    final natural = _controller.coverScale;
    final doc = _controller.layout.documentSize;
    final viewH = _controller.visibleRect.height * _controller.currentZoom;
    final half = viewH / natural / 2;
    final cy = doc.height <= half * 2
        ? doc.height / 2
        : y.clamp(half, doc.height - half).toDouble();
    _controller.goTo(
      _controller.calcMatrixFor(Offset(doc.width / 2, cy), zoom: natural),
      duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
    );
  }

  // تغيّر مساحة القراءة (تدوير الجهاز، الهوامش): إن كانت الصفحة بحجمها الطبيعي
  // نعيد ملاءمتها بعد أن يعيد العارض الترتيب، فلا تبقى مزاحة
  void _refitAfterLayout() {
    if (!_controller.isReady) return;
    final natural = _horizontal || _nearNatural;
    if (!natural) return;
    final page = _page.value;
    final y =
        _controller.visibleRect.center.dy /
        _controller.layout.documentSize.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!mounted || !_controller.isReady) return;
        if (_horizontal) {
          _fitPage(page - 1, animate: false);
        } else {
          _toNatural(
            y * _controller.layout.documentSize.height,
            animate: false,
          );
        }
      });
    });
  }

  // زوم يعرض الصفحة index كاملة
  double _fitZoomOf(int index) {
    final page = _controller.layout.pageLayouts[index];
    final view = _controller.visibleRect.size * _controller.currentZoom;
    return math.min(
      view.width / (page.width + _margin * 2),
      view.height / (page.height + _margin * 2),
    );
  }

  // بعد الإفلات في الأفقي تستقر صفحة واحدة:
  // - بلا زوم: إفلات سريع أو سحب أكثر من خُمس الصفحة يقلبها، وإلا ترجع.
  // - انتهاء قرص (تكبير/تصغير) قرب حجم الصفحة: ترجع الصفحة كاملة، بلا تقليب.
  // - مكبرة: الانزلاق يكمل داخلها؛ نتوقع أين سيقف، فإن تجاوز حافتها بخُمس
  //   الشاشة يقلب، وإن تجاوزها أقل يقف عند الحافة نفسها (لا بين صفحتين).
  // InteractiveViewer يستدعي هذا قبل أن يبدأ انزلاقه، فالحركة في microtask
  // بعده، وgoTo يوقف الانزلاق ثم يتحرك (كان الانزلاق يلغي حركتنا فتقف الصفحة
  // بين صفحتين، والانتظار حتى ينتهي كان يجعلها "تعلق").
  void _onInteractionEnd(ScaleEndDetails details) {
    if (!_horizontal) {
      _settleVertical();
      return;
    }
    if (!_controller.isReady || _drawMode) return;
    final layouts = _controller.layout.pageLayouts;
    if (layouts.isEmpty) return;
    final from = _snapFrom.clamp(0, layouts.length - 1);
    final page = layouts[from];
    final zoom = _controller.currentZoom;
    final view = _controller.visibleRect;
    final fit = _fitZoomOf(from);
    final zoomed = zoom > fit * 1.08;
    final pinched = (zoom / _zoomAtStart - 1).abs() > 0.02;
    // مصغّرة (نظرة عامة على صفحات كثيرة): تتحرك بحرية بلا استقرار على صفحة
    if (zoom < fit * 0.92) return;
    final v = details.velocity.pixelsPerSecond;

    void settle(void Function() move) => scheduleMicrotask(() {
      if (mounted && _horizontal && _controller.isReady) move();
    });
    int pageTo(int step) =>
        (from + (_rtlBook ? -step : step)).clamp(0, layouts.length - 1);

    if (!zoomed) {
      var step = 0; // +1 الصفحة على يمين الشاشة، -1 على يسارها
      if (!pinched) {
        final dx = view.center.dx - page.center.dx;
        if (v.dx.abs() > 300) {
          step = v.dx < 0 ? 1 : -1;
        } else if (dx.abs() > page.width * 0.2) {
          step = dx > 0 ? 1 : -1;
        }
      }
      settle(() => _fitPage(pageTo(step)));
      return;
    }
    if (pinched) return; // تكبير: يبقى حيث تركه القرص

    // أين سيقف الانزلاق (المحتوى يتبع الإصبع، فالعرض يتحرك عكسه)
    final shift = Offset(_glideDistance(v.dx), _glideDistance(v.dy)) / zoom;
    final end = view.shift(-shift);
    final over = view.width * 0.2;
    if (end.right > page.right + over) {
      settle(() => _fitPage(pageTo(1)));
    } else if (end.left < page.left - over) {
      settle(() => _fitPage(pageTo(-1)));
    } else if (end.right > page.right || end.left < page.left) {
      // يقف عند حافة الصفحة بنفس الزوم، والارتفاع داخل الصفحة
      final x = end.right > page.right
          ? page.right - view.width / 2
          : page.left + view.width / 2;
      final half = view.height / 2;
      final y = view.height >= page.height
          ? page.center.dy
          : end.center.dy.clamp(page.top + half, page.bottom - half);
      settle(
        () => _controller.goTo(
          _controller.calcMatrixFor(Offset(x, y.toDouble()), zoom: zoom),
          duration: const Duration(milliseconds: 180),
        ),
      );
    }
  }

  bool get _darkPaper => _settings.darkPaper;

  // كل ألوان القارئ من مصدر واحد (ReaderPaper.chrome)، وهو نفسه في لوحة الإعدادات
  ReaderChrome get _chrome => _settings.chrome;

  double get _margin => switch (_settings.margin) {
    ReaderMargin.none => 2,
    ReaderMargin.standard => 8,
    ReaderMargin.wide => 22,
  };

  // ألوان الورق على الصفحة نفسها بتحويل خطي دقيق لكل قناة:
  // أبيض الصفحة ← لون الورق، وأسودها ← لون النص (من ReaderPaper، مكان واحد)،
  // أي نص + قيمة × (ورق − نص)، في الفاتح والداكن معًا.
  // المصفوفة تُطبَّق أثناء رسم صورة الصفحة نفسها (pdfrxPageColorFilter في نسخة
  // pdfrx المحلية third_party/pdfrx)، فتكاد لا تكلف شيئًا. كانت طبقة saveLayer
  // لكل صفحة ظاهرة (15.6ms للإطار، وبدونها 2ms)، وقبلها طبقات blend (17ms).
  // الصفحات الممسوحة تمر بنفس التحويل فلا يضيع منها شيء (تتغير الألوان فقط).
  // التحديد والتظليل والقلم تُرسم بعد الصورة فلا يمسها المرشح.
  // على الورق الداكن يُعكس سطوع الصفحة، والعكس وحده يقلب ألوان الصور والرسوم
  // (الأحمر يصير سماويًا). فنسبقه بتدوير الصبغة 180 درجة (مصفوفة تحفظ الرمادي)،
  // فيبقى النص بلون النص بالضبط، وتبقى الصور والرسوم بصبغاتها الأصلية بسطوع
  // معكوس. التحديد والتظليل والقلم لا يمسها المرشح (تُرسم بعد الصورة).
  static const List<double> _hueTurn = [
    -0.574, 1.430, 0.144, //
    0.426, 0.430, 0.144, //
    0.426, 1.430, -0.856, //
  ];

  ColorFilter? _paperFilter() {
    final paper = _settings.paperColor;
    final ink = _settings.inkColor;
    if (paper == Colors.white && ink == Colors.black) return null;
    final turn = _settings.darkPaper;
    // صف القناة at: نص + (ورق − نص) × قيمة القناة (بعد تدوير الصبغة إن كان داكنًا)
    List<double> row(double p, double i, int at) => [
      for (var k = 0; k < 3; k++)
        turn ? (p - i) * _hueTurn[at * 3 + k] : (k == at ? p - i : 0),
      0,
      i * 255,
    ];
    return ColorFilter.matrix([
      ...row(paper.r, ink.r, 0),
      ...row(paper.g, ink.g, 1),
      ...row(paper.b, ink.b, 2),
      0, 0, 0, 1, 0, //
    ]);
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    _page.value = page;
    if (_pageCount > 0) widget.onPageChanged?.call(page, _pageCount);
    _schedulePrefetch();
  }

  // ------------------------- حفظ نسخة / مشاركة نسخة -------------------------

  // نسخة من الكتاب بالتظليل والقلم ونص الصفحة (pdf_export.dart)
  Future<(Uint8List, String)> _buildCopy() async {
    final original = await File(widget.filePath).readAsBytes();
    final pages = <int, PageAnnotations>{
      for (var i = 0; i < _pageCount; i++)
        i: PageAnnotations(
          marks: _marks.forPage(i),
          strokes: _ink.forPage(i),
          notes: _notes.forPage(i),
        ),
    };
    final bytes = await exportAnnotatedPdf(original, pages);
    final base = p.basenameWithoutExtension(widget.fileName);
    return (bytes, '$base.pdf');
  }

  Future<void> _withCopy(
    Future<void> Function(Uint8List bytes, String name) action,
  ) async {
    if (_exporting) return;
    final s = AppStrings.of(context);
    _clearAll();
    setState(() => _exporting = true);
    showAppMessage(context, s.preparingCopy);
    try {
      final (bytes, name) = await _buildCopy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await action(bytes, name);
    } catch (e) {
      if (mounted) showAppMessage(context, '${s.exportFailed}: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveCopy() => _withCopy((bytes, name) async {
    final s = AppStrings.of(context);
    final path = await FilePicker.saveFile(
      dialogTitle: s.saveCopy,
      fileName: name,
      bytes: bytes,
    );
    if (path == null || !mounted) return; // أُلغي
    showAppMessage(context, s.savedSuccessfully);
  });

  Future<void> _shareCopy() {
    // المقاس قبل أي await (نافذة المشاركة على الأجهزة اللوحية)
    final screen = MediaQuery.sizeOf(context);
    final origin = Rect.fromLTWH(screen.width - 56, 0, 56, 56);
    return _withCopy((bytes, name) async {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
          subject: widget.fileName,
          sharePositionOrigin: origin,
        ),
      );
    });
  }

  Future<void> _toggleBookmark() async {
    final s = AppStrings.of(context);
    final added = await _bookmarks.togglePage(widget.fileId, _page.value);
    if (!mounted) return;
    showAppMessage(
      context,
      added ? s.bookmarkAdded : s.bookmarkRemoved,
      leadingImage: added ? owlSaluteImage : null,
    );
  }

  // القراءة النصية: تبدأ من صفحة العارض، والرجوع منها يفتح الصفحة التي وصلها
  void _onTextModeChanged() {
    if (!mounted) return;
    _clearAll();
    setState(() => _drawMode = false);
    if (!_textMode.value) {
      final page = _page.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isReady) {
          _controller.goToPage(pageNumber: page);
        }
      });
    }
  }

  void _openSettings() {
    _clearAll();
    ReaderSettingsSheet.show(context, _reader, _textMode);
  }

  // ------------------------- التحديد والتظليل -------------------------

  // رسم التحديدات المحفوظة فوق الصفحة (بعد لون الورق حتى تبقى ألوانها)،
  // والتحديد النشط (المختار باللمس أو المحفوظ للتو) بإطار أزرق خفيف
  void _paintMarks(Canvas canvas, Rect rect, PdfPage page) {
    final index = page.pageNumber - 1;
    final marks = _marks.forPage(index);
    final focus = [
      for (final m in _active)
        if (m.page == index) ...m.rects,
    ];
    final active = [
      if (_hasOcr && _ocrPage == index) ...rectsFor(_ocrWords, _ocrA, _ocrB),
    ];
    if (marks.isEmpty && active.isEmpty && focus.isEmpty) return;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    MarksPainter(
      marks: marks,
      selection: active.isEmpty ? null : active,
      selectionColor: _chrome.selection,
      focus: focus.isEmpty ? null : focus,
      focusColor: _chrome.strong.withValues(alpha: 0.6),
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
    showAppMessage(
      context,
      AppStrings.of(context).bookmarkAdded,
      leadingImage: owlSaluteImage,
    );
    _clearAll();
  }

  // الملاحظة تحتاج تحديدًا محفوظًا: من نص محدد نظلّله أولًا
  Future<void> _editNote() async {
    final s = AppStrings.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: s.markNoteTitle,
        hint: s.markNoteHint,
        confirm: s.saveNote,
        initial: _active.isEmpty ? '' : (_active.first.note ?? ''),
        chrome: _chrome,
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
    _clearAll();

    // صفحة نصية: تحديد pdfrx العادي
    if (!await _scanned.isScanned(page)) {
      await _selection.selectWord(doc);
      return;
    }

    // ممسوحة: "جارٍ قراءة النص" إن تأخرت القراءة أكثر من لحظة
    if (!mounted) return;
    Timer? message;
    var shown = false;
    if (!_scanned.isReady(index)) {
      message = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        shown = true;
        showReadingWait(context, _chrome);
      });
    }
    final words = await _scanned.words(index, urgent: true);
    message?.cancel();
    if (shown && mounted) hideReadingWait(context);
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
  // فيكون التحديد في الصفحات الممسوحة فوريًا غالبًا. ما بقي في الطابور من
  // مكان سابق يُلغى، فالصفحة البعيدة لا تنتظر صفحات تركها القارئ.
  void _schedulePrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_controller.isReady) return;
      final pages = _controller.pages;
      final current = _page.value - 1;
      _scanned.keepOnly({current, current + 1, current + 2});
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

  // اللون السادس من عجلة الألوان (محفوظ في إعدادات القراءة)
  int? get _wheelColor => _settings.customInkColor;

  int get _inkColor => _inkColorIndex < _inkPalette.length
      ? _inkPalette[_inkColorIndex]
      : (_wheelColor ?? _inkPalette.first);

  Future<void> _pickWheelColor() async {
    final picked = await showInkColorWheel(
      context,
      initial: Color(_wheelColor ?? _inkColor),
      chrome: _chrome,
    );
    if (picked == null || !mounted) return;
    _reader.update(_settings.copyWith(customInkColor: picked.toARGB32()));
    _selectInkColor(_inkPalette.length);
  }

  // اختيار لون من اللوحة: للرسم، وللنص الذي يُكتب الآن على الصفحة، ولنص المذكرة
  // المفتوحة إن كانت الأداة كتابة (شريط النص السفلي بلا ألوان، طلب المستخدم)
  void _selectInkColor(int index) {
    setState(() => _inkColorIndex = index);
    // نص الصفحة: اللون على المحدد فقط، أو على ما سيُكتب بعده
    // (كان note.color = اللون فيتلون الصندوق كله)
    final note = _editing;
    if (note != null) {
      final color = _inkColor;
      _noteText.applyStyle((s) => s.copyWith(color: color));
    }
    // المذكرة: اللون على المحدد فقط، أو على ما سيُكتب بعده إن لم يكن تحديد
    // (كان card.color = اللون فيتلون النص كله، حتى ما كُتب قبل)
    final card = _openCard;
    if (card != null && _typingTool) {
      final color = _inkColor;
      _noteLines.applyStyle((s) => s.copyWith(color: color));
      _cards.save();
    }
  }

  // ضربة جديدة بالأداة والنوع والسماكة الحالية (السماكة نسبة من عرض الصفحة،
  // وفي المذكرة نسبة من عرضها فتُقسم على card.w)
  InkStroke _newStroke(int page, Offset point, {double scale = 1}) {
    final pencil = _tool == InkTool.pencil;
    final shape = _tool == InkTool.shape ? _inkShape : null;
    return InkStroke(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: page,
      pencil: pencil,
      color: _inkColor,
      width: _inkThickness * (pencil ? 0.8 : 1) * scale,
      // السهم شكل مستقل، فلا نضيف له سهمًا ثانيًا
      line: shape == InkShape.arrow && _inkLine == InkLine.arrow
          ? InkLine.solid
          : _inkLine,
      shape: shape,
      points: [point, if (shape != null) point],
    );
  }

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

  // أدوات المرفقات: لمسة على الصفحة تضيف مقطعًا صوتيًا أو صورة في مكانها
  bool get _attachTool => _tool == InkTool.audio || _tool == InkTool.image;

  // أدوات تعمل باللمسة لا بالسحب
  bool get _tapTool => _typingTool || _attachTool;

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
      if (_tapTool) return; // يُعالج عند الرفع كلمسة
      if (_tool == InkTool.eraser) {
        _eraseAt(e.localPosition);
        return;
      }
      final doc = _toDoc(e.localPosition);
      final hit = doc == null ? null : _pagePoint(doc);
      if (hit == null) return;
      _live = _newStroke(hit.$1, hit.$2);
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
    if (_multiTouch || _tapTool) return;
    if (_tool == InkTool.eraser) {
      _eraseAt(e.localPosition);
      return;
    }
    final live = _live;
    final doc = _toDoc(e.localPosition);
    if (live == null || doc == null) return;
    final hit = _pagePoint(doc, onlyPage: live.page);
    if (hit == null) return;
    // الشكل: النقطة الثانية تتبع الإصبع
    if (live.shape != null) {
      live.points.last = hit.$2;
      _controller.invalidate();
      return;
    }
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
      // شكل بلا سحب (لمسة فقط) لا يُحفظ
      if (live.shape != null &&
          (live.points.first - live.points.last).distance < 0.004) {
        _controller.invalidate();
        return;
      }
      _ink.add(live);
      _ink.save();
      return;
    }
    // لمسة قصيرة بأداة المذكرة أو النص: ملاحظة جديدة أو تعديل موجودة
    final down = _downAt;
    if (_tapTool &&
        down != null &&
        e is PointerUpEvent &&
        (e.localPosition - down).distance < 12) {
      _attachTool ? _attachAt(e.localPosition) : _tapToType(e.localPosition);
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
    final (x, w) = _boxFrom(point.dx, rtl);
    final color = _inkColor;
    final note = PageNote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: index,
      // يبدأ الصندوق من مكان اللمسة باتجاه الكتابة
      x: x,
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
    _editAnchor = point.dx;
  }

  // صندوق نص جديد: بدايته (حيث يبدأ المؤشر) في مكان اللمسة، باتجاه الكتابة.
  // إن لم يتسع العرض المعتاد في هذه الجهة يضيق الصندوق ولا يُزاح عن اللمسة
  (double, double) _boxFrom(double anchor, bool rtl) {
    const preferred = 0.55;
    const minimum = 0.18;
    final room = rtl ? anchor - 0.01 : 0.99 - anchor;
    final w = room.clamp(minimum, preferred);
    final x = rtl ? anchor - w : anchor;
    return (x.clamp(0.01, 0.99 - w), w);
  }

  // اتجاه النص الجديد يتبدل مع أول حرف: نقلب الصندوق حول مكان اللمسة حتى يبقى
  // أول النص عندها (ما لم يحركه المستخدم أو يغيّر عرضه)
  void _followDirection(PageNote note, TextDirection dir) {
    final anchor = _editAnchor;
    if (anchor == null) return;
    final (x, w) = _boxFrom(anchor, dir == TextDirection.rtl);
    // يُستدعى أثناء البناء، والنص المفتوح لا يُرسم على الصفحة (skipId)، فلا invalidate
    note.x = x;
    note.w = w;
  }

  void _startEditing(PageNote note) {
    _editAnchor = null;
    // ملاحظة قديمة بلا مقاطع: عريضها ومائلها وخطها تحتها (للصندوق كله) تصير
    // مقطعًا واحدًا بنفس الشكل، فيمكن بعدها تغيير جزء منها دون الباقي
    if (note.runs == null && (note.bold || note.italic || note.underline)) {
      note.runs = Runs.uniform(
        note.text.length,
        RunStyle(
          bold: note.bold,
          italic: note.italic,
          underline: note.underline,
        ),
      );
      note.bold = false;
      note.italic = false;
      note.underline = false;
    }
    _noteText.setStyled(note.text, note.runs ?? Runs.uniform(note.text.length));
    setState(() => _editing = note);
    _controller.invalidate();
    _noteFocus.requestFocus();
    // بعد ظهور لوحة المفاتيح: تحريك الصفحة إن غطّت الملاحظة
    _editRestore = null;
    _editShifted = null;
    // إن كانت لوحة المفاتيح مفتوحة أصلًا؛ وإلا يُستدعى عند تغير ارتفاعها (build)
    WidgetsBinding.instance.addPostFrameCallback((_) => _keepEditingVisible());
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
      note.runs = Runs.fit(_noteText.runs, text.length);
      _notes.changed();
    }
    _notes.save();
    _noteFocus.unfocus();
    setState(() => _editing = null);
    // العرض يرجع كما كان قبل أن نحركه لإظهار النص (إن لم يحركه المستخدم بعدها)
    final restore = _editRestore;
    if (restore != null &&
        _controller.isReady &&
        _editShifted != null &&
        _controller.value == _editShifted) {
      _controller.value = restore;
    }
    _editRestore = null;
    _editShifted = null;
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

  // يُبقي النص الذي يُكتب فوق شريط التنسيق ولوحة المفاتيح: يحرك العرض فقط
  // (مكان النص المحفوظ على الصفحة لا يتغير)، ويحفظ العرض الأصلي ليرجع إليه.
  // يُستدعى بعد أن يتغير ارتفاع لوحة المفاتيح فعلًا وعند كل تغيير في النص،
  // لا بعد مهلة ثابتة (كانت 400ms فتسبق فتح اللوحة فيبقى النص مختفيًا تحتها).
  void _keepEditingVisible() {
    if (!mounted || _editing == null || !_controller.isReady) return;
    final g = _editingGeometry();
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (g == null || stack == null || !stack.hasSize) return;
    // ارتفاع شريط التنسيق الحقيقي (يغطي أسفل العارض فوق لوحة المفاتيح)
    final bar = _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    final barHeight = bar != null && bar.hasSize ? bar.size.height : 0.0;
    final visibleBottom = stack.size.height - barHeight - 12;
    // يكفي أن يظهر أول النص وما بعده بسطرين (الصندوق الطويل يُمرر داخله)
    final wanted = math.min(g.box.bottom, g.box.top + g.fontSize * 4) + 8;
    final overflow = wanted - visibleBottom;
    if (overflow <= 0.5) return;
    _editRestore ??= _controller.value.clone();
    _controller.value = Matrix4.translationValues(0, -overflow, 0)
      ..multiply(_controller.value);
    _editShifted = _controller.value.clone();
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
        if (note == null) return const SizedBox.shrink();
        note.text = _noteText.text; // للاتجاه والمحاذاة أثناء الكتابة
        note.runs = _noteText.runs; // ولقياس الصندوق بالمقاطع
        final direction =
            strongDirection(note.text) ?? Directionality.of(context);
        _followDirection(note, direction);
        final g = _editingGeometry();
        if (g == null) return const SizedBox.shrink();
        final c = _chrome;
        final s = AppStrings.of(context);
        final pad = notePadding(g.fontSize);
        final pageHeight = g.pageWidth * _pageAspect(note.page);

        void move(Offset delta) {
          _editAnchor = null; // حرّكه المستخدم: لا نقلبه بعد الآن
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
              // قبل أول حرف: حسب لغة التطبيق
              textDirection: direction,
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

        // مقبض العرض على الحافة اليمنى، ودائرة الدوران فوق المنتصف، ومقبض الحجم
        // في الزاوية السفلية: سحبه للخارج يكبّر الخط والصندوق معًا وللداخل يصغّرهما.
        //
        // هامش شفاف m حول الصندوق: فلاتر لا يقبل اللمس خارج حدود الويدجت، والمقابض
        // كانت خارج حدوده (الزاوية -16، العرض -9، الدوران -38) فيستجيب جزؤها
        // الداخلي فقط "يشتغل ولا يشتغل" ودائرة الدوران لا تستجيب أبدًا. الهامش
        // نفسه لا يلتقط اللمس (لا شيء فيه)، فلمسة فيه تصل للصفحة كما كانت.
        const m = 44.0;
        final editor = Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(padding: const EdgeInsets.all(m), child: box),
            // مقبض العرض أولًا، فيأتي مقبض الحجم فوقه في الزاوية (كان يغطيه)
            Positioned(
              right: m - 9 - 6,
              top: m,
              bottom: m,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    _editAnchor = null;
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
              right: m - 16 - 6,
              bottom: m - 16 - 6,
              child: Semantics(
                label: s.textSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    _editAnchor = null;
                    final grow = (d.delta.dx + d.delta.dy) / 2;
                    final factor = 1 + grow / math.max(60, g.box.width);
                    final size = (note.size * factor).clamp(0.015, 0.12);
                    final applied = size / note.size;
                    note.size = size;
                    note.w = (note.w * applied).clamp(0.08, 1.0);
                    setState(() {});
                    _controller.invalidate();
                  },
                  onPanEnd: (_) => _notes.save(),
                  // منطقة لمس 46 حول دائرة 22
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.strong, width: 1.6),
                      ),
                      child: Icon(
                        Icons.open_in_full,
                        size: 12,
                        color: c.strong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: m - 38 - 6,
              left: m,
              right: m,
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
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.strong, width: 1.6),
                      ),
                      child: Icon(
                        Icons.rotate_right,
                        size: 17,
                        color: c.strong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        // الصندوق قبل الدوران (مكانه بلا دوران)، والدوران حول مركزه (الهامش
        // متساوٍ من كل جهة فالمركز نفسه)
        final unrotated = g.box;
        return Stack(
          children: [
            Positioned(
              left: unrotated.left - m,
              top: unrotated.top - m,
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
    setState(() {
      _openCard = card;
      _cardAutofocus = false;
    });
    _maybeShowNoteHint();
  }

  // طي البطاقة: حفظ نصها وإخفاؤها (تبقى أيقونتها على الصفحة)
  void _closeCard() {
    final card = _openCard;
    if (card == null) return;
    card.text = _cardText.text.trimRight();
    FocusManager.instance.primaryFocus?.unfocus();
    _cardLive = null;
    setState(() {
      _openCard = null;
      // مقطع من داخل المذكرة يتوقف بطيها
      if (_playing?.noteId == card.id) _playing = null;
    });
    _cards.changed();
    _cards.save();
    // علامتها (إن وُجدت) تتبع نصها الجديد
    _bookmarks.syncNote(
      lectureId: widget.fileId,
      noteId: card.id,
      page: card.page + 1,
      preview: _notePreview(card),
    );
  }

  void _deleteCard() {
    final card = _openCard;
    if (card == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _openCard = null);
    _cards.remove(card);
    _cards.save();
    // المذكرة حُذفت فلا معنى لعلامتها (إزالة العلامة وحدها لا تحذف المذكرة)
    _bookmarks.removeNote(widget.fileId, card.id);
    // مرفقاتها لا تضيع: ترجع إلى الصفحة مكان المذكرة
    setState(() {
      for (final a in _attachments.all) {
        if (a.noteId == card.id) _moveToPage(a, card);
      }
    });
  }

  // ------------------------- مرفقات الصفحات (صوت وصورة) -------------------------

  // لمسة بأداة الصوت أو الصورة: مقطع أو صورة في مكان اللمسة
  Future<void> _attachAt(Offset local) async {
    if (_openCard != null) {
      _closeCard();
      return;
    }
    final doc = _toDoc(local);
    final hit = doc == null ? null : _pagePoint(doc);
    if (hit == null) return;
    final (page, point) = hit;
    if (_tool == InkTool.image) {
      await _addImage(page, point);
    } else {
      await _addAudio(page, point);
    }
  }

  // نسبة ارتفاع الصورة إلى عرضها (لرسمها بلا تمطيط)
  Future<double> _imageAspect(String path) async {
    try {
      final image = await decodeImageFromList(await File(path).readAsBytes());
      final aspect = image.height / image.width;
      image.dispose();
      return aspect;
    } catch (_) {
      return 0.75;
    }
  }

  Future<void> _addImage(int page, Offset point) async {
    final s = AppStrings.of(context);
    final source = await context.read<FilePickerService>().pickImage();
    if (source == null || !mounted) return;
    try {
      final name = await _attachments.importFile(source);
      final aspect = await _imageAspect(source);
      const w = 0.4;
      _attachments.add(
        PageAttachment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          page: page,
          kind: AttachmentKind.image,
          file: name,
          // الصورة متمركزة على اللمسة، داخل الصفحة
          x: (point.dx - w / 2).clamp(0.0, 1 - w),
          y: (point.dy - 0.05).clamp(0.0, 0.95),
          w: w,
          aspect: aspect,
        ),
      );
      await _attachments.save();
    } catch (_) {
      if (mounted) {
        showAppMessage(context, s.attachFailed, tone: MessageTone.error);
      }
    }
  }

  // الصوت: سجّل الآن أو اختر ملفًا من الهاتف
  Future<void> _addAudio(int page, Offset point) async {
    final s = AppStrings.of(context);
    final c = _chrome;
    final choice = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _menuSheet(sheet, [
        ListTile(
          leading: AppIcon(AppIcons.mic, size: 22, color: c.strong),
          title: Text(s.recordAudio, style: TextStyle(color: c.ink)),
          subtitle: Text(s.recordLimit, style: TextStyle(color: c.muted)),
          onTap: () => Navigator.of(sheet).pop(true),
        ),
        ListTile(
          leading: AppIcon(AppIcons.audioFile, size: 22, color: c.strong),
          title: Text(s.chooseAudioFile, style: TextStyle(color: c.ink)),
          onTap: () => Navigator.of(sheet).pop(false),
        ),
      ]),
    );
    if (choice == null || !mounted) return;

    String? name;
    int? durationMs;
    try {
      if (choice) {
        final path = await _attachments.newRecordingPath();
        if (!mounted) return;
        final length = await showRecordSheet(context, chrome: c, path: path);
        if (length == null) return;
        name = p.basename(path);
        durationMs = length.inMilliseconds;
      } else {
        final source = await context.read<FilePickerService>().pickAudio();
        if (source == null) return;
        name = await _attachments.importFile(source);
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(context, s.attachFailed, tone: MessageTone.error);
      }
      return;
    }
    _attachments.add(
      PageAttachment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: page,
        kind: AttachmentKind.audio,
        file: name,
        x: point.dx.clamp(0.0, 0.94),
        y: point.dy.clamp(0.0, 0.96),
        durationMs: durationMs,
      ),
    );
    await _attachments.save();
  }

  // لوحة قائمة صغيرة بألوان القراءة: فوق أزرار أندرويد (شريط الحالة مخفي
  // فالمساحة الآمنة صفر، فنأخذ ارتفاع الأزرار نفسها)، وعلى Material حتى يظهر
  // أثر اللمس في الصفوف (كان DecoratedBox يخفيه)
  Widget _menuSheet(BuildContext sheet, List<Widget> rows) {
    final c = _chrome;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.viewPaddingOf(sheet).bottom,
      ),
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }

  // ضغطة مطولة: حذف (واستبدال للصورة). الممحاة لا تمسها
  Future<void> _attachmentMenu(PageAttachment a) async {
    final s = AppStrings.of(context);
    final c = _chrome;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _menuSheet(sheet, [
        if (a.noteId != null)
          ListTile(
            leading: AppIcon(AppIcons.pageMove, size: 22, color: c.ink),
            title: Text(s.moveToPage, style: TextStyle(color: c.ink)),
            onTap: () => Navigator.of(sheet).pop('page'),
          ),
        if (!a.isAudio)
          ListTile(
            leading: AppIcon(AppIcons.imageAdd, size: 22, color: c.ink),
            title: Text(s.replaceImage, style: TextStyle(color: c.ink)),
            onTap: () => Navigator.of(sheet).pop('replace'),
          ),
        ListTile(
          leading: AppIcon(AppIcons.trash, size: 22, color: AppColors.red),
          title: Text(s.delete, style: TextStyle(color: AppColors.red)),
          onTap: () => Navigator.of(sheet).pop('delete'),
        ),
      ]),
    );
    if (!mounted) return;
    if (action == 'page') {
      final card = _cards.all.where((x) => x.id == a.noteId).firstOrNull;
      setState(() => _moveToPage(a, card));
    } else if (action == 'delete') {
      if (_playing?.id == a.id) setState(() => _playing = null);
      await _attachments.remove(a);
    } else if (action == 'replace') {
      final source = await context.read<FilePickerService>().pickImage();
      if (source == null || !mounted) return;
      try {
        final name = await _attachments.importFile(source);
        await _attachments.replaceFile(a, name, await _imageAspect(source));
      } catch (_) {
        if (mounted) {
          showAppMessage(context, s.attachFailed, tone: MessageTone.error);
        }
      }
    }
  }

  // شريط مرفقات المذكرة تحت رأسها: صور مصغرة ومقاطع بمددها. لمسة: الصورة بملء
  // الشاشة أو تشغيل المقطع، ضغطة مطولة: قائمته (إرجاعه للصفحة أو حذفه)
  Widget? _noteAttachmentStrip(NoteCard card) {
    final items = [
      for (final a in _attachments.all)
        if (a.noteId == card.id) a,
    ];
    if (items.isEmpty) return null;
    final c = _chrome;
    final s = AppStrings.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget tile(PageAttachment a) {
      final path = _attachments.pathOf(a);
      final playing = _playing?.id == a.id;
      final Widget body = a.isAudio
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: playing ? c.strong : c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.strong.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIcons.mic,
                    size: 18,
                    color: playing ? Colors.white : c.strong,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    a.durationMs == null
                        ? s.audioClip
                        : formatClip(Duration(milliseconds: a.durationMs!)),
                    style: TextStyle(
                      color: playing ? Colors.white : c.ink,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                child: path == null
                    ? ColoredBox(color: c.chip)
                    : Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: (52 * dpr).round(),
                        errorBuilder: (_, _, _) => ColoredBox(color: c.chip),
                      ),
              ),
            );
      return Semantics(
        button: true,
        label: a.isAudio ? s.audioClip : s.imageTool,
        child: GestureDetector(
          onTap: () {
            if (a.isAudio) {
              setState(() => _playing = a);
            } else if (path != null) {
              showImageFullScreen(context, path);
            }
          },
          onLongPress: () => _attachmentMenu(a),
          child: body,
        ),
      );
    }

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => tile(items[i]),
      ),
    );
  }

  // إرجاع مرفق من مذكرة إلى الصفحة بجانب أيقونتها
  void _moveToPage(PageAttachment a, NoteCard? card) {
    a.noteId = null;
    if (card != null) {
      a.page = card.page;
      a.x = (card.x + 0.06).clamp(0.0, 0.9);
      a.y = card.y.clamp(0.0, 0.95);
    }
    if (_playing?.id == a.id) _playing = null;
    _attachments.changed();
    _attachments.save();
  }

  // ---- سحب أيقونة أو مرفق عبر الصفحات ----
  // مكان العنصر في المستند كله أثناء السحب (بلا حصر في صفحة)، فيُعرف من
  // مجموع الحركة أي صفحة صار فوقها
  Offset? _dragDoc;

  Offset _docOf(int page, double x, double y) {
    final pr = _controller.layout.pageLayouts[page];
    return Offset(pr.left + x * pr.width, pr.top + y * pr.height);
  }

  // يضيف حركة الإصبع (بكسل الشاشة) ويرجع الصفحة والمكان النسبي فيها: الصفحة
  // التي تحتوي النقطة، وفي الفراغ بين صفحتين أقربهما
  ({int page, double x, double y})? _followDrag(Offset screenDelta) {
    final start = _dragDoc;
    if (start == null || !_controller.isReady) return null;
    final doc = start + screenDelta / _controller.currentZoom;
    _dragDoc = doc;
    final layouts = _controller.layout.pageLayouts;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < layouts.length; i++) {
      final r = layouts[i];
      final dx = doc.dx < r.left
          ? r.left - doc.dx
          : math.max(0.0, doc.dx - r.right);
      final dy = doc.dy < r.top
          ? r.top - doc.dy
          : math.max(0.0, doc.dy - r.bottom);
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
        if (distance == 0) break;
      }
    }
    final r = layouts[best];
    return (
      page: best,
      x: ((doc.dx - r.left) / r.width).clamp(0.0, 0.97),
      y: ((doc.dy - r.top) / r.height).clamp(0.0, 0.97),
    );
  }

  bool _inExistingNote(PageAttachment a) =>
      a.noteId != null && _cards.all.any((c) => c.id == a.noteId);

  // مكان لمسة من الشاشة إلى طبقة العارض
  Offset? _toStack(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  // المذكرة المفتوحة إن كانت النقطة فوق لوحتها (بإحداثيات طبقة العارض)
  NoteCard? _overOpenCard(Offset local) {
    final card = _openCard;
    final panel =
        _cardPanelKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (card == null || panel == null || stack == null || !panel.hasSize) {
      return null;
    }
    final topLeft = stack.globalToLocal(panel.localToGlobal(Offset.zero));
    return (topLeft & panel.size).contains(local) ? card : null;
  }

  // أيقونة مذكرة مطوية تحت نقطة (لإسقاط مرفق فيها)، بمساحة لمس سخية
  NoteCard? _cardIconAt(Offset local) {
    if (!_controller.isReady) return null;
    final List<Rect> layouts;
    try {
      layouts = _controller.layout.pageLayouts;
    } catch (_) {
      return null;
    }
    for (final card in _cards.all) {
      if (card.id == _openCard?.id || card.page >= layouts.length) continue;
      final pr = layouts[card.page];
      final at = MatrixUtils.transformPoint(
        _controller.value,
        Offset(pr.left + card.x * pr.width, pr.top + card.y * pr.height),
      );
      if (Rect.fromLTWH(at.dx - 18, at.dy - 18, 62, 62).contains(local)) {
        return card;
      }
    }
    return null;
  }

  // إصبع واحد على مرفق خارج وضع القلم: يمرر الصفحة كأن المرفق ليس هنا
  void _scrollBy(Offset delta) {
    _controller.value = Matrix4.translationValues(delta.dx, delta.dy, 0)
      ..multiply(_controller.value);
  }

  void _startAttachDrag(PageAttachment a, Offset global, Offset topLeft) {
    final local = _toStack(global);
    if (local == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dragAttach = a;
      _dragStart = local;
      _dragAt = local;
      _dragGrab = local - topLeft;
      _dragMoved = false;
      _dropCard = null;
    });
  }

  void _moveAttachDrag(Offset global) {
    final local = _toStack(global);
    if (local == null || _dragAttach == null) return;
    setState(() {
      _dragAt = local;
      if ((local - _dragStart).distance > 10) _dragMoved = true;
      // المذكرة المفتوحة أسفل الشاشة أولًا، ثم أيقونات المذكرات المطوية
      _dropCard = _dragMoved
          ? (_overOpenCard(local) ?? _cardIconAt(local))
          : null;
    });
  }

  // الإفلات: على أيقونة مذكرة ← داخلها، أو في مكان آخر ← ينتقل إليه،
  // وبلا حركة ← قائمة المرفق
  Future<void> _endAttachDrag() async {
    final a = _dragAttach;
    if (a == null) return;
    final moved = _dragMoved;
    final card = _dropCard;
    final topLeft = _dragAt - _dragGrab;
    setState(() {
      _dragAttach = null;
      _dropCard = null;
    });
    if (!moved) {
      await _attachmentMenu(a);
      return;
    }
    if (card != null) {
      a.noteId = card.id;
      a.page = card.page;
      HapticFeedback.mediumImpact();
    } else {
      final doc = _toDoc(topLeft);
      final hit = doc == null ? null : _pagePoint(doc);
      if (hit == null) return;
      a.page = hit.$1;
      a.x = hit.$2.dx.clamp(0.0, 0.97);
      a.y = hit.$2.dy.clamp(0.0, 0.97);
    }
    _attachments.changed();
    await _attachments.save();
  }

  // المرفقات فوق الصفحات، تتحرك وتكبر معها. لمسة: الصورة بملء الشاشة أو
  // تشغيل المقطع. إصبعان على الصورة: تكبيرها وتصغيرها في أي وقت. ضغطة مطولة
  // ثم سحب: إلى أيقونة مذكرة (داخلها) أو إلى مكان آخر، وبلا سحب: القائمة.
  // إصبع واحد: في وضع القلم يحركه، وخارجه يمرر الصفحة كالعادة
  Widget _attachmentLayer() {
    return ListenableBuilder(
      // _cards: حذف مذكرة يُظهر مرفقاتها اليتيمة فورًا
      listenable: Listenable.merge([_controller, _attachments, _cards]),
      builder: (context, _) {
        if (!_controller.isReady || _attachments.all.isEmpty) {
          return const SizedBox.shrink();
        }
        final List<Rect> layouts;
        try {
          layouts = _controller.layout.pageLayouts;
        } catch (_) {
          return const SizedBox.shrink();
        }
        final c = _chrome;
        final s = AppStrings.of(context);
        final screen = MediaQuery.sizeOf(context);
        final zoom = _controller.currentZoom;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final items = <Widget>[];

        for (final a in _attachments.all) {
          // داخل مذكرة موجودة: يظهر في شريطها لا هنا. مذكرته لم تعد موجودة
          // (حُذفت من العارض القديم مثلًا): يظهر على الصفحة حتى لا يضيع
          if (_inExistingNote(a) || a.page >= layouts.length) continue;
          final pr = layouts[a.page];
          final scaledWidth = pr.width * zoom;
          final at = MatrixUtils.transformPoint(
            _controller.value,
            Offset(pr.left + a.x * pr.width, pr.top + a.y * pr.height),
          );
          final w = a.isAudio ? 40.0 : a.w * scaledWidth;
          final h = a.isAudio ? 40.0 : w * a.aspect;
          final dragging = _dragAttach?.id == a.id;
          // أثناء السحب يتبع الإصبع
          final topLeft = dragging ? _dragAt - _dragGrab : at;
          // خارج الشاشة: لا داعي لبنائه
          if (!dragging &&
              (at.dx > screen.width ||
                  at.dy > screen.height ||
                  at.dx + w < 0 ||
                  at.dy + h < 0)) {
            continue;
          }

          final path = _attachments.pathOf(a);
          final Widget body;
          if (a.isAudio) {
            final playing = _playing?.id == a.id;
            body = Container(
              decoration: BoxDecoration(
                color: playing ? c.strong : c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.strong, width: 1.6),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 8),
                ],
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.mic,
                  size: 20,
                  color: playing ? Colors.white : c.strong,
                ),
              ),
            );
          } else {
            body = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: path == null
                        ? ColoredBox(color: c.chip)
                        : Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            cacheWidth: (w * dpr).round().clamp(64, 2048),
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: c.chip,
                              child: Center(
                                child: AppIcon(
                                  AppIcons.image,
                                  size: 24,
                                  color: c.muted,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                // مقبض الحجم في وضع القلم (والقرص بإصبعين في أي وقت)، داخل
                // حدود الصورة: خارجها لا يقبل فلاتر اللمس (كان -14 فنصفه ميت)
                if (_drawMode && !dragging)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) {
                        final grow = (d.delta.dx + d.delta.dy) / 2;
                        a.w = (a.w + grow / scaledWidth).clamp(0.08, 1.0);
                        _attachments.changed();
                      },
                      onPanEnd: (_) => _attachments.save(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.strong, width: 1.6),
                          ),
                          child: Icon(
                            Icons.open_in_full,
                            size: 12,
                            color: c.strong,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          items.add(
            Positioned(
              left: topLeft.dx,
              top: topLeft.dy,
              width: w,
              height: h,
              child: Semantics(
                button: true,
                label: a.isAudio ? s.audioClip : s.imageTool,
                child: GestureDetector(
                  onTap: () {
                    if (a.isAudio) {
                      setState(() => _playing = a);
                    } else if (path != null) {
                      showImageFullScreen(context, path);
                    }
                  },
                  onLongPressStart: (d) =>
                      _startAttachDrag(a, d.globalPosition, at),
                  onLongPressMoveUpdate: (d) =>
                      _moveAttachDrag(d.globalPosition),
                  onLongPressEnd: (_) => _endAttachDrag(),
                  onScaleStart: (_) {
                    _pinchW = a.w;
                    _dragDoc = _docOf(a.page, a.x, a.y);
                  },
                  onScaleUpdate: (d) {
                    if (d.pointerCount >= 2) {
                      // إصبعان: حجم الصورة (الصوت أيقونة ثابتة)
                      if (!a.isAudio) {
                        a.w = (_pinchW * d.scale).clamp(0.08, 1.0);
                        _attachments.changed();
                      }
                    } else if (_drawMode) {
                      // في وضع القلم يتحرك عبر الصفحات كأيقونات المذكرات
                      final hit = _followDrag(d.focalPointDelta);
                      if (hit == null) return;
                      a.page = hit.page;
                      a.x = hit.x;
                      a.y = hit.y;
                      _attachments.changed();
                    } else {
                      _scrollBy(d.focalPointDelta);
                    }
                  },
                  onScaleEnd: (_) {
                    _dragDoc = null;
                    _attachments.save();
                  },
                  child: AnimatedScale(
                    scale: dragging ? 1.06 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: Opacity(opacity: dragging ? 0.85 : 1, child: body),
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, children: items);
      },
    );
  }

  // ------------------------- علامة المذكرة -------------------------

  // بداية نص المذكرة للعلامة (سطر واحد)، وفارغ إن كانت رسمًا فقط
  String _notePreview(NoteCard card) {
    final text = (_openCard?.id == card.id ? _cardText.text : card.text)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  // الاسم المقترح: الاسم الحالي، أو أول سطر في المذكرة
  String _noteSuggestion(NoteCard card) {
    final existing = _bookmarks.noteBookmark(widget.fileId, card.id);
    if (existing?.title case final title?) return title;
    final text = _openCard?.id == card.id ? _cardText.text : card.text;
    final first = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return first.length > 40 ? first.substring(0, 40).trimRight() : first;
  }

  Future<void> _bookmarkNote(NoteCard card) async {
    // لمستان سريعتان كانتا تفتحان نافذتين: واحدة فقط حتى تُغلق
    if (_bookmarkBusy) return;
    _bookmarkBusy = true;
    try {
      await _bookmarkNoteOnce(card);
    } finally {
      _bookmarkBusy = false;
    }
  }

  Future<void> _bookmarkNoteOnce(NoteCard card) async {
    final s = AppStrings.of(context);
    final bookmarked = _bookmarks.noteBookmark(widget.fileId, card.id) != null;
    final action = await showNoteBookmarkDialog(
      context,
      chrome: _chrome,
      suggestion: _noteSuggestion(card),
      bookmarked: bookmarked,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case SaveNoteBookmark(:final title):
        await _bookmarks.saveNote(
          lectureId: widget.fileId,
          noteId: card.id,
          page: card.page + 1,
          preview: _notePreview(card),
          title: title,
        );
        if (mounted) showAppMessage(context, s.noteBookmarkSaved);
      case RemoveNoteBookmark():
        await _bookmarks.removeNote(widget.fileId, card.id);
        if (mounted) showAppMessage(context, s.bookmarkRemoved);
    }
  }

  // أيقونة العلامة في رأس المذكرة: مفرغة، وممتلئة بلون الثيم إن كانت في العلامات،
  // وتكبر قليلًا عند التبدل. أول مرة فقط يظهر تحتها تلميح قصير
  Widget _noteBookmarkButton(NoteCard card) {
    final s = AppStrings.of(context);
    final c = _chrome;
    return ListenableBuilder(
      listenable: _bookmarks,
      builder: (context, _) {
        final saved = _bookmarks.noteBookmark(widget.fileId, card.id) != null;
        return Tooltip(
          key: _noteHintKey,
          message: s.noteBookmarkHint,
          triggerMode: TooltipTriggerMode.manual,
          showDuration: const Duration(seconds: 4),
          preferBelow: true,
          decoration: BoxDecoration(
            color: c.fab,
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(color: c.onFab, fontSize: 12.5),
          child: IconButton(
            tooltip: saved ? s.editNoteBookmark : s.bookmarkNote,
            visualDensity: VisualDensity.compact,
            onPressed: () => _bookmarkNote(card),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: AppIcon(
                saved ? AppIcons.bookmarkSaved : AppIcons.bookmark,
                key: ValueKey(saved),
                size: 19,
                color: saved ? c.strong : c.ink,
              ),
            ),
          ),
        );
      },
    );
  }

  // التلميح مرة واحدة: أول فتح لمذكرة بعد هذه الميزة
  void _maybeShowNoteHint() {
    if (_settings.noteBookmarkHintSeen) return;
    _reader.update(_settings.copyWith(noteBookmarkHintSeen: true));
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _openCard != null) {
        _noteHintKey.currentState?.ensureTooltipVisible();
      }
    });
  }

  void _createCard(int page, Offset point) {
    final card = NoteCard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: page,
      // أيقونتها في مكان اللمسة. كان x محصورًا في 0.4 لأن المذكرة كانت تُفتح على
      // الصفحة بعرض 0.6، وهي الآن تُفتح فوق لوحة المفاتيح فلا حاجة له
      x: point.dx.clamp(0.0, 0.97),
      y: point.dy.clamp(0.0, 0.97),
    );
    _cards.add(card);
    _cards.save();
    _openCardAt(card);
    // المذكرة الجديدة تبدأ بالكتابة
    setState(() => _cardAutofocus = true);
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
          icons.add(
            Positioned(
              left: at.dx - 6,
              top: at.dy - 6,
              child: Semantics(
                button: true,
                label: AppStrings.of(context).noteTool,
                child: GestureDetector(
                  onTap: () => _openCardAt(card),
                  // السحب يتبع الإصبع في المستند كله، فتنتقل إلى الصفحة التي
                  // فوقها أو تحتها (كان x وy محصورين في صفحتها فتقف عند حافتها)
                  onPanStart: (_) =>
                      _dragDoc = _docOf(card.page, card.x, card.y),
                  onPanUpdate: (d) {
                    final hit = _followDrag(d.delta);
                    if (hit == null) return;
                    card.page = hit.page;
                    card.x = hit.x;
                    card.y = hit.y;
                    _cards.changed();
                  },
                  onPanEnd: (_) {
                    _dragDoc = null;
                    _cards.save();
                    // علامتها (إن وُجدت) تفتح على صفحتها الجديدة
                    _bookmarks.syncNote(
                      lectureId: widget.fileId,
                      noteId: card.id,
                      page: card.page + 1,
                      preview: _notePreview(card),
                    );
                  },
                  // مرفق مسحوب فوقها: تكبر قليلًا بحلقة حتى يُفلت فيها
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 38,
                    height: 38,
                    transform: card.id == _dropCard?.id
                        ? (Matrix4.identity()..scaleByDouble(1.25, 1.25, 1, 1))
                        : Matrix4.identity(),
                    transformAlignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.strong,
                      borderRadius: BorderRadius.circular(12),
                      border: card.id == _dropCard?.id
                          ? Border.all(color: c.surface, width: 2.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: card.id == _dropCard?.id
                              ? c.strong.withValues(alpha: 0.6)
                              : const Color(0x33000000),
                          blurRadius: card.id == _dropCard?.id ? 16 : 8,
                        ),
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
      listenable: Listenable.merge([_cards, _attachments]),
      builder: (context, _) {
        final card = _openCard;
        if (card == null) return const SizedBox.shrink();
        final c = _chrome;
        final s = AppStrings.of(context);
        final drawing =
            _drawMode &&
            (_tool == InkTool.pen ||
                _tool == InkTool.pencil ||
                _tool == InkTool.shape ||
                _tool == InkTool.eraser);
        const fontSize = 16.0;
        // بلا لوحة مفاتيح: فوق شريط أندرويد
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        final bottomPad = keyboard ? 0.0 : MediaQuery.paddingOf(context).bottom;

        return LayoutBuilder(
          builder: (context, area) {
            const minHeight = 150.0;
            // أعلى المذكرة تحت لوحة القلم إن كانت ظاهرة (مقاسها من آخر إطار)
            final panel =
                _panelKey.currentContext?.findRenderObject() as RenderBox?;
            final measured = panel != null && panel.hasSize;
            // المقاس من الإطار السابق، واللوحة يتغير ارتفاعها مع الأداة (القلم
            // يضيف نوع الخط والسماكة فكانت تغطي رأس المذكرة). بعد كل إطار:
            // إن تغير ارتفاعها عما بُني به نعيد البناء بالمقاس الجديد (يستقر
            // فورًا لأن البناء التالي يطابقه)
            final usedHeight = _drawMode && measured ? panel.size.height : -1.0;
            if (_drawMode) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_drawMode) return;
                final now =
                    _panelKey.currentContext?.findRenderObject() as RenderBox?;
                if (now != null &&
                    now.hasSize &&
                    now.size.height != usedHeight) {
                  setState(() {});
                }
              });
            }
            final panelBottom = _drawMode && measured
                ? 6 + panel.size.height + 8
                : 24.0;
            // الصندوق يُرسم بارتفاع height + bottomPad (فوق أزرار أندرويد بلا
            // لوحة مفاتيح)، فيُطرح bottomPad هنا وإلا علا فوق اللوحة بمقداره
            final maxHeight = (area.maxHeight - panelBottom - bottomPad).clamp(
              minHeight,
              double.infinity,
            );
            // قبل أي سحب: أغلب المساحة فوق لوحة المفاتيح للكتابة
            final height = (_cardHeight ?? area.maxHeight * 0.7).clamp(
              minHeight,
              maxHeight,
            );
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height + bottomPad,
                  child: Material(
                    key: _cardPanelKey,
                    color: _cardColor,
                    elevation: 14,
                    shadowColor: Colors.black45,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      // مرفق مسحوب فوقها: حد أعرض بلون الثيم حتى يُفلت فيها
                      side: BorderSide(
                        color: _dropCard?.id == card.id
                            ? c.strong
                            : c.strong.withValues(alpha: 0.5),
                        width: _dropCard?.id == card.id ? 3 : 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPad),
                      child: Column(
                        children: [
                          // رأس واحد قصير (مساحة أكبر للكتابة): المقبض في
                          // المنتصف، وسحب الرأس كله للأعلى يكبّرها وللأسفل يصغّرها
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (d) => setState(
                              () => _cardHeight = (height - d.delta.dy).clamp(
                                minHeight,
                                maxHeight,
                              ),
                            ),
                            child: SizedBox(
                              height: 40,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Semantics(
                                    label: s.resizeNote,
                                    child: Container(
                                      width: 40,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: c.strong.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      AppIcon(
                                        AppIcons.stickyNote,
                                        size: 19,
                                        color: c.strong,
                                      ),
                                      const Spacer(),
                                      _noteBookmarkButton(card),
                                      IconButton(
                                        tooltip: s.delete,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _deleteCard,
                                        icon: AppIcon(
                                          AppIcons.trash,
                                          size: 19,
                                          color: c.ink,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: s.closeNote,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _closeCard,
                                        icon: AppIcon(
                                          AppIcons.close,
                                          size: 19,
                                          color: c.ink,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: c.strong.withValues(alpha: 0.25),
                          ),
                          // مرفقات المذكرة (صور ومقاطع) وشريط تشغيل مقطعها
                          ?_noteAttachmentStrip(card),
                          if (_playing case final clip?
                              when clip.noteId == card.id)
                            if (_attachments.pathOf(clip) case final clipPath?)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                                child: AttachmentPlayerBar(
                                  key: ValueKey(clip.id),
                                  path: clipPath,
                                  chrome: c,
                                  onClose: () {
                                    if (mounted) {
                                      setState(() => _playing = null);
                                    }
                                  },
                                ),
                              ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final canvas = _cardCanvas(card, box.maxWidth);
                                return Stack(
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    Positioned.fill(
                                      // كل سطر باتجاهه من أول حرف فيه، ولمسة في
                                      // الفراغ تحت النص تكتب مكانها
                                      child: NoteLinesEditor(
                                        key: ValueKey(card.id),
                                        text: card.text,
                                        runs: card.runs,
                                        controller: _noteLines,
                                        readOnly: drawing,
                                        autofocus: _cardAutofocus,
                                        cursorColor: c.strong,
                                        padding: fontSize * 0.6,
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          height: 1.45,
                                          color: card.color == null
                                              ? c.ink
                                              : Color(card.color!),
                                        ),
                                        onChanged: (v, runs) {
                                          card.text = v;
                                          card.runs = runs;
                                          _cardText.text = v;
                                        },
                                      ),
                                    ),
                                    // الرسم داخل البطاقة فوق النص
                                    // يملأ المذكرة كلها، والنقاط بوحدة canvas
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _CardInkPainter(
                                            strokes: [
                                              ...card.strokes,
                                              ?_cardLive,
                                            ],
                                            unit: canvas,
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
                          // تنسيق الكتابة (فوق لوحة المفاتيح): يظهر في الكتابة فقط
                          if (!drawing) _noteFormatRow(),
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

  // صف تنسيق المذكرة: عريض، مائل، تحته خط، وحجم أصغر/أكبر. يخص المحدد فقط،
  // أو ما سيُكتب بعده إن لم يكن تحديد. الأزرار تُظهر النمط عند المؤشر.
  Widget _noteFormatRow() {
    final c = _chrome;
    final s = AppStrings.of(context);
    return ListenableBuilder(
      listenable: _noteLines,
      builder: (context, _) {
        final active = _noteLines.activeStyle;

        Widget toggle(
          IconData icon,
          String label,
          bool on,
          RunStyle Function(RunStyle) change,
        ) => Semantics(
          button: true,
          toggled: on,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _noteLines.applyStyle(change),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 44,
              height: 38,
              decoration: BoxDecoration(
                color: on ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: on ? c.strong : c.ink),
            ),
          ),
        );

        // الحجم نسبة من الخط الأساسي، بخطوات، بين 0.6 و2.4
        RunStyle Function(RunStyle) size(double step) =>
            (r) => r.copyWith(scale: (r.scale * step).clamp(0.6, 2.4));

        return Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: c.strong.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // قيمة مطلقة من الحالة الحالية حتى يتطابق كل المحدد
              toggle(
                Icons.format_bold,
                s.formatBold,
                active.bold,
                (r) => r.copyWith(bold: !active.bold),
              ),
              toggle(
                Icons.format_italic,
                s.formatItalic,
                active.italic,
                (r) => r.copyWith(italic: !active.italic),
              ),
              toggle(
                Icons.format_underline,
                s.formatUnderline,
                active.underline,
                (r) => r.copyWith(underline: !active.underline),
              ),
              toggle(Icons.text_decrease, s.smallerText, false, size(1 / 1.15)),
              toggle(Icons.text_increase, s.largerText, false, size(1.15)),
            ],
          ),
        );
      },
    );
  }

  // نسبة من مساحة الرسم؛ الارتفاع بلا حد أعلى (كان 1 فيتوقف الرسم عند خط
  // ثابت مهما طالت المذكرة)
  Offset _inCard(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    math.max(0.0, local.dy / size.height),
  );

  void _cardDown(NoteCard card, Offset local, Size size) {
    final point = _inCard(local, size);
    if (_tool == InkTool.eraser) {
      _cardErase(card, point, size);
      return;
    }
    // نفس سماكة الصفحة: السماكة نسبة من عرض البطاقة
    setState(() => _cardLive = _newStroke(card.page, point, scale: 1 / card.w));
  }

  void _cardMove(NoteCard card, Offset local, Size size) {
    final point = _inCard(local, size);
    if (_tool == InkTool.eraser) {
      _cardErase(card, point, size);
      return;
    }
    final live = _cardLive;
    if (live == null) return;
    if (live.shape != null) {
      live.points.last = point;
    } else {
      if ((point - live.points.last).distance < 0.003) return;
      live.points.add(point);
    }
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
      // الرسم داخل مذكرة مفتوحة: الحقل يصير للقراءة فقط لكنه يبقى مركّزًا
      // فتبقى لوحة المفاتيح تغطي المذكرة، فنغلقها (النص والتنسيق باقيان)
      final drawing =
          t == InkTool.pen ||
          t == InkTool.pencil ||
          t == InkTool.shape ||
          t == InkTool.eraser;
      if (_openCard != null && drawing) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
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
                    width: 40,
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
                      fontSize: 10.5,
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

    // خيار في مجموعة (نوع الخط أو الشكل): رسم صغير يوضحه + اسم للقارئ
    Widget option({
      required bool selected,
      required VoidCallback onTap,
      required String label,
      required InkStroke sample,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected ? c.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: CustomPaint(
              painter: _SamplePainter(
                stroke: sample,
                color: selected ? c.strong : c.ink,
              ),
            ),
          ),
        ),
      ),
    );

    Widget group(List<Widget> children) => Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        // stretch: بدونه ارتفاع الخيار صفر فلا يستقبل اللمس
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    // عينات الرسم بنسب من مربع الخيار (السماكة نسبة من عرضه)
    InkStroke sample({
      InkLine line = InkLine.solid,
      InkShape? shape,
      List<Offset>? points,
    }) => InkStroke(
      id: '',
      page: 0,
      color: 0,
      width: 0.045,
      line: line,
      shape: shape,
      points:
          points ??
          const [
            Offset(0.22, 0.62),
            Offset(0.36, 0.38),
            Offset(0.5, 0.5),
            Offset(0.64, 0.62),
            Offset(0.78, 0.38),
          ],
    );

    Widget colorDot(int i, Color color, {VoidCallback? onTap}) {
      final selected = _inkColorIndex == i;
      return GestureDetector(
        onTap: onTap ?? () => _selectInkColor(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
    }

    // الدائرة السادسة: قوس قزح تفتح العجلة، وبعد الاختيار تأخذ اللون المحفوظ
    // (لمسة عليها وهي مختارة تفتح العجلة من جديد لتغييره)
    final wheelIndex = palette.length;
    final wheel = _wheelColor;
    final wheelDot = Semantics(
      button: true,
      label: s.moreColors,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: wheel == null || _inkColorIndex == wheelIndex
            ? _pickWheelColor
            : () => _selectInkColor(wheelIndex),
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _inkColorIndex == wheelIndex
                  ? c.strong.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFFF5A5A),
                  Color(0xFFFFD84D),
                  Color(0xFF5AD17A),
                  Color(0xFF4DB8FF),
                  Color(0xFF8E6BFF),
                  Color(0xFFFF5AC8),
                  Color(0xFFFF5A5A),
                ],
              ),
            ),
            child: wheel == null
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(wheel),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
          ),
        ),
      ),
    );

    final drawing =
        _tool == InkTool.pen ||
        _tool == InkTool.pencil ||
        _tool == InkTool.shape;
    final compact = _editing != null; // نص على الصفحة يُكتب الآن
    final shapeNames = {
      InkShape.line: s.shapeLine,
      InkShape.arrow: s.shapeArrow,
      InkShape.rect: s.shapeRect,
      InkShape.circle: s.shapeCircle,
    };
    final lineNames = {
      InkLine.solid: s.lineSolid,
      InkLine.dashed: s.lineDashed,
      InkLine.dotted: s.lineDotted,
      InkLine.arrow: s.lineArrow,
    };

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
                // أثناء كتابة نص على الصفحة: الألوان فقط (ما يلزم الكتابة)، فلا
                // تزدحم الشاشة بين اللوحة وشريط التنسيق ولوحة المفاتيح. صف
                // الأدوات يعود بعد الإنهاء
                if (!compact)
                  Row(
                    children: [
                      tool(InkTool.pen, AppIcons.penNib, s.penTool),
                      tool(InkTool.pencil, AppIcons.pencil, s.pencilTool),
                      tool(InkTool.eraser, AppIcons.eraser, s.eraserTool),
                      tool(InkTool.shape, AppIcons.shapes, s.shapeTool),
                      tool(InkTool.note, AppIcons.stickyNote, s.noteTool),
                      tool(InkTool.text, AppIcons.textTool, s.textTool),
                      tool(InkTool.audio, AppIcons.mic, s.audioTool),
                      tool(InkTool.image, AppIcons.image, s.imageTool),
                    ],
                  ),
                // الممحاة بلا خيارات
                if (!compact && _tool != InkTool.eraser && !_attachTool)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: c.line),
                  ),
                // الأشكال: تختار ثم تسحب على الصفحة
                if (_tool == InkTool.shape) ...[
                  group([
                    for (final shape in InkShape.values)
                      option(
                        selected: _inkShape == shape,
                        onTap: () => setState(() => _inkShape = shape),
                        label: shapeNames[shape]!,
                        sample: sample(
                          shape: shape,
                          points: shape == InkShape.circle
                              ? const [Offset(0.32, 0.22), Offset(0.68, 0.78)]
                              : shape == InkShape.rect
                              ? const [Offset(0.28, 0.26), Offset(0.72, 0.74)]
                              : const [Offset(0.26, 0.7), Offset(0.74, 0.3)],
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (drawing) ...[
                  // نوع الخط
                  group([
                    for (final line in InkLine.values)
                      option(
                        selected: _inkLine == line,
                        onTap: () => setState(() => _inkLine = line),
                        label: lineNames[line]!,
                        sample: sample(line: line),
                      ),
                  ]),
                  caption(s.lineStyle),
                  // السماكة بشريط من رفيع جدًا إلى عريض جدًا، ومعاينة حية بجانبه
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c.chip,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: CustomPaint(
                            painter: _SamplePainter(
                              stroke: InkStroke(
                                id: '',
                                page: 0,
                                color: 0,
                                pencil: _tool == InkTool.pencil,
                                // نفس نسبة السماكة إلى عرض صفحة على الهاتف تقريبًا
                                width: _inkThickness * 360 / 64,
                                line: _inkLine,
                                points: const [
                                  Offset(0.16, 0.6),
                                  Offset(0.33, 0.36),
                                  Offset(0.5, 0.5),
                                  Offset(0.67, 0.64),
                                  Offset(0.84, 0.4),
                                ],
                              ),
                              color: Color(_inkColor),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: c.strong,
                              inactiveTrackColor: c.accent,
                              thumbColor: c.strong,
                              overlayColor: c.accent,
                            ),
                            child: Slider(
                              value: _inkSize,
                              onChanged: (v) => setState(() => _inkSize = v),
                              semanticFormatterCallback: (_) => s.thickness,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // الألوان: الخمسة + العجلة
                if (_tool != InkTool.eraser && !_attachTool) ...[
                  SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < palette.length; i++)
                          colorDot(i, Color(palette[i])),
                        wheelDot,
                      ],
                    ),
                  ),
                  caption(s.inkColor),
                ],
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

  Widget _menu({double? tailX, bool tailUp = false}) {
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
      tailX: tailX,
      tailUp: tailUp,
    );
  }

  // القائمة فوق المنطقة [top, bottom] إن وُجد مكان، وإلا تحتها، وذيلها يشير
  // إلى أول سطر (فوق) أو آخر سطر (تحت). topX/bottomX: منتصف السطرين أفقيًا.
  Widget _placeMenu(double top, double bottom, double topX, double bottomX) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(380.0, box.maxWidth - 24);
        // الارتفاع الفعلي من آخر رسم (يزيد مع نص الملاحظة وزر المسح)
        final h = _menuHeight;
        const gap = SelectionMenu.tail + 8;
        // العارض يمتد تحت أزرار أندرويد (شريط الحالة مخفي فالمساحة الآمنة صفر)
        final bottomLimit =
            box.maxHeight - MediaQuery.viewPaddingOf(context).bottom - 8;
        final above = top - h - gap;
        final below = bottom + gap + 18; // 18: مقبضا التحديد
        final isAbove = above >= 8;
        final raw = isAbove ? above : below;
        final y = raw.clamp(8.0, math.max(8.0, bottomLimit - h)).toDouble();
        final left = (box.maxWidth - width) / 2;
        // الذيل فقط إن بقيت القائمة ملاصقة للنص (لم تُزح لحافة الشاشة)
        final anchored = (y - raw).abs() < 1;
        final tailX = ((isAbove ? topX : bottomX) - left)
            .clamp(36.0, width - 36.0)
            .toDouble();
        return Stack(
          children: [
            Positioned(
              left: left,
              top: y,
              width: width,
              child: _MeasureHeight(
                onHeight: (v) {
                  if ((v - _menuHeight).abs() > 0.5) {
                    setState(() => _menuHeight = v);
                  }
                },
                child: _menu(tailX: anchored ? tailX : null, tailUp: !isAbove),
              ),
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

        final a = toLocal(first);
        final b = toLocal(last);
        return _placeMenu(a.top, b.bottom, a.center.dx, b.center.dx);
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
    // خلفية القارئ والشريط العلوي (ليلًا من الثيم، أغمق من الصفحة؛ نهارًا = الورق)
    final paper = c.reader;
    final ink = c.ink;
    final icon = c.icon;
    // ألوان الورق: تُقرأ عند رسم صور الصفحات (_paperFilter)
    pdfrxPageColorFilter = _paperFilter();

    // تدوير الجهاز: الملاءمة تُعاد بعد أن يرتب العارض الصفحات للمقاس الجديد
    final screen = MediaQuery.sizeOf(context);
    if (_viewSize != null && screen != _viewSize) _refitAfterLayout();
    _viewSize = screen;

    // تغيّر ارتفاع لوحة المفاتيح (فُتحت أو اكتمل فتحها): بعد أن يتقلص العارض
    // نتأكد أن النص الذي يُكتب ظاهر فوقها
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _lastInset) {
      final growing = inset > _lastInset;
      _lastInset = inset;
      if (_editing != null && growing) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _keepEditingVisible(),
        );
      }
    }

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
                  if (_textMode.value) {
                    _page.value = p;
                    _textReaderKey.currentState?.jumpToPage(p);
                  } else if (_controller.isReady) {
                    _controller.goToPage(pageNumber: p);
                  }
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
                    color: saved ? c.strong : icon,
                  ),
                );
              },
            ),
            // التبديل بين الصفحات الأصلية والقراءة النصية
            IconButton(
              tooltip: _textMode.value ? s.originalPages : s.textReading,
              onPressed: () => _textMode.value = !_textMode.value,
              icon: AppIcon(
                _textMode.value ? AppIcons.pdfPages : AppIcons.textReading,
                size: 23,
                color: icon,
              ),
            ),
            if (!_textMode.value)
              // الرسم الحر
              IconButton(
                tooltip: s.drawMode,
                onPressed: _toggleDrawMode,
                icon: AppIcon(
                  AppIcons.draw,
                  size: 23,
                  color: _drawMode ? c.strong : icon,
                ),
              ),
            IconButton(
              tooltip: s.readerSettings,
              onPressed: _openSettings,
              icon: Icon(Icons.tune, color: icon),
            ),
            PopupMenuButton<int>(
              tooltip: s.more,
              color: c.surface,
              enabled: !_exporting,
              onSelected: (v) => v == 0 ? _saveCopy() : _shareCopy(),
              itemBuilder: (_) => [
                for (final (v, icon, label) in [
                  (0, AppIcons.saveFile, s.saveCopy),
                  (1, AppIcons.shareFile, s.shareCopy),
                ])
                  PopupMenuItem(
                    value: v,
                    child: Row(
                      children: [
                        AppIcon(icon, size: 20, color: c.ink),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(label, style: TextStyle(color: c.ink)),
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
            // مخفي بنفس مقاسه (Offstage لا يأخذ مساحة فينكمش العارض كله إلى صفر)
            Visibility(
              visible: !_textMode.value,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: Theme(
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
                    // الأفقي: صفحات جنبًا إلى جنب، تفتح على صفحة كاملة، وتستقر
                    // صفحة واحدة بعد كل سحبة
                    layoutPages: _horizontal
                        ? (_rtlBook ? _layoutRtl : _layoutLtr)
                        : null,
                    sizeDelegateProvider: _horizontal
                        ? (_horizontalZoomOut ?? _horizontalSizing)
                        : _verticalSizing,
                    calculateCurrentPageNumber: _horizontal
                        ? _pageAtCenter
                        : null,
                    onInteractionStart: _onInteractionStart,
                    onInteractionEnd: _onInteractionEnd,
                    // بلا ظل والصفحات مصغرة (نظرة عامة): ظل مموّه لكل صفحة من
                    // صفحات كثيرة صغيرة عمل بلا فائدة تُرى
                    pageDropShadow: _overview
                        ? null
                        : BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _darkPaper ? 0.4 : 0.10,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                    pagePaintCallbacks: [_paintMarks, _paintInk],
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
                      _updateZoomLimits();
                      _onPageChanged(controller.pageNumber ?? _page.value);
                      _revealNote();
                    },
                    onPageChanged: _onPageChanged,
                    loadingBannerBuilder: (_, _, _) => Center(
                      child: CircularProgressIndicator(color: c.strong),
                    ),
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
                        orientation: _horizontal
                            ? ScrollbarOrientation.bottom
                            : ScrollbarOrientation.right,
                        // في الأسفل: فوق أزرار أندرويد (العارض يمتد تحتها)
                        margin: _horizontal
                            ? MediaQuery.viewPaddingOf(context).bottom + 4
                            : 2,
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
            ),
            // القراءة النصية فوق العارض (العارض باقٍ مخفيًا فلا يُعاد فتح الكتاب)
            if (_textMode.value)
              Positioned.fill(
                child: ColoredBox(
                  color: paper,
                  child: PdfTextReader(
                    key: _textReaderKey,
                    lectureId: widget.fileId,
                    filePath: widget.filePath,
                    pageCount: math.max(_pageCount, 1),
                    initialPage: _page.value,
                    fontSize: _settings.textFontSize,
                    sidePadding: 14 + _margin,
                    chrome: c,
                    onPageChanged: _onPageChanged,
                    onShowOriginal: (page) {
                      _page.value = page;
                      _textMode.value = false;
                    },
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
            // مقبضا تحديد الصفحات الممسوحة، تحت القائمة (كانا يُرسمان فوقها)
            Positioned.fill(child: _ocrHandles()),
            // قائمة التحديد: للنص المحدد أو للتحديد المحفوظ المختار
            Positioned.fill(child: _overlayMenu()),
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
            // مرفقات الصفحات (صوت وصورة) تحت المذكرة المفتوحة، وفوقها أثناء
            // سحب مرفق حتى يُرى فوق لوحتها. المفتاحان يبقيان الطبقتين نفسيهما
            // عند تبديل الترتيب فلا ينقطع السحب
            if (_dragAttach == null)
              Positioned.fill(
                key: const ValueKey('attachments'),
                child: _attachmentLayer(),
              ),
            if (_openCard != null)
              Positioned.fill(
                key: const ValueKey('openCard'),
                child: _cardView(),
              ),
            if (_dragAttach != null)
              Positioned.fill(
                key: const ValueKey('attachments'),
                child: _attachmentLayer(),
              ),
            // الملاحظة التي تُكتب الآن (فوق طبقة الرسم حتى تستقبل اللمس)
            if (_editing != null) Positioned.fill(child: _noteEditor()),
            // شريط تنسيق النص أسفل الشاشة (فوق لوحة المفاتيح)
            if (_editing != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NoteToolbar(
                  key: _toolbarKey,
                  note: _editing!,
                  text: _noteText,
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
            // شريط تشغيل المقطع الصوتي أسفل العارض (مقاطع المذكرة تعمل داخلها)
            if (_playing case final clip? when !_inExistingNote(clip))
              if (_attachments.pathOf(clip) case final clipPath?)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12 + MediaQuery.paddingOf(context).bottom,
                  child: AttachmentPlayerBar(
                    key: ValueKey(clip.id),
                    path: clipPath,
                    chrome: _chrome,
                    onClose: () {
                      if (mounted) setState(() => _playing = null);
                    },
                  ),
                ),
            // لوحة القلم تحت الشريط العلوي (من زر القلم)، وتبقى أثناء الكتابة في
            // المذكرة حتى يتغير اللون، والمذكرة تقف تحتها (_panelKey)
            if (_drawMode)
              Positioned(
                left: 12,
                right: 12,
                top: 6,
                child: Center(
                  child: KeyedSubtree(key: _panelKey, child: _drawPanel()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// يبلّغ ارتفاع ابنه بعد كل رسم (قائمة التحديد يتغير طولها)
class _MeasureHeight extends StatelessWidget {
  const _MeasureHeight({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final size = context.size;
      if (size != null) onHeight(size.height);
    });
    return child;
  }
}

// نافذة الملاحظة: تملك الـ controller وتتخلص منه في dispose.
// شكلها من مرجع المستخدم (23 أكتوبر): أيقونة | العنوان، خانة كتابة بإطار بلون
// الثيم، وزرا "إلغاء" (إطار) و"حفظ الملاحظة" (ممتلئ). الألوان من واجهة القراءة.
class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.chrome,
    this.hint,
    this.confirm,
    this.initial = '',
  });

  final String title;
  final ReaderChrome chrome;
  final String? hint;
  final String? confirm;
  final String initial;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final _input = TextEditingController(text: widget.initial)
    ..addListener(_onText);
  // الاتجاه من أول حرف، والفارغ بلغة التطبيق
  TextDirection? _direction;

  void _onText() {
    final d = strongDirection(_input.text);
    if (d != _direction) setState(() => _direction = d);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _input.text);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.chrome;
    const radius = 18.0;

    OutlineInputBorder border(double width, double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: c.strong.withValues(alpha: alpha),
        width: width,
      ),
    );

    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIcon(AppIcons.stickyNote, size: 24, color: c.strong),
                Container(
                  width: 1.2,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: c.line,
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _input,
              autofocus: true,
              keyboardType: TextInputType.multiline,
              minLines: 3,
              maxLines: 7,
              cursorColor: c.strong,
              textDirection: _direction ?? Directionality.of(context),
              style: TextStyle(fontSize: 15, color: c.ink, height: 1.45),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: c.muted, fontSize: 14.5),
                filled: true,
                fillColor: c.strong.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: border(1.2, 0.45),
                focusedBorder: border(1.8, 1),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.ink,
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(color: c.ink.withValues(alpha: 0.22)),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(s.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.strong,
                      // الليلي: لون الثيم فاتح فالنص داكن
                      foregroundColor: c.onStrong,
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(widget.confirm ?? s.go),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

// عينة نوع خط أو شكل في لوحة القلم، مرسومة بنفس رسم الصفحة
class _SamplePainter extends CustomPainter {
  const _SamplePainter({required this.stroke, required this.color});

  final InkStroke stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // مربع في منتصف الخيار حتى لا تتمدد الأشكال مع عرضه
    final side = math.min(size.width, size.height * 1.6);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side / 1.6) / 2);
    paintStrokes(canvas, Size(side, side / 1.6), [
      InkStroke(
        id: stroke.id,
        page: 0,
        pencil: stroke.pencil,
        color: color.toARGB32(),
        width: stroke.width,
        line: stroke.line,
        shape: stroke.shape,
        points: stroke.points,
      ),
    ]);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SamplePainter old) =>
      old.color != color ||
      old.stroke.width != stroke.width ||
      old.stroke.line != stroke.line ||
      old.stroke.pencil != stroke.pencil ||
      old.stroke.shape != stroke.shape;
}

// رسم ضربات البطاقة المفتوحة (version يتغير مع كل نقطة لإعادة الرسم)
class _CardInkPainter extends CustomPainter {
  const _CardInkPainter({
    required this.strokes,
    required this.unit,
    required this.version,
  });

  final List<InkStroke> strokes;
  final Size unit; // وحدة النقاط (العرض × نسبة ثابتة)، والرسم يتجاوزها للأسفل
  final int version;

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, unit, strokes);

  @override
  bool shouldRepaint(_CardInkPainter old) => true;
}
