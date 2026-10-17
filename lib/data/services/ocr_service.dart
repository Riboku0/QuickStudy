import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' show Printing;

// كلمة تعرّف عليها OCR، وموضعها نسبة من الصفحة (0..1)
class OcrWord {
  const OcrWord(this.text, this.rect, this.line);

  final String text;
  final Rect rect;
  final int line;

  List<Object> toJson() => [text, rect.left, rect.top, rect.right, rect.bottom, line];

  static OcrWord? fromJson(Object? raw) {
    if (raw is! List || raw.length < 6) return null;
    return OcrWord(
      '${raw[0]}',
      Rect.fromLTRB(
        (raw[1] as num).toDouble(),
        (raw[2] as num).toDouble(),
        (raw[3] as num).toDouble(),
        (raw[4] as num).toDouble(),
      ),
      (raw[5] as num).toInt(),
    );
  }
}

// التعرف على النص في الصفحات الممسوحة (عربي + إنجليزي) لتحديدها ونسخها.
// النتيجة تُحفظ لكل صفحة في quickstudy_ocr/{lectureId}/{page}.json،
// فلا تتكرر المعالجة عند فتح الكتاب مرة أخرى. الملف الأصلي لا يتغير.
class OcrService {
  OcrService._();

  static final OcrService instance = OcrService._();

  // دقة كافية لقراءة الحروف العربية بدون صورة ضخمة
  static const double _dpi = 220;

  // صفحة واحدة في كل مرة (OCR ثقيل على الهاتف)
  Future<void> _queue = Future.value();

  Future<List<OcrWord>> pageWords({
    required int lectureId,
    required Uint8List pdfBytes,
    required int page,
  }) async {
    final cache = await _cacheFile(lectureId, page);
    final cached = await _readCache(cache);
    if (cached != null) return cached;

    final result = _queue.then((_) => _recognize(pdfBytes, page));
    _queue = result.then((_) {}, onError: (_) {});
    final words = await result;

    try {
      await cache.parent.create(recursive: true);
      await cache.writeAsString(
        jsonEncode([for (final w in words) w.toJson()]),
        flush: true,
      );
    } catch (e) {
      debugPrint('[OCR] cache write failed: $e');
    }
    return words;
  }

  Future<List<OcrWord>> _recognize(Uint8List pdfBytes, int page) async {
    final temp = await getTemporaryDirectory();
    final image = File(p.join(
      temp.path,
      'quickstudy_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
    ));

    try {
      int width = 0;
      int height = 0;
      await for (final raster in Printing.raster(pdfBytes, pages: [page], dpi: _dpi)) {
        width = raster.width;
        height = raster.height;
        await image.writeAsBytes(await raster.toPng(), flush: true);
        break;
      }
      if (width <= 0 || height <= 0) return const [];

      final hocr = await FlutterTesseractOcr.extractHocr(
        image.path,
        language: 'ara+eng',
        args: {'psm': '3', 'preserve_interword_spaces': '1'},
      );
      return parseHocr(hocr, width.toDouble(), height.toDouble());
    } finally {
      try {
        if (await image.exists()) await image.delete();
      } catch (_) {}
    }
  }

  // hOCR: أسطر (ocr_line وما يشبهها) وبداخلها كلمات ocrx_word مع bbox
  static final RegExp _token = RegExp(
    r'''<span class=['"](ocr_line|ocr_header|ocr_caption|ocr_textfloat|ocrx_word)['"][^>]*?title=['"]bbox (\d+) (\d+) (\d+) (\d+)([^'"]*)['"][^>]*>''',
  );
  static final RegExp _tags = RegExp(r'<[^>]+>');
  static final RegExp _conf = RegExp(r'x_wconf (\d+)');

  static List<OcrWord> parseHocr(String hocr, double width, double height) {
    final words = <OcrWord>[];
    var line = -1;

    for (final m in _token.allMatches(hocr)) {
      if (m.group(1) != 'ocrx_word') {
        line++;
        continue;
      }

      // نص الكلمة حتى </span> (قد يحوي <strong> أو <em>)
      final end = hocr.indexOf('</span>', m.end);
      if (end < 0) continue;
      final text = _unescape(hocr.substring(m.end, end).replaceAll(_tags, '')).trim();
      if (text.isEmpty) continue;

      // كلمات بثقة منخفضة جدًا غالبًا ضجيج من الصورة
      final conf = int.tryParse(_conf.firstMatch(m.group(6) ?? '')?.group(1) ?? '');
      if (conf != null && conf < 15) continue;

      final x0 = double.parse(m.group(2)!);
      final y0 = double.parse(m.group(3)!);
      final x1 = double.parse(m.group(4)!);
      final y1 = double.parse(m.group(5)!);
      if (x1 <= x0 || y1 <= y0) continue;

      words.add(OcrWord(
        text,
        Rect.fromLTRB(x0 / width, y0 / height, x1 / width, y1 / height),
        line < 0 ? 0 : line,
      ));
    }
    return words;
  }

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'quickstudy_ocr'));
  }

  Future<File> _cacheFile(int lectureId, int page) async =>
      File(p.join((await _root()).path, '$lectureId', '$page.json'));

  Future<List<OcrWord>?> _readCache(File file) async {
    try {
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return null;
      return data.map(OcrWord.fromJson).whereType<OcrWord>().toList();
    } catch (_) {
      return null; // ملف تالف: نعيد التعرف
    }
  }
}
