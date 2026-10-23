import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' show Printing;

// كلمة تعرّف عليها OCR، وموضعها نسبة من الصفحة (0..1)
class OcrWord {
  const OcrWord(this.text, this.rect, this.line);

  final String text;
  final Rect rect;
  final int line;

  List<Object> toJson() => [
    text,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    line,
  ];

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

// قراءة مسبقة أُلغيت لأن القارئ ابتعد عن صفحتها (ليست خطأ)
class OcrSkipped implements Exception {
  const OcrSkipped();
}

class _OcrJob {
  _OcrJob(this.lectureId, this.page, this.pdfBytes, this.urgent);

  final int lectureId;
  final int page;
  final Uint8List pdfBytes;
  bool urgent;
  final Completer<List<OcrWord>> done = Completer();
}

// RGBA ← صورة PGM رمادية (P5) يقرؤها Tesseract مباشرة. دالة عليا حتى لا
// تحمل Isolate.run شيئًا غير البكسلات.
Uint8List _grayPgm(Uint8List rgba, int width, int height) {
  final header = ascii.encode('P5\n$width $height\n255\n');
  final out = Uint8List(header.length + width * height)..setAll(0, header);
  var o = header.length;
  for (var i = 0; i + 3 < rgba.length && o < out.length; i += 4) {
    out[o++] = (rgba[i] * 77 + rgba[i + 1] * 150 + rgba[i + 2] * 29) >> 8;
  }
  return out;
}

Future<Uint8List> _pgmInBackground(Uint8List rgba, int width, int height) =>
    Isolate.run(() => _grayPgm(rgba, width, height));

// التعرف على النص في الصفحات الممسوحة (عربي + إنجليزي) لتحديدها ونسخها.
// النتيجة تُحفظ لكل صفحة في quickstudy_ocr/{lectureId}/{page}.json،
// فلا تتكرر المعالجة عند فتح الكتاب مرة أخرى. الملف الأصلي لا يتغير.
class OcrService {
  OcrService._();

  static final OcrService instance = OcrService._();

  // دقة كافية لقراءة الحروف العربية بدون صورة ضخمة
  static const double _dpi = 220;

  // صفحة واحدة في كل مرة (OCR ثقيل على الهاتف). الطلب العاجل (ضغطة مطولة)
  // يتقدم على القراءة المسبقة، والمسبقة بترتيب وصولها، وما ابتعد عنه القارئ
  // يُلغى قبل أن يبدأ (keepOnly) حتى لا تنتظر الصفحة الحالية صفحات قديمة.
  final List<_OcrJob> _pending = [];
  bool _working = false;

  static const _channel = MethodChannel('quickstudy/ocr');
  Future<String>? _dataPath;

  // ملفات اللغة من assets/tessdata إلى مجلد التطبيق مرة واحدة (كما تفعل
  // flutter_tesseract_ocr)، ويُرجع المجلد الأب الذي يطلبه Tesseract
  Future<String> _prepareTessData() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'tessdata'));
    await dir.create(recursive: true);
    final config =
        jsonDecode(await rootBundle.loadString('assets/tessdata_config.json'))
            as Map<String, dynamic>;
    for (final name in (config['files'] as List).cast<String>()) {
      final file = File(p.join(dir.path, name));
      if (await file.exists()) continue;
      final data = await rootBundle.load('assets/tessdata/$name');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return docs.path;
  }

  Future<List<OcrWord>> pageWords({
    required int lectureId,
    required Uint8List pdfBytes,
    required int page,
    bool urgent = false,
  }) async {
    final cache = await _cacheFile(lectureId, page);
    final cached = await _readCache(cache);
    if (cached != null) return cached;

    final words = await _enqueue(lectureId, pdfBytes, page, urgent);

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

  Future<List<OcrWord>> _enqueue(
    int lectureId,
    Uint8List pdfBytes,
    int page,
    bool urgent,
  ) {
    for (final job in _pending) {
      if (job.lectureId == lectureId && job.page == page) {
        job.urgent |= urgent;
        return job.done.future;
      }
    }
    final job = _OcrJob(lectureId, page, pdfBytes, urgent);
    _pending.add(job);
    _pump();
    return job.done.future;
  }

  // صفحة لم تبدأ قراءتها بعد صارت عاجلة (ضغط عليها القارئ)
  void promote(int lectureId, int page) {
    for (final job in _pending) {
      if (job.lectureId == lectureId && job.page == page) job.urgent = true;
    }
  }

  // إلغاء القراءة المسبقة للصفحات التي ابتعد عنها القارئ (العاجلة تبقى)
  void keepOnly(int lectureId, Set<int> pages) {
    _pending.removeWhere((job) {
      final drop =
          job.lectureId == lectureId && !job.urgent && !pages.contains(job.page);
      if (drop) job.done.completeError(const OcrSkipped());
      return drop;
    });
  }

  Future<void> _pump() async {
    if (_working) return;
    _working = true;
    while (_pending.isNotEmpty) {
      final job = _pending.firstWhere(
        (j) => j.urgent,
        orElse: () => _pending.first,
      );
      _pending.remove(job);
      try {
        job.done.complete(await _recognize(job.pdfBytes, job.page));
      } catch (e, st) {
        job.done.completeError(e, st);
      }
    }
    _working = false;
  }

  Future<List<OcrWord>> _recognize(Uint8List pdfBytes, int page) async {
    final temp = await getTemporaryDirectory();
    // PGM رمادي بلا ضغط: كتابته فورية، وترميز PNG كان يأخذ نصف ثانية لكل صفحة
    final image = File(
      p.join(
        temp.path,
        'quickstudy_ocr_${DateTime.now().microsecondsSinceEpoch}.pgm',
      ),
    );

    try {
      int width = 0;
      int height = 0;
      await for (final raster in Printing.raster(
        pdfBytes,
        pages: [page],
        dpi: _dpi,
      )) {
        width = raster.width;
        height = raster.height;
        await image.writeAsBytes(
          await _pgmInBackground(raster.pixels, width, height),
          flush: true,
        );
        break;
      }
      if (width <= 0 || height <= 0) return const [];

      // عبر MainActivity (خيط بأولوية عادية)، لا extractHocr من الإضافة
      final hocr =
          await _channel.invokeMethod<String>('hocr', {
            'dataPath': await (_dataPath ??= _prepareTessData()),
            'language': 'ara+eng',
            'imagePath': image.path,
            'psm': 3,
            'vars': {
              'preserve_interword_spaces': '1',
              // بلا محاولة ثانية بالألوان المعكوسة للأسطر الضعيفة: أسرع،
              // والكتب نص داكن على ورق فاتح
              'tessedit_do_invert': '0',
            },
          }) ??
          '';
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
      final text = _unescape(hocr.substring(m.end, end).replaceAll(_tags, ''))
          .trim();
      if (text.isEmpty) continue;

      // كلمات بثقة منخفضة جدًا غالبًا ضجيج من الصورة
      final conf = int.tryParse(
        _conf.firstMatch(m.group(6) ?? '')?.group(1) ?? '',
      );
      if (conf != null && conf < 15) continue;

      final x0 = double.parse(m.group(2)!);
      final y0 = double.parse(m.group(3)!);
      final x1 = double.parse(m.group(4)!);
      final y1 = double.parse(m.group(5)!);
      if (x1 <= x0 || y1 <= y0) continue;

      words.add(
        OcrWord(
          text,
          Rect.fromLTRB(x0 / width, y0 / height, x1 / width, y1 / height),
          line < 0 ? 0 : line,
        ),
      );
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
