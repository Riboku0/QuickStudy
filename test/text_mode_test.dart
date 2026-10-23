import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/viewer/widgets/pdf_text_mode.dart';
import 'package:project/ui/viewer/widgets/text_marks.dart';

// الكلمات في سطر: عرض كل كلمة 0.1 بلا فراغ، والسطر بارتفاع 0.02
List<PageWord> line(
  int index,
  List<String> words, {
  double top = 0,
  bool rtl = false,
  double width = 0.8,
}) {
  final w = width / words.length;
  return [
    for (final (i, t) in words.indexed)
      PageWord(
        t,
        Rect.fromLTWH(rtl ? 0.9 - (i + 1) * w : 0.1 + i * w, top, w, 0.02),
        index,
        rtl,
      ),
  ];
}

void main() {
  test('lines of one paragraph join, a short line ends it', () {
    final words = [
      ...line(0, ['The', 'first', 'line'], top: 0.10),
      ...line(1, ['goes', 'on', 'here.'], top: 0.13, width: 0.3),
      ...line(2, ['Second', 'paragraph'], top: 0.16),
    ];
    expect(buildParagraphs(words), [
      'The first line goes on here.',
      'Second paragraph',
    ]);
  });

  test('a big vertical gap starts a new paragraph', () {
    final words = [
      ...line(0, ['One'], top: 0.10),
      ...line(1, ['two'], top: 0.13),
      ...line(2, ['Three'], top: 0.30),
    ];
    expect(buildParagraphs(words), ['One two', 'Three']);
  });

  test('Arabic lines keep reading order and drop the page number', () {
    final words = [
      ...line(0, ['١٢'], top: 0.02, width: 0.05),
      ...line(1, ['كان', 'يا', 'ما'], top: 0.10, rtl: true),
      ...line(2, ['كان'], top: 0.13, rtl: true),
    ];
    expect(buildParagraphs(words), ['كان يا ما كان']);
  });

  test('a hyphen at the end of a Latin line joins the word', () {
    final words = [
      ...line(0, ['an', 'exam-'], top: 0.10),
      ...line(1, ['ple', 'here'], top: 0.13),
    ];
    expect(buildParagraphs(words), ['an example here']);
  });

  test('empty page gives no paragraphs', () {
    expect(buildParagraphs(const []), isEmpty);
  });
}
