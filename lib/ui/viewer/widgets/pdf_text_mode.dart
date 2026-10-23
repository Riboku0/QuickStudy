import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/ocr_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/themes/app_icons.dart';
import '../../core/ui/app_icon.dart';
import '../../core/ui/core_ui.dart' show textDirectionFor;
import 'reader_chrome.dart';
import 'text_marks.dart';

// نص صفحة جاهز للقراءة النصية: فقرات بترتيب القراءة، وهل جاء من OCR
class PageParagraphs {
  const PageParagraphs(this.paragraphs, {this.ocr = false});

  final List<String> paragraphs;
  final bool ocr;
}

// كلمات الصفحة (مرتبة: الأسطر من الأعلى، والكلمات حسب اتجاه السطر) ← فقرات.
// فقرة جديدة عند: فراغ عامودي أكبر من المعتاد، أو سطر سابق قصير (انتهت الفقرة
// قبل حافة النص)، أو تغيّر اتجاه السطر. رقم الصفحة وحده في أول الصفحة أو
// آخرها يُحذف. الكلمة المقسومة بشرطة في آخر سطر لاتيني تُوصل.
List<String> buildParagraphs(List<PageWord> words) {
  if (words.isEmpty) return const [];
  final lines = <({String text, Rect rect, bool rtl})>[];
  var start = 0;
  for (var i = 1; i <= words.length; i++) {
    if (i < words.length && words[i].line == words[start].line) continue;
    final part = words.sublist(start, i);
    var rect = part.first.rect;
    for (final w in part) {
      rect = rect.expandToInclude(w.rect);
    }
    lines.add((
      text: part.map((w) => w.text).join(' '),
      rect: rect,
      rtl: part.first.rtl,
    ));
    start = i;
  }

  bool pageNumber(String t) => RegExp(r'^[\d٠-٩\s\-–—]+$').hasMatch(t);
  if (lines.length > 1 && pageNumber(lines.first.text)) lines.removeAt(0);
  if (lines.length > 1 && pageNumber(lines.last.text)) lines.removeLast();
  if (lines.isEmpty) return const [];

  final heights = [for (final l in lines) l.rect.height]..sort();
  final lineHeight = heights[heights.length ~/ 2];
  final gaps = [
    for (var i = 1; i < lines.length; i++)
      lines[i].rect.top - lines[i - 1].rect.bottom,
  ]..sort();
  final gap = gaps.isEmpty ? 0.0 : gaps[(gaps.length - 1) ~/ 2];
  var left = 1.0;
  var right = 0.0;
  for (final l in lines) {
    if (l.rect.left < left) left = l.rect.left;
    if (l.rect.right > right) right = l.rect.right;
  }
  final width = right - left;

  final paragraphs = <String>[];
  var current = StringBuffer(lines.first.text);
  for (var i = 1; i < lines.length; i++) {
    final prev = lines[i - 1];
    final line = lines[i];
    final space = line.rect.top - prev.rect.bottom;
    final short = prev.rect.width < width * 0.72;
    final breaks =
        space > gap + lineHeight * 0.6 || short || line.rtl != prev.rtl;
    if (breaks) {
      paragraphs.add(current.toString());
      current = StringBuffer(line.text);
      continue;
    }
    final text = current.toString();
    if (!prev.rtl && text.endsWith('-') && text.length > 1) {
      current = StringBuffer(text.substring(0, text.length - 1))
        ..write(line.text);
    } else {
      current.write(' ');
      current.write(line.text);
    }
  }
  paragraphs.add(current.toString());
  return paragraphs;
}

// القراءة النصية: نص الكتاب بعرض الشاشة وبحجم الخط المختار، صفحة تحت صفحة.
// الصفحة النصية تُستخرج فورًا، والممسوحة بالتعرف الضوئي على الهاتف (OcrService،
// لا رفع لأي خدمة). القائمة تبدأ من صفحة العارض (center)، وعند تغيير الخط
// تُبنى من جديد على الصفحة الظاهرة بنفس النسبة داخلها، فلا يضيع الموضع.
class PdfTextReader extends StatefulWidget {
  const PdfTextReader({
    super.key,
    required this.lectureId,
    required this.filePath,
    required this.pageCount,
    required this.initialPage,
    required this.fontSize,
    required this.sidePadding,
    required this.chrome,
    required this.onPageChanged,
    required this.onShowOriginal,
  });

  final int lectureId;
  final String filePath;
  final int pageCount;
  final int initialPage; // من 1
  final double fontSize;
  final double sidePadding;
  final ReaderChrome chrome;
  final ValueChanged<int> onPageChanged; // من 1
  final ValueChanged<int> onShowOriginal; // من 1

  @override
  State<PdfTextReader> createState() => PdfTextReaderState();
}

class PdfTextReaderState extends State<PdfTextReader> {
  late final Future<Uint8List> _bytes = File(widget.filePath).readAsBytes();
  final Map<int, Future<PageParagraphs>> _pages = {};
  final Map<int, GlobalKey> _keys = {};
  final _viewportKey = GlobalKey();

  late int _center = (widget.initialPage - 1).clamp(0, widget.pageCount - 1);
  double _centerFraction = 0; // الموضع داخل صفحة البداية (0..1)
  late int _visible = _center;
  ScrollController _scroll = ScrollController();

  // الصفحة الظاهرة أعلى الشاشة (من 1)
  int get page => _visible + 1;

  @override
  void didUpdateWidget(PdfTextReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.sidePadding != widget.sidePadding) {
      _rebuildAt(_visible, _fractionIn(_visible));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // الانتقال لصفحة (من رقم الصفحة في الشريط)
  void jumpToPage(int page) => _rebuildAt(page - 1, 0);

  void _rebuildAt(int index, double fraction) {
    final old = _scroll;
    setState(() {
      _center = index.clamp(0, widget.pageCount - 1);
      _centerFraction = fraction;
      _visible = _center;
      _scroll = ScrollController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      _restoreFraction();
    });
  }

  // بعد إعادة البناء: نفس النسبة داخل الصفحة (ارتفاعها قد يتغير عند جاهزية نصها)
  void _restoreFraction() {
    if (!mounted || _centerFraction <= 0 || !_scroll.hasClients) return;
    final box =
        _keys[_center]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _scroll.jumpTo(box.size.height * _centerFraction);
  }

  // أين أعلى الشاشة داخل الصفحة index (0..1)
  double _fractionIn(int index) {
    final box = _keys[index]?.currentContext?.findRenderObject() as RenderBox?;
    final view = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || view == null || !box.hasSize || box.size.height <= 0) {
      return 0;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    return (-top / box.size.height).clamp(0.0, 1.0);
  }

  // الصفحة التي يمر بها أعلى الشاشة
  void _updateVisible() {
    final view = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (view == null) return;
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
      if (top <= 24 && top + box.size.height > 24) {
        if (e.key != _visible) {
          _visible = e.key;
          widget.onPageChanged(e.key + 1);
          _load(e.key + 1, urgent: false); // تجهيز التالية
        }
        return;
      }
    }
  }

  Future<PageParagraphs> _load(int index, {bool urgent = true}) {
    if (index < 0 || index >= widget.pageCount) {
      return Future.value(const PageParagraphs([]));
    }
    return _pages[index] ??= _read(index, urgent).catchError((Object e) {
      _pages.remove(index); // "حاول مرة أخرى" يعيد المحاولة
      throw e;
    });
  }

  Future<PageParagraphs> _read(int index, bool urgent) async {
    final bytes = await _bytes;
    var words = const <PageWord>[];
    try {
      words = await extractPageWords(bytes, index);
    } catch (e) {
      debugPrint('[TextMode] text extraction failed on page $index: $e');
    }
    if (words.length >= PageTextCache.minTextWords) {
      return PageParagraphs(buildParagraphs(words));
    }
    // صفحة ممسوحة (أو علامة مائية فقط): التعرف الضوئي على الهاتف
    try {
      final raw = await OcrService.instance.pageWords(
        lectureId: widget.lectureId,
        pdfBytes: bytes,
        page: index,
        urgent: urgent,
      );
      final scanned = orderWords([
        for (final w in raw) (text: w.text, rect: w.rect, line: w.line),
      ]);
      if (scanned.length > words.length) {
        return PageParagraphs(buildParagraphs(scanned), ocr: true);
      }
    } on OcrSkipped {
      rethrow;
    } catch (e) {
      debugPrint('[TextMode] OCR failed on page $index: $e');
      if (words.isEmpty) rethrow;
    }
    return PageParagraphs(buildParagraphs(words));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chrome;
    final pad = widget.sidePadding;
    Widget item(int index) => _PageBlock(
      key: _keys[index] ??= GlobalKey(),
      index: index,
      text: _load(index),
      fontSize: widget.fontSize,
      chrome: c,
      onRetry: () => setState(() => _pages.remove(index)),
      onShowOriginal: () => widget.onShowOriginal(index + 1),
    );

    final centerKey = ValueKey('center-$_center');
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
          _updateVisible();
        }
        return false;
      },
      child: SelectionArea(
        child: CustomScrollView(
          key: _viewportKey,
          controller: _scroll,
          center: centerKey,
          slivers: [
            // الصفحات قبل صفحة البداية (تُبنى للأعلى)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverList.builder(
                itemCount: _center,
                itemBuilder: (_, i) => item(_center - 1 - i),
              ),
            ),
            SliverPadding(
              key: centerKey,
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 48),
              sliver: SliverList.builder(
                itemCount: widget.pageCount - _center,
                itemBuilder: (_, i) => item(_center + i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBlock extends StatelessWidget {
  const _PageBlock({
    super.key,
    required this.index,
    required this.text,
    required this.fontSize,
    required this.chrome,
    required this.onRetry,
    required this.onShowOriginal,
  });

  final int index;
  final Future<PageParagraphs> text;
  final double fontSize;
  final ReaderChrome chrome;
  final VoidCallback onRetry;
  final VoidCallback onShowOriginal;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = chrome;
    final note = TextStyle(fontSize: 12.5, color: c.muted, height: 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // فاصل الصفحة: رقمها في المنتصف بين خطين
        SelectionContainer.disabled(
          child: Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 14),
            child: Row(
              children: [
                Expanded(child: Divider(color: c.line, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(s.pageNumber(index + 1), style: note),
                ),
                Expanded(child: Divider(color: c.line, height: 1)),
              ],
            ),
          ),
        ),
        FutureBuilder<PageParagraphs>(
          future: text,
          builder: (context, snap) {
            if (snap.hasError) {
              final skipped = snap.error is OcrSkipped;
              return _State(
                chrome: c,
                message: skipped ? s.readingPageText : s.noPageText,
                busy: skipped,
                actions: [
                  if (!skipped) (s.retry, onRetry),
                  (s.originalPages, onShowOriginal),
                ],
              );
            }
            if (!snap.hasData) {
              return _State(chrome: c, message: s.readingPageText, busy: true);
            }
            final page = snap.data!;
            if (page.paragraphs.isEmpty) {
              return _State(
                chrome: c,
                message: s.noPageText,
                actions: [(s.originalPages, onShowOriginal)],
              );
            }
            final style = TextStyle(
              fontSize: fontSize,
              height: 1.75,
              color: c.ink,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page.ocr)
                  SelectionContainer.disabled(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          AppIcon(AppIcons.info, size: 16, color: c.icon),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s.ocrPageNote, style: note)),
                        ],
                      ),
                    ),
                  ),
                for (final p in page.paragraphs)
                  Padding(
                    padding: EdgeInsets.only(bottom: fontSize * 0.7),
                    child: Text(
                      p,
                      style: style,
                      textAlign: TextAlign.start,
                      textDirection: textDirectionFor(p),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// حالة صفحة بلا نص جاهز: تحميل، أو لا نص (مع الصفحة الأصلية وإعادة المحاولة)
class _State extends StatelessWidget {
  const _State({
    required this.chrome,
    required this.message,
    this.busy = false,
    this.actions = const [],
  });

  final ReaderChrome chrome;
  final String message;
  final bool busy;
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final c = chrome;
    return SelectionContainer.disabled(
      child: Container(
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: c.strong,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.ink, height: 1.5),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final (label, onTap) in actions)
                    TextButton(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        foregroundColor: c.strong,
                        minimumSize: const Size(48, 46),
                      ),
                      child: Text(label),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
