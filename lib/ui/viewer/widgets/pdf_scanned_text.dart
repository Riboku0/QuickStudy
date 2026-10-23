import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../data/services/ocr_service.dart';
import 'text_marks.dart';

// كلمات الصفحات الممسوحة (صور بلا نص) للتحديد في العارض الجديد.
// الصفحة النصية يحددها pdfrx بنفسه؛ هنا فقط الصفحات بأقل من 25 كلمة،
// تُقرأ بالتعرف الضوئي (OcrService يحفظ النتيجة لكل صفحة فلا تتكرر).
// الكلمات بمواضع نسبية من الصفحة ورقم سطر، كما في العارض القديم.
class ScannedPageText {
  ScannedPageText({required this.lectureId, required this.filePath});

  final int lectureId;
  final String filePath;

  Uint8List? _bytes;
  final Map<int, Future<bool>> _scanned = {};
  final Map<int, Future<List<PageWord>>> _words = {};
  final Set<int> _ready = {};

  // هل الصفحة ممسوحة؟ (نص pdfrx فيها أقل من الحد)
  Future<bool> isScanned(PdfPage page) => _scanned[page.pageNumber - 1] ??= page
      .loadStructuredText()
      .then(
        (t) =>
            t.fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <
            PageTextCache.minTextWords,
      )
      .catchError((Object _) => true);

  // الكلمات جاهزة بلا انتظار؟ (وإلا تظهر رسالة "جارٍ قراءة النص")
  bool isReady(int pageIndex) => _ready.contains(pageIndex);

  // urgent: القارئ ينتظرها الآن (ضغطة مطولة)، فتتقدم على القراءة المسبقة
  Future<List<PageWord>> words(int pageIndex, {bool urgent = false}) {
    if (urgent) {
      _urgent.add(pageIndex);
      OcrService.instance.promote(lectureId, pageIndex);
    }
    return _words[pageIndex] ??= _load(pageIndex).catchError((Object e) {
      if (e is! OcrSkipped) debugPrint('[OCR] page $pageIndex failed: $e');
      _words.remove(pageIndex); // محاولة أخرى في المرة القادمة
      return const <PageWord>[];
    });
  }

  final Set<int> _urgent = {};

  // قراءة مسبقة في الخلفية (بلا انتظار)
  void prefetch(PdfPage page) {
    final index = page.pageNumber - 1;
    if (_words.containsKey(index)) return;
    isScanned(page).then((scanned) {
      if (scanned) words(index).ignore();
    });
  }

  // القارئ انتقل: القراءة المسبقة لغير هذه الصفحات تُلغى إن لم تبدأ
  void keepOnly(Set<int> pageIndexes) =>
      OcrService.instance.keepOnly(lectureId, pageIndexes);

  Future<List<PageWord>> _load(int pageIndex) async {
    final bytes = _bytes ??= await File(filePath).readAsBytes();
    final raw = await OcrService.instance.pageWords(
      lectureId: lectureId,
      pdfBytes: bytes,
      page: pageIndex,
      urgent: _urgent.contains(pageIndex),
    );
    final words = orderWords([
      for (final w in raw) (text: w.text, rect: w.rect, line: w.line),
    ]);
    _ready.add(pageIndex);
    return words;
  }
}
