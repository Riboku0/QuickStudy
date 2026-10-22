import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' show Printing;
import 'package:syncfusion_flutter_pdf/pdf.dart'
    show PdfDocument, PdfTextExtractor;

// استخراج نص PDF داخل Isolate لتجنب تجميد الواجهة.
String _extractPdfTextSync(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);

  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

class FileTextExtractor {
  /// الصيغ المدعومة: PDF والصور فقط.
  static Future<String> extractText({required String path}) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    final extension = path.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return _readPdf(file);

      case 'png':
      case 'jpg':
      case 'jpeg':
        return _readImage(file);

      default:
        throw UnsupportedError(
          'This file format is not supported: .$extension',
        );
    }
  }

  /// استخراج النص من PDF، ثم استخدام OCR إذا لم يوجد نص كافٍ.
  static Future<String> _readPdf(File file) async {
    String extractedText = '';
    final bytes = await file.readAsBytes();

    try {
      extractedText = (await Isolate.run(
        () => _extractPdfTextSync(bytes),
      ).timeout(const Duration(seconds: 120))).trim();
    } catch (_) {
      // الانتقال إلى OCR إذا تعذر استخراج النص مباشرة.
    }

    if (extractedText.length >= 30) {
      return extractedText;
    }

    final pageCount = await Isolate.run(() {
      final document = PdfDocument(inputBytes: bytes);

      try {
        return document.pages.count;
      } finally {
        document.dispose();
      }
    });

    if (pageCount > 40) {
      throw Exception(
        'This PDF has $pageCount pages - too long for OCR. '
        'Use the page viewer instead.',
      );
    }

    return _readPdfWithOcr(file);
  }

  /// تحويل صفحات PDF إلى صور والتعرف على النصوص باستخدام OCR.
  static Future<String> _readPdfWithOcr(File file) async {
    final bytes = await file.readAsBytes();
    final tempDirectory = await getTemporaryDirectory();

    final pageTexts = <String>[];
    var pageNumber = 0;

    await for (final raster in Printing.raster(bytes, dpi: 200)) {
      pageNumber++;

      final pngBytes = await raster.toPng();

      final imageFile = File(
        '${tempDirectory.path}/'
        'quickstudy_ocr_'
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$pageNumber.png',
      );

      try {
        await imageFile.writeAsBytes(pngBytes, flush: true);

        final recognizedText = await FlutterTesseractOcr.extractText(
          imageFile.path,
          language: 'ara+eng',
          args: {'psm': '3', 'preserve_interword_spaces': '1'},
        );

        if (recognizedText.trim().isNotEmpty) {
          pageTexts.add(
            '--- Page $pageNumber ---\n'
            '${recognizedText.trim()}',
          );
        }
      } finally {
        try {
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        } catch (_) {
          // تجاهل أخطاء حذف الملفات المؤقتة.
        }
      }
    }

    if (pageNumber == 0) {
      throw Exception('The PDF contains no pages.');
    }

    final result = pageTexts.join('\n\n').trim();

    if (result.isEmpty) {
      throw Exception(
        'OCR could not recognize text in this PDF. '
        'Check the scan quality and Arabic language files.',
      );
    }

    return result;
  }

  /// التعرف على النصوص العربية والإنجليزية داخل الصور.
  static Future<String> _readImage(File file) async {
    final text = await FlutterTesseractOcr.extractText(
      file.path,
      language: 'ara+eng',
      args: {'psm': '3', 'preserve_interword_spaces': '1'},
    );

    return text.trim();
  }
}
