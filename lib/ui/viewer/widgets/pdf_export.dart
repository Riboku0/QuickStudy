import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfBitmap, PdfDocument;

import 'pdf_ink.dart';
import 'pdf_notes.dart';
import 'text_marks.dart';

// "حفظ نسخة" و"مشاركة نسخة" في العارض الجديد: نسخة من الكتاب فوق كل صفحة
// فيها شيء طبقة شفافة بنفس رسامي الشاشة: التظليل، والقلم والأشكال، ونص
// الصفحة. المذكرات والمرفقات (صوت، صور) تبقى داخل التطبيق.
// الكتاب الأصلي لا يتغير.

class PageAnnotations {
  const PageAnnotations({
    this.marks = const [],
    this.strokes = const [],
    this.notes = const [],
  });

  final List<TextMark> marks;
  final List<InkStroke> strokes;
  final List<PageNote> notes;

  bool get isEmpty =>
      marks.isEmpty &&
      strokes.isEmpty &&
      notes.every((n) => n.text.trim().isEmpty);
}

// pages: رقم الصفحة من 0 ← ما عليها. بلا شيء = نسخة طبق الأصل
Future<Uint8List> exportAnnotatedPdf(
  Uint8List original,
  Map<int, PageAnnotations> pages,
) async {
  final used = {
    for (final e in pages.entries)
      if (!e.value.isEmpty) e.key: e.value,
  };
  if (used.isEmpty) return original;

  // خطوط نص الصفحة من Google Fonts قبل الرسم
  try {
    for (final a in used.values) {
      for (final n in a.notes) {
        noteStyle(n, 12);
      }
    }
    await GoogleFonts.pendingFonts();
  } catch (_) {}

  final document = PdfDocument(inputBytes: original);
  try {
    for (final entry in used.entries) {
      if (entry.key < 0 || entry.key >= document.pages.count) continue;
      final page = document.pages[entry.key];
      final size = page.size;
      // دقة كافية للنص والخطوط بلا ملف ضخم
      final pw = math.min(size.width * 3, 2400.0);
      final ph = pw * size.height / size.width;
      final png = await _overlay(entry.value, Size(pw, ph));
      page.graphics.drawImage(
        PdfBitmap(png),
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }
    return Uint8List.fromList(await document.save());
  } finally {
    document.dispose();
  }
}

Future<Uint8List> _overlay(PageAnnotations a, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  MarksPainter(marks: a.marks).paint(canvas, size);
  paintStrokes(canvas, size, a.strokes);
  paintNotes(canvas, size, a.notes);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
