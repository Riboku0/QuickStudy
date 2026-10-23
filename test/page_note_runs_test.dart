import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/viewer/widgets/pdf_notes.dart';
import 'package:project/ui/viewer/widgets/styled_text.dart';

// نص الصفحة بمقاطع: يُحفظ ويُقرأ، والقديم بلا مقاطع يبقى كما هو
PageNote note({String text = 'hello world', List<StyledRun>? runs}) => PageNote(
  id: 'n',
  page: 0,
  x: 0.1,
  y: 0.1,
  w: 0.5,
  size: 0.03,
  text: text,
  runs: runs,
);

void main() {
  test('runs survive a save and reload of a page note', () {
    const orange = 0xFFEB8A2E;
    final n = note(
      runs: const [
        StyledRun(6, RunStyle.plain),
        StyledRun(5, RunStyle(color: orange, bold: true)),
      ],
    );
    final back = PageNote.fromJson(n.toJson());
    expect(Runs.styleAt(back.runs!, 0).color, isNull);
    expect(Runs.styleAt(back.runs!, 6).color, orange);
    expect(Runs.styleAt(back.runs!, 10).bold, isTrue);
  });

  test('an old note without runs loads plain and draws as one span', () {
    final old = PageNote.fromJson({
      'id': 'o',
      'page': 2,
      'x': 0.2,
      'y': 0.3,
      'w': 0.4,
      'size': 0.03,
      'text': 'old text',
      'bold': true,
    });
    expect(old.runs, isNull);
    expect(old.bold, isTrue);
    final span = noteSpan(old, const TextStyle(fontSize: 12));
    expect(span.text, 'old text');
    expect(span.children, isNull);
  });

  test('dark run colors become readable on dark paper', () {
    final n = note(
      runs: const [StyledRun(11, RunStyle(color: 0xFF202020))],
    );
    final span = noteSpan(n, const TextStyle(fontSize: 12), darkPaper: true);
    final child = span.children!.first as TextSpan;
    expect(child.style!.color, const Color(0xFFE6E0D4));
    // على الورق الفاتح يبقى لونه
    final light = noteSpan(n, const TextStyle(fontSize: 12));
    expect(
      (light.children!.first as TextSpan).style!.color,
      const Color(0xFF202020),
    );
  });
}
