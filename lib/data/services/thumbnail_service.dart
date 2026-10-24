import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' show Printing;

// معاينة الصفحة الأولى من ملفات PDF.
// تُرسم مرة واحدة بدقة منخفضة، ثم تُحفظ في الذاكرة وفي مجلد مؤقت،
// فلا تتكرر عملية الرسم عند التمرير أو عند فتح التطبيق مرة أخرى.
class ThumbnailService {
  ThumbnailService._();

  // نسخة واحدة مشتركة لكل التطبيق (لا تحتاج provider)
  static final ThumbnailService instance = ThumbnailService._();

  static const double _dpi = 56; // كافية لمعاينة صغيرة وخفيفة

  final Map<String, Uint8List> _memory = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};

  // طابور: صفحة واحدة تُرسم في كل مرة حتى لا تتجمد الواجهة
  Future<void> _queue = Future.value();

  // المعاينة إن كانت في الذاكرة الآن (بدون انتظار)، لتظهر فورًا بلا وميض
  Uint8List? peek(String pdfPath) => _memory[pdfPath];

  Future<Uint8List?> pdfFirstPage(String pdfPath) {
    final cached = _memory[pdfPath];
    if (cached != null) return Future.value(cached);

    // تنبيه: الدالة بأقواس {} حتى لا تُرجع شيئًا. لو كانت () => _inFlight.remove(...)
    // لأرجعت الطلب نفسه، و whenComplete تنتظر ما يُرجع، فيبقى الطلب ينتظر نفسه للأبد.
    return _inFlight[pdfPath] ??= _load(pdfPath).whenComplete(() {
      _inFlight.remove(pdfPath);
    });
  }

  Future<Uint8List?> epubCover(String epubPath) {
    final cached = _memory[epubPath];
    if (cached != null) return Future.value(cached);
    return _inFlight[epubPath] ??= _loadEpubCover(epubPath).whenComplete(() {
      _inFlight.remove(epubPath);
    });
  }

  Future<Uint8List?> _loadEpubCover(String epubPath) async {
    try {
      final source = File(epubPath);
      if (!await source.exists()) return null;
      final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
      final container = archive.findFile('META-INF/container.xml');
      if (container == null) return null;
      final containerXml = String.fromCharCodes(container.content as List<int>);
      final root = RegExp(r'''full-path\s*=\s*["']([^"']+)["']''')
          .firstMatch(containerXml)
          ?.group(1);
      if (root == null) return null;
      final opfFile = archive.findFile(root);
      if (opfFile == null) return null;
      final opf = String.fromCharCodes(opfFile.content as List<int>);
      final coverId = RegExp(
        r'''<meta\b[^>]*name\s*=\s*["']cover["'][^>]*content\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(opf)?.group(1);
      final manifest = RegExp(r'''<item\b[^>]*>''', caseSensitive: false)
          .allMatches(opf)
          .map((m) => m.group(0)!)
          .toList();
      String? href;
      for (final item in manifest) {
        final id = RegExp(r'''\bid\s*=\s*["']([^"']+)["']''')
            .firstMatch(item)
            ?.group(1);
        final properties = RegExp(r'''\bproperties\s*=\s*["']([^"']+)["']''')
            .firstMatch(item)
            ?.group(1);
        if (id == coverId || (properties?.split(' ').contains('cover-image') ?? false)) {
          href = RegExp(r'''\bhref\s*=\s*["']([^"']+)["']''')
              .firstMatch(item)
              ?.group(1);
          if (href != null) break;
        }
      }
      if (href == null) return null;
      final coverPath = p.normalize(p.join(p.dirname(root), Uri.decodeComponent(href)))
          .replaceAll('\\', '/');
      final cover = archive.findFile(coverPath);
      if (cover == null) return null;
      final bytes = Uint8List.fromList(cover.content as List<int>);
      if (bytes.isEmpty) return null;
      _memory[epubPath] = bytes;
      return bytes;
    } catch (e, st) {
      debugPrint('[Thumbnail] EPUB cover failed for $epubPath: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> _load(String pdfPath) async {
    final cacheFile = await _cacheFileFor(pdfPath);

    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      if (_isPng(bytes)) {
        _memory[pdfPath] = bytes;
        return bytes;
      }
      // ملف مؤقت تالف (كتابة لم تكتمل): نحذفه ونرسم من جديد
      debugPrint('[Thumbnail] bad cache file, re-rendering: ${cacheFile.path}');
      try {
        await cacheFile.delete();
      } catch (_) {}
    }

    // حد زمني: رسم معلّق لا يوقف بقية المعاينات في الطابور
    final result = _queue.then(
      (_) => _render(pdfPath, cacheFile).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('[Thumbnail] timed out: $pdfPath');
          return null;
        },
      ),
    );
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Uint8List?> _render(String pdfPath, File cacheFile) async {
    try {
      final source = File(pdfPath);
      if (!await source.exists()) {
        debugPrint('[Thumbnail] file not found: $pdfPath');
        return null;
      }

      final bytes = await source.readAsBytes();

      await for (final page in Printing.raster(bytes, pages: [0], dpi: _dpi)) {
        final png = await page.toPng();
        if (!_isPng(png)) {
          debugPrint('[Thumbnail] empty render: $pdfPath');
          return null;
        }
        _memory[pdfPath] = png;

        try {
          await cacheFile.parent.create(recursive: true);
          await cacheFile.writeAsBytes(png, flush: true);
        } catch (_) {
          // التخزين المؤقت اختياري
        }

        return png;
      }
    } catch (e, st) {
      // ملف تالف أو غير قابل للرسم: تظهر أيقونة بدل المعاينة
      debugPrint('[Thumbnail] render failed for $pdfPath: $e\n$st');
      return null;
    }

    debugPrint('[Thumbnail] no pages rendered: $pdfPath');
    return null;
  }

  // معاينة لم تُفتح كصورة: نحذفها من الذاكرة والقرص لتُرسم من جديد
  Future<void> evict(String pdfPath) async {
    _memory.remove(pdfPath);
    try {
      final file = await _cacheFileFor(pdfPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // توقيع PNG في أول 8 بايت
  static bool _isPng(Uint8List b) =>
      b.length > 64 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47;

  Future<File> _cacheFileFor(String pdfPath) async {
    final temp = await getTemporaryDirectory();
    // أسماء الملفات المحفوظة فريدة (تبدأ بطابع زمني)
    final name = '${p.basenameWithoutExtension(pdfPath)}.png';
    return File(p.join(temp.path, 'quickstudy_thumbnails', name));
  }
}
